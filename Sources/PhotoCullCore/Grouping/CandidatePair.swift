import Foundation

/// The reason a pair was nominated as a candidate for near-duplicate or burst grouping.
public enum PrefilterReason: Sendable, Equatable {
    /// Both assets share the same PHAsset burst identifier.
    case burstId
    /// The assets' creation dates fall within the configured time window.
    case timeProximity
}

/// A nominated pair of assets that may be near-duplicates or burst siblings.
/// `similarityScore` is `nil` until the `SimilarityScorer` evaluates the pair.
public struct CandidatePair: Sendable, Equatable {
    public let assetIdA: String
    public let assetIdB: String
    public let prefilterReason: PrefilterReason
    /// Cosine distance in [0, 1]. Nil until scored by `SimilarityScorer`.
    public var similarityScore: Double?

    public init(
        assetIdA: String,
        assetIdB: String,
        prefilterReason: PrefilterReason,
        similarityScore: Double? = nil
    ) {
        self.assetIdA = assetIdA
        self.assetIdB = assetIdB
        self.prefilterReason = prefilterReason
        self.similarityScore = similarityScore
    }
}
