import Foundation

public actor ScanPipeline {
    private let libraryService: any PhotoLibraryServiceProtocol
    private let hasher: CryptoHasher
    private let groupBuilder: GroupBuilder
    private let ranker: ExactDuplicateRanker
    private let safetyGuard: SafetyGuard
    private let explanationBuilder: ExplanationBuilder
    private let configuration: CullConfiguration
    private let analysisBackend: AnalysisBackendBundle?
    private let decisionStore: (any ReviewDecisionStore)?

    public init(
        libraryService: some PhotoLibraryServiceProtocol,
        hasher: CryptoHasher = CryptoHasher(),
        groupBuilder: GroupBuilder = GroupBuilder(),
        ranker: ExactDuplicateRanker = ExactDuplicateRanker(),
        safetyGuard: SafetyGuard = SafetyGuard(),
        explanationBuilder: ExplanationBuilder = ExplanationBuilder(),
        configuration: CullConfiguration = .default,
        analysisBackend: AnalysisBackendBundle? = nil,
        decisionStore: (any ReviewDecisionStore)? = nil
    ) {
        self.libraryService = libraryService
        self.hasher = hasher
        self.groupBuilder = groupBuilder
        self.ranker = ranker
        self.safetyGuard = safetyGuard
        self.explanationBuilder = explanationBuilder
        self.configuration = configuration
        self.analysisBackend = analysisBackend
        self.decisionStore = decisionStore
    }

    public func scan() -> AsyncThrowingStream<ScanEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    // 1. Fetch assets
                    continuation.yield(.progress(ScanProgress(
                        phase: .fetchingAssets, processed: 0, total: 0, message: "Fetching photos..."
                    )))
                    var assets = try await libraryService.fetchAssets()

                    // 1b. Filter out assets the user has already reviewed.
                    // - .deleted: asset is in the Trash — never surface again.
                    // - .kept: user explicitly kept this asset in a prior session.
                    //   We exclude kept assets only when *every* member of their
                    //   previous group was reviewed (i.e. no new unseen partner).
                    //   Simple conservative rule: skip .deleted assets entirely;
                    //   leave .kept assets in so new arrivals can still pair with them.
                    if let store = decisionStore {
                        let allIds = assets.map(\.id)
                        let known = await store.decisions(for: allIds)
                        assets = assets.filter { known[$0.id] != .deleted }
                    }

                    let total = assets.count

                    // 2. Load image data + hash each asset → HashResult
                    continuation.yield(.progress(ScanProgress(
                        phase: .hashing, processed: 0, total: total, message: "Hashing \(total) photo(s)..."
                    )))
                    var hashResults: [HashResult] = []
                    hashResults.reserveCapacity(total)
                    for (index, asset) in assets.enumerated() {
                        try Task.checkCancellation()
                        let data = try await libraryService.loadImageData(for: asset)
                        let hash = hasher.hash(data)
                        hashResults.append(HashResult(asset: asset, cryptoHash: hash))
                        continuation.yield(.progress(ScanProgress(
                            phase: .hashing,
                            processed: index + 1,
                            total: total,
                            message: "Hashing \(index + 1) of \(total)..."
                        )))
                    }

                    // 3. Group exact duplicates
                    continuation.yield(.progress(ScanProgress(
                        phase: .grouping, processed: total, total: total, message: "Grouping duplicates..."
                    )))
                    let exactGroups: [CullGroup]
                    if configuration.enableExactDuplicates {
                        exactGroups = groupBuilder.buildGroups(from: hashResults)
                    } else {
                        exactGroups = []
                    }

                    // 4. Near-duplicate / burst grouping (Phase 3)
                    let similarityGroups: [CullGroup]
                    var similarityFeatures: [String: AssetFeatures] = [:]
                    var similarityPairs: [CandidatePair] = []

                    if configuration.enableNearDuplicates || configuration.enableBurstGrouping,
                       let backend = analysisBackend {
                        // Assets already in exact-duplicate groups are excluded.
                        let exactGroupedIds = Set(exactGroups.flatMap { $0.members.map(\.id) })
                        let candidateAssets = assets.filter { !exactGroupedIds.contains($0.id) }

                        // CPU metadata prefilter
                        let prefilter = MetadataPrefilter()
                        let candidatePairs = prefilter.candidates(
                            from: candidateAssets, configuration: configuration
                        )

                        if !candidatePairs.isEmpty {
                            // Collect unique asset IDs referenced by candidate pairs.
                            var neededIds: Set<String> = []
                            for pair in candidatePairs {
                                neededIds.insert(pair.assetIdA)
                                neededIds.insert(pair.assetIdB)
                            }
                            let neededAssets = candidateAssets.filter { neededIds.contains($0.id) }

                            continuation.yield(.progress(ScanProgress(
                                phase: .grouping,
                                processed: exactGroups.count,
                                total: exactGroups.count + neededAssets.count,
                                message: "Extracting features for \(neededAssets.count) asset(s)..."
                            )))

                            // Extract features; failures are non-fatal.
                            var validPairs = candidatePairs
                            let exposureScorer = ExposureScorer()
                            let subjectScorer = SubjectScorer()

                            // Collect scores concurrently with bounded concurrency.
                            let concurrencyLimit = min(neededAssets.count, 4)
                            typealias ScoringResult = (id: String, features: AssetFeatures?)
                            var scoringResults: [ScoringResult] = []
                            scoringResults.reserveCapacity(neededAssets.count)

                            try Task.checkCancellation()
                            await withTaskGroup(of: ScoringResult.self) { group in
                                var active = 0
                                var iterator = neededAssets.makeIterator()

                                // Seed initial batch.
                                while active < concurrencyLimit, let asset = iterator.next() {
                                    let a = asset
                                    group.addTask {
                                        do {
                                            let processed = try await backend.preprocessor.preprocess(a)
                                            let vector = try await backend.featureExtractor.extractFeatures(from: processed)
                                            let sharpness = try await backend.sharpnessAnalyzer.analyzeSharpness(of: processed)
                                            var exposureScore: Double? = nil
                                            var subjectScore: Double? = nil
                                            if let sv = try? exposureScorer.score(asset: a, image: processed) {
                                                exposureScore = sv.value
                                            }
                                            if let sv = try? subjectScorer.score(asset: a, image: processed) {
                                                subjectScore = sv.value
                                            }
                                            let feat = AssetFeatures(
                                                assetId: a.id,
                                                featureVector: vector,
                                                sharpnessScore: sharpness,
                                                exposureScore: exposureScore,
                                                subjectScore: subjectScore
                                            )
                                            return (id: a.id, features: feat)
                                        } catch {
                                            return (id: a.id, features: nil)
                                        }
                                    }
                                    active += 1
                                }

                                // Drain results and refill.
                                for await result in group {
                                    scoringResults.append(result)
                                    if let asset = iterator.next() {
                                        let a = asset
                                        group.addTask {
                                            do {
                                                let processed = try await backend.preprocessor.preprocess(a)
                                                let vector = try await backend.featureExtractor.extractFeatures(from: processed)
                                                let sharpness = try await backend.sharpnessAnalyzer.analyzeSharpness(of: processed)
                                                var exposureScore: Double? = nil
                                                var subjectScore: Double? = nil
                                                if let sv = try? exposureScorer.score(asset: a, image: processed) {
                                                    exposureScore = sv.value
                                                }
                                                if let sv = try? subjectScorer.score(asset: a, image: processed) {
                                                    subjectScore = sv.value
                                                }
                                                let feat = AssetFeatures(
                                                    assetId: a.id,
                                                    featureVector: vector,
                                                    sharpnessScore: sharpness,
                                                    exposureScore: exposureScore,
                                                    subjectScore: subjectScore
                                                )
                                                return (id: a.id, features: feat)
                                            } catch {
                                                return (id: a.id, features: nil)
                                            }
                                        }
                                    }
                                }
                            }

                            // Integrate results; drop pairs for failed assets.
                            for result in scoringResults {
                                if let feat = result.features {
                                    similarityFeatures[result.id] = feat
                                } else {
                                    validPairs = validPairs.filter {
                                        $0.assetIdA != result.id && $0.assetIdB != result.id
                                    }
                                }
                            }

                            // Score and confirm pairs.
                            let scorer = SimilarityScorer()
                            let confirmed = scorer.confirmPairs(
                                validPairs,
                                features: similarityFeatures,
                                threshold: configuration.similarityThreshold
                            )
                            similarityPairs = confirmed

                            // Build groups.
                            let assetMap = Dictionary(uniqueKeysWithValues: candidateAssets.map { ($0.id, $0) })
                            let builder = SimilarityGroupBuilder()
                            var allSimGroups = builder.buildGroups(from: confirmed, assets: assetMap)

                            // Filter by enabled flags.
                            if configuration.enableBurstGrouping && !configuration.enableNearDuplicates {
                                allSimGroups = allSimGroups.filter { $0.reason == .burst }
                            } else if configuration.enableNearDuplicates && !configuration.enableBurstGrouping {
                                allSimGroups = allSimGroups.filter { $0.reason == .nearDuplicate }
                            }

                            similarityGroups = allSimGroups
                        } else {
                            similarityGroups = []
                        }
                    } else {
                        similarityGroups = []
                    }

                    let allGroups = exactGroups + similarityGroups

                    // 5. Rank + SafetyGuard + Explain
                    continuation.yield(.progress(ScanProgress(
                        phase: .ranking, processed: 0, total: allGroups.count,
                        message: "Ranking \(allGroups.count) group(s)..."
                    )))
                    var allRecommendations: [CullRecommendation] = []
                    for group in exactGroups {
                        var recs = ranker.rank(group: group)
                        recs = try safetyGuard.validate(recommendations: recs, for: group)
                        recs = recs.map { explanationBuilder.explain(recommendation: $0, in: group) }
                        allRecommendations.append(contentsOf: recs)
                    }
                    let bestShotRanker = BestShotRanker()
                    let assetLookup = Dictionary(
                        uniqueKeysWithValues: assets.map { ($0.id, $0) }
                    )
                    for group in similarityGroups {
                        var recs = bestShotRanker.rank(
                            group: group,
                            features: similarityFeatures,
                            pairs: similarityPairs,
                            assets: assetLookup,
                            configuration: configuration
                        )
                        recs = try safetyGuard.validate(recommendations: recs, for: group)
                        let keeperBreakdown = recs.first(where: { $0.action == .keep })?.signalBreakdown
                        recs = recs.map { explanationBuilder.explain(recommendation: $0, in: group, keeperBreakdown: keeperBreakdown) }
                        allRecommendations.append(contentsOf: recs)
                    }

                    let result = ScanResult(
                        groups: allGroups,
                        recommendations: allRecommendations,
                        totalScanned: total,
                        scanDate: Date()
                    )

                    continuation.yield(.progress(ScanProgress(
                        phase: .complete,
                        processed: total,
                        total: total,
                        message: "Found \(allGroups.count) group(s) among \(total) photo(s)."
                    )))
                    continuation.yield(.completed(result))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
