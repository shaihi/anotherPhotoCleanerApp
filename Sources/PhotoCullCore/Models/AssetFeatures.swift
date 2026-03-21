import Foundation

/// Extracted features for a single asset used during near-duplicate scoring.
public struct AssetFeatures: Sendable, Equatable {
    public let assetId: String
    /// Vision feature vector for cosine similarity comparison.
    public let featureVector: FeatureVector
    /// Normalized sharpness score in [0, 1].
    public let sharpnessScore: SharpnessScore
    /// Phase 4: CIAreaAverage-based exposure score in [0, 1]. Nil if not yet scored.
    public var exposureScore: Double?
    /// Phase 4: Vision attention-saliency subject score in [0, 1]. Nil if not yet scored.
    public var subjectScore: Double?

    public init(
        assetId: String,
        featureVector: FeatureVector,
        sharpnessScore: SharpnessScore,
        exposureScore: Double? = nil,
        subjectScore: Double? = nil
    ) {
        self.assetId = assetId
        self.featureVector = featureVector
        self.sharpnessScore = sharpnessScore
        self.exposureScore = exposureScore
        self.subjectScore = subjectScore
    }
}
