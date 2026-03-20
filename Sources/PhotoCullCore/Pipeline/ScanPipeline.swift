import Foundation

public actor ScanPipeline {
    private let libraryService: any PhotoLibraryServiceProtocol
    private let hasher: CryptoHasher
    private let groupBuilder: GroupBuilder
    private let ranker: ExactDuplicateRanker
    private let safetyGuard: SafetyGuard
    private let explanationBuilder: ExplanationBuilder
    private let configuration: CullConfiguration

    public init(
        libraryService: some PhotoLibraryServiceProtocol,
        hasher: CryptoHasher = CryptoHasher(),
        groupBuilder: GroupBuilder = GroupBuilder(),
        ranker: ExactDuplicateRanker = ExactDuplicateRanker(),
        safetyGuard: SafetyGuard = SafetyGuard(),
        explanationBuilder: ExplanationBuilder = ExplanationBuilder(),
        configuration: CullConfiguration = .default
    ) {
        self.libraryService = libraryService
        self.hasher = hasher
        self.groupBuilder = groupBuilder
        self.ranker = ranker
        self.safetyGuard = safetyGuard
        self.explanationBuilder = explanationBuilder
        self.configuration = configuration
    }

    public func scan() -> AsyncThrowingStream<ScanEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    // 1. Fetch assets
                    continuation.yield(.progress(ScanProgress(
                        phase: .fetchingAssets, processed: 0, total: 0, message: "Fetching photos..."
                    )))
                    let assets = try await libraryService.fetchAssets()
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

                    // 3. Group duplicates
                    continuation.yield(.progress(ScanProgress(
                        phase: .grouping, processed: total, total: total, message: "Grouping duplicates..."
                    )))
                    let groups: [CullGroup]
                    if configuration.enableExactDuplicates {
                        groups = groupBuilder.buildGroups(from: hashResults)
                    } else {
                        groups = []
                    }

                    // 4. Rank + SafetyGuard + Explain
                    continuation.yield(.progress(ScanProgress(
                        phase: .ranking, processed: 0, total: groups.count, message: "Ranking \(groups.count) group(s)..."
                    )))
                    var allRecommendations: [CullRecommendation] = []
                    for group in groups {
                        var recs = ranker.rank(group: group)
                        recs = try safetyGuard.validate(recommendations: recs, for: group)
                        recs = recs.map { explanationBuilder.explain(recommendation: $0, in: group) }
                        allRecommendations.append(contentsOf: recs)
                    }

                    let result = ScanResult(
                        groups: groups,
                        recommendations: allRecommendations,
                        totalScanned: total,
                        scanDate: Date()
                    )

                    continuation.yield(.progress(ScanProgress(
                        phase: .complete,
                        processed: total,
                        total: total,
                        message: "Found \(groups.count) duplicate group(s) among \(total) photo(s)."
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
