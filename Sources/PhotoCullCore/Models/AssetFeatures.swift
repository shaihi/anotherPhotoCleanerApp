import Foundation

/// Extracted features for a single asset used during near-duplicate scoring.
public struct AssetFeatures: Sendable, Equatable {
    public let assetId: String
    /// Vision feature vector for cosine similarity comparison.
    public let featureVector: FeatureVector
    /// Normalized sharpness score in [0, 1].
    public let sharpnessScore: SharpnessScore

    public init(assetId: String, featureVector: FeatureVector, sharpnessScore: SharpnessScore) {
        self.assetId = assetId
        self.featureVector = featureVector
        self.sharpnessScore = sharpnessScore
    }
}
