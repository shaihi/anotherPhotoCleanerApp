import Foundation

/// Shared Laplacian-variance normalization used by both CPU and Metal sharpness analyzers.
/// Maps raw variance (0 → ∞) to a score in [0, 1].
/// Formula: score = 1 - exp(-variance / scale)
/// scale = 500 is calibrated so:
///   - A uniform solid-color image (variance ≈ 0) → score ≈ 0
///   - A high-contrast checkerboard at 512×512 (variance ≈ several thousand) → score > 0.9
enum SharpnessNormalization {
    static let scale: Double = 500.0

    static func normalize(variance: Double) -> Double {
        let clamped = max(0, variance)
        return 1.0 - exp(-clamped / scale)
    }
}
