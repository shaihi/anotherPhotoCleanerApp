import Foundation

/// Scores candidate pairs using cosine distance and filters confirmed near-duplicates.
public struct SimilarityScorer: Sendable {
    public init() {}

    // MARK: - Public API

    /// Computes the cosine distance between two feature vectors.
    /// - Returns: A value in [0, 1] where 0 means identical and 1 means orthogonal.
    ///   Returns 1.0 if either vector has a zero norm (undefined similarity).
    public func score(a: [Float], b: [Float]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 1.0 }
        let dot = zip(a, b).reduce(Float(0)) { $0 + $1.0 * $1.1 }
        let normA = sqrt(a.reduce(Float(0)) { $0 + $1 * $1 })
        let normB = sqrt(b.reduce(Float(0)) { $0 + $1 * $1 })
        guard normA > 0, normB > 0 else { return 1.0 }
        let cosine = Double(dot) / (Double(normA) * Double(normB))
        // Clamp to [0, 1] to handle floating-point rounding past 1.
        return max(0.0, min(1.0, 1.0 - cosine))
    }

    /// Returns `true` when the cosine distance is strictly below `threshold`.
    public func isConfirmed(distance: Double, threshold: Double) -> Bool {
        distance < threshold
    }

    /// Scores every pair, sets `similarityScore`, and returns only confirmed pairs.
    /// Pairs whose asset features are missing from `features` are silently dropped.
    ///
    /// - Parameters:
    ///   - pairs: Candidate pairs nominated by `MetadataPrefilter`.
    ///   - features: Map of `assetId` → `AssetFeatures` for all candidates.
    ///   - threshold: Cosine-distance threshold; pairs below this value are confirmed.
    /// - Returns: Scored pairs with `similarityScore` set, filtered to confirmed only.
    public func confirmPairs(
        _ pairs: [CandidatePair],
        features: [String: AssetFeatures],
        threshold: Double
    ) -> [CandidatePair] {
        pairs.compactMap { pair in
            guard let featA = features[pair.assetIdA],
                  let featB = features[pair.assetIdB] else {
                return nil
            }
            let distance = score(a: featA.featureVector.values, b: featB.featureVector.values)
            guard isConfirmed(distance: distance, threshold: threshold) else { return nil }
            return CandidatePair(
                assetIdA: pair.assetIdA,
                assetIdB: pair.assetIdB,
                prefilterReason: pair.prefilterReason,
                similarityScore: distance
            )
        }
    }
}
