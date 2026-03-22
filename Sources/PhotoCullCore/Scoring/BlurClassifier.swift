import Foundation

/// The result of classifying a photo's sharpness relative to its group keeper.
public enum BlurClassification: Sendable, Equatable {
    /// Both the absolute and relative blur conditions are met, and the asset is Tier 2
    /// (not isFavorite or isEdited). The photo is likely accidentally blurry.
    case accidental
    /// One or both conditions are not met, or the keeper is not sharp enough to provide
    /// a reliable reference. No confident blur classification can be made.
    case unclear
    /// Both conditions are met, but the asset is isFavorite or isEdited (Tier 0/1).
    /// Preservation rules already protect it; this case is informational only.
    case preserved
}

/// CPU-only blur classifier. Operates on already-computed `sharpnessScore` values
/// from `AssetFeatures` — no pixel access, no async work, no new frameworks.
///
/// Accidental blur is classified when BOTH conditions hold:
/// 1. Absolute: `candidateSharpness < accidentalBlurThreshold`
/// 2. Relative: `candidateSharpness < keeperSharpness × blurRelativeFactor`
///    AND `keeperSharpness ≥ blurKeeperSharpnessMinimum` (reference must be reliable)
///
/// All three parameters come from `CullConfiguration` and are calibrated against
/// the `SharpnessNormalization.normalize(variance:)` output range [0, 1].
public struct BlurClassifier: Sendable {
    public init() {}

    /// Classifies whether `candidate` is accidentally blurry relative to `keeperSharpness`.
    ///
    /// - Parameters:
    ///   - candidateSharpness: Normalized sharpness score for the candidate asset (injected
    ///     from `AssetFeatures.sharpnessScore.value`). In production this is computed by
    ///     `MetalSharpnessAnalyzer` or `CPUSharpnessAnalyzer`; in tests it is an injected
    ///     synthetic value chosen to deterministically satisfy or violate the thresholds.
    ///   - keeperSharpness: Normalized sharpness score for the group keeper.
    ///   - asset: The candidate `PhotoAsset` — used to check preservation tier.
    ///   - configuration: Thresholds sourced from `CullConfiguration`.
    public func classify(
        candidateSharpness: Double,
        keeperSharpness: Double,
        asset: PhotoAsset,
        configuration: CullConfiguration
    ) -> BlurClassification {
        let absoluteMet = candidateSharpness < configuration.accidentalBlurThreshold
        let keeperReliable = keeperSharpness >= configuration.blurKeeperSharpnessMinimum
        let relativeMet = keeperReliable &&
            candidateSharpness < keeperSharpness * configuration.blurRelativeFactor

        guard absoluteMet && relativeMet else { return .unclear }

        if asset.isFavorite || asset.isEdited { return .preserved }
        return .accidental
    }
}
