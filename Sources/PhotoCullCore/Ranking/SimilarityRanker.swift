import Foundation

/// Ranks members of a near-duplicate or burst group using preservation-first logic.
///
/// **Tier priority (hard order)**
/// 1. `isFavorite` — a favorite is never demoted below a non-favorite.
/// 2. `isEdited` — edited beats non-edited within the same favourite tier.
/// 3. Highest sharpness score.
/// 4. Newest `creationDate`.
///
/// **Confidence derivation**
/// Confidence values are derived from the group's pair distances so they reflect
/// actual similarity strength rather than being hard-coded constants.
public struct SimilarityRanker: Sendable {
    public init() {}

    /// Produces one `.keep` recommendation (the best member) and `.cull` for all others.
    ///
    /// - Parameters:
    ///   - group: The group to rank.
    ///   - features: Asset features keyed by asset ID; used for sharpness scores.
    ///   - pairs: All confirmed pairs for the scan; only pairs whose members are in
    ///     this group are used to derive confidence values.
    public func rank(
        group: CullGroup,
        features: [String: AssetFeatures],
        pairs: [CandidatePair]
    ) -> [CullRecommendation] {
        let memberIds = Set(group.members.map(\.id))

        // Sort members: best first.
        let sorted = group.members.sorted { a, b in
            // Tier 1: favorite
            if a.isFavorite != b.isFavorite { return a.isFavorite }
            // Tier 2: edited
            if a.isEdited != b.isEdited { return a.isEdited }
            // Tier 3: sharpness
            let sharpA = features[a.id]?.sharpnessScore.value ?? 0
            let sharpB = features[b.id]?.sharpnessScore.value ?? 0
            if sharpA != sharpB { return sharpA > sharpB }
            // Tier 4: newest creation date
            let dateA = a.creationDate ?? .distantPast
            let dateB = b.creationDate ?? .distantPast
            return dateA > dateB
        }

        // Derive confidence from average pair distance.
        let groupPairs = pairs.filter {
            memberIds.contains($0.assetIdA) && memberIds.contains($0.assetIdB)
        }
        let averageDistance: Double = {
            guard !groupPairs.isEmpty else { return 0.1 }
            let sum = groupPairs.compactMap(\.similarityScore).reduce(0, +)
            let count = groupPairs.compactMap(\.similarityScore).count
            return count > 0 ? sum / Double(count) : 0.1
        }()
        let baseSimilarityConfidence = (1.0 - averageDistance).clamped(to: 0.5...0.95)

        // Rank separation bonus: reward clear sharpness dominance.
        let keeperSharpness = features[sorted[0].id]?.sharpnessScore.value ?? 0
        let nextBestSharpness = sorted.count > 1 ? (features[sorted[1].id]?.sharpnessScore.value ?? 0) : keeperSharpness
        let sharpnessDelta = max(0, keeperSharpness - nextBestSharpness)
        let rankSeparationBonus = min(1.0, sharpnessDelta / 0.2 + 0.8)

        let keeperConfidence = (baseSimilarityConfidence * rankSeparationBonus).clamped(to: 0.5...0.95)
        let cullConfidence = (baseSimilarityConfidence * 0.9).clamped(to: 0.5...0.95)

        return sorted.enumerated().map { index, asset in
            let action: CullAction = index == 0 ? .keep : .cull
            let confidence = action == .keep ? keeperConfidence : cullConfidence
            return CullRecommendation(
                asset: asset,
                action: action,
                reasons: [],    // ExplanationBuilder fills these in
                confidence: confidence
            )
        }
    }
}

// MARK: - Comparable clamping helper

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(range.upperBound, max(range.lowerBound, self))
    }
}
