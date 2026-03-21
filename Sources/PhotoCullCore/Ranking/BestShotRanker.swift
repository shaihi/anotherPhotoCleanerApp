import Foundation

/// Ranks members of a near-duplicate or burst group using a two-pass algorithm.
///
/// **Pass 1 — Preservation tier:**
/// - Tier 0: `isFavorite == true`
/// - Tier 1: `isEdited == true`
/// - Tier 2: all others
/// A Tier-2 photo never outranks a Tier-0 or Tier-1 photo.
///
/// **Pass 2 — Within-tier ordering by composite score:**
/// Primary: composite score DESC
/// Tie 1: sharpness DESC
/// Tie 2: newest creationDate DESC
/// Tie 3: lexicographically smallest id ASC
///
/// **Cull suppression rules:**
/// Rule A — Confidence suppression: if `ConfidenceCalculator.isSuppressed` returns true,
///          downgrade to `.keep`.
/// Rule B — Missing-signal suppression: if the cull candidate has any nil optional signal
///          (`exposureScore` or `subjectScore`), downgrade to `.keep`.
public struct BestShotRanker: Sendable {
    private let compositeScorer = CompositeScorer()
    private let resolutionScorer = ResolutionScorer()
    private let confidenceCalculator = ConfidenceCalculator()
    private let blurClassifier = BlurClassifier()

    public init() {}

    public func rank(
        group: CullGroup,
        features: [String: AssetFeatures],
        pairs: [CandidatePair],
        assets: [String: PhotoAsset],
        configuration: CullConfiguration
    ) -> [CullRecommendation] {
        let members = group.members
        let memberIds = Set(members.map(\.id))

        // Build weight map from configuration.
        let weights: [QualitySignal: Double] = [
            .sharpness: configuration.sharpnessWeight,
            .exposure: configuration.exposureWeight,
            .subjectQuality: configuration.subjectWeight,
            .resolution: configuration.resolutionWeight
        ]

        // Determine group max pixels for resolution scoring.
        let groupMaxPixels = members.map { $0.pixelWidth * $0.pixelHeight }.max() ?? 0

        // Build signal maps and composite scores for all members.
        let signalMaps = buildSignalMaps(
            members: members, features: features,
            groupMaxPixels: groupMaxPixels
        )
        let compositeScores = buildCompositeScores(
            members: members, signalMaps: signalMaps, weights: weights
        )

        // Pass 1 + 2: Sort with tier, then composite score, then tiebreakers.
        let sorted = members.sorted { a, b in
            let tierA = preservationTier(for: a)
            let tierB = preservationTier(for: b)
            if tierA != tierB { return tierA < tierB }
            // Within tier: composite score DESC
            let scoreA = compositeScores[a.id] ?? 0.0
            let scoreB = compositeScores[b.id] ?? 0.0
            if scoreA != scoreB { return scoreA > scoreB }
            // Tiebreaker 1: sharpness DESC
            let sharpA = features[a.id]?.sharpnessScore.value ?? 0.0
            let sharpB = features[b.id]?.sharpnessScore.value ?? 0.0
            if sharpA != sharpB { return sharpA > sharpB }
            // Tiebreaker 2: newest creation date DESC
            let dateA = a.creationDate ?? .distantPast
            let dateB = b.creationDate ?? .distantPast
            if dateA != dateB { return dateA > dateB }
            // Tiebreaker 3: lexicographic id ASC (deterministic)
            return a.id < b.id
        }

        // Derive similarity confidence from pair distances.
        let baseSimilarityConfidence = deriveSimilarityConfidence(
            memberIds: memberIds, pairs: pairs
        )

        let keeper = sorted[0]
        let keeperScore = compositeScores[keeper.id] ?? 0.0
        let keeperSignals = signalMaps[keeper.id] ?? [:]
        let keeperBreakdown = compositeScorer.breakdown(signals: keeperSignals, weights: weights)

        // Compute keeper confidence.
        let nextBestScore = sorted.count > 1 ? (compositeScores[sorted[1].id] ?? 0.0) : keeperScore
        let keeperConfidence = confidenceCalculator.confidence(
            keeperScore: keeperScore,
            nextBestScore: nextBestScore,
            similarityConfidence: baseSimilarityConfidence
        )

        var results: [CullRecommendation] = []

        for (index, asset) in sorted.enumerated() {
            if index == 0 {
                // Keeper
                results.append(CullRecommendation(
                    asset: asset,
                    action: .keep,
                    reasons: [],
                    confidence: keeperConfidence,
                    signalBreakdown: keeperBreakdown
                ))
            } else {
                // Potential cull — check suppression rules.
                let feat = features[asset.id]
                let assetSignals = signalMaps[asset.id] ?? [:]
                let assetBreakdown = compositeScorer.breakdown(signals: assetSignals, weights: weights)
                let cullConfidence = (baseSimilarityConfidence * 0.9).clamped(to: 0.5...0.95)
                let assetScore = compositeScores[asset.id] ?? 0.0

                // Rule B: missing-signal suppression
                if feat?.exposureScore == nil || feat?.subjectScore == nil {
                    results.append(CullRecommendation(
                        asset: asset,
                        action: .keep,
                        reasons: ["Insufficient quality data to recommend deletion."],
                        confidence: keeperConfidence,
                        signalBreakdown: assetBreakdown
                    ))
                    continue
                }

                // Rule C: accidental blur suppression (gated by enableBlurDetection).
                // Bypasses Rule A confidence suppression only — does not affect Rule B,
                // preservation tiers, or SafetyGuard (which runs after rank() returns).
                if configuration.enableBlurDetection {
                    let candidateSharpness = features[asset.id]?.sharpnessScore.value ?? 0.0
                    let keeperSharpness = features[keeper.id]?.sharpnessScore.value ?? 0.0
                    let blurResult = blurClassifier.classify(
                        candidateSharpness: candidateSharpness,
                        keeperSharpness: keeperSharpness,
                        asset: asset,
                        configuration: configuration
                    )
                    if blurResult == .accidental {
                        results.append(CullRecommendation(
                            asset: asset,
                            action: .cull,
                            reasons: ["Suggested for removal: likely accidental blur (sharpness \(String(format: "%.2f", candidateSharpness)) vs keeper \(String(format: "%.2f", keeperSharpness)))."],
                            confidence: cullConfidence,
                            signalBreakdown: assetBreakdown
                        ))
                        continue
                    }
                }

                // Rule A: confidence suppression
                let recommendationConfidence = confidenceCalculator.confidence(
                    keeperScore: keeperScore,
                    nextBestScore: assetScore,
                    similarityConfidence: baseSimilarityConfidence
                )
                if confidenceCalculator.isSuppressed(
                    confidence: recommendationConfidence,
                    threshold: configuration.confidenceThreshold
                ) {
                    results.append(CullRecommendation(
                        asset: asset,
                        action: .keep,
                        reasons: ["Scores too close to recommend deletion."],
                        confidence: recommendationConfidence,
                        signalBreakdown: assetBreakdown
                    ))
                    continue
                }

                results.append(CullRecommendation(
                    asset: asset,
                    action: .cull,
                    reasons: [],
                    confidence: cullConfidence,
                    signalBreakdown: assetBreakdown
                ))
            }
        }

        return results
    }

    // MARK: - Private helpers

    private func preservationTier(for asset: PhotoAsset) -> Int {
        if asset.isFavorite { return 0 }
        if asset.isEdited   { return 1 }
        return 2
    }

    private func buildSignalMaps(
        members: [PhotoAsset],
        features: [String: AssetFeatures],
        groupMaxPixels: Int
    ) -> [String: [QualitySignal: Double]] {
        var result: [String: [QualitySignal: Double]] = [:]
        for asset in members {
            let feat = features[asset.id]
            var signals: [QualitySignal: Double] = [:]
            signals[.sharpness] = feat?.sharpnessScore.value ?? 0.5
            signals[.exposure] = feat?.exposureScore ?? 0.5
            signals[.subjectQuality] = feat?.subjectScore ?? 0.5
            signals[.resolution] = resolutionScorer.score(
                asset: asset, groupMaxPixels: groupMaxPixels
            ).value
            result[asset.id] = signals
        }
        return result
    }

    private func buildCompositeScores(
        members: [PhotoAsset],
        signalMaps: [String: [QualitySignal: Double]],
        weights: [QualitySignal: Double]
    ) -> [String: Double] {
        var result: [String: Double] = [:]
        for asset in members {
            let signals = signalMaps[asset.id] ?? [:]
            result[asset.id] = compositeScorer.score(signals: signals, weights: weights)
        }
        return result
    }

    private func deriveSimilarityConfidence(
        memberIds: Set<String>,
        pairs: [CandidatePair]
    ) -> Double {
        let groupPairs = pairs.filter {
            memberIds.contains($0.assetIdA) && memberIds.contains($0.assetIdB)
        }
        guard !groupPairs.isEmpty else { return (1.0 - 0.1).clamped(to: 0.5...0.95) }
        let scores = groupPairs.compactMap(\.similarityScore)
        guard !scores.isEmpty else { return (1.0 - 0.1).clamped(to: 0.5...0.95) }
        let average = scores.reduce(0, +) / Double(scores.count)
        return (1.0 - average).clamped(to: 0.5...0.95)
    }
}

// MARK: - Clamping helper

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(range.upperBound, max(range.lowerBound, self))
    }
}
