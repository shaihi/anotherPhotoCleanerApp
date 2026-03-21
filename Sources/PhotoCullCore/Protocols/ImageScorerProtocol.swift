import Foundation

/// Scores a single quality signal for an asset using an already-prepared `ProcessedImage`.
///
/// Implementations MUST NOT load or decode image data themselves — they receive a
/// `ProcessedImage` that has already been preprocessed by the pipeline.
public protocol ImageScorerProtocol: Sendable {
    /// Compute a quality signal value for the given asset and pre-processed image.
    func score(asset: PhotoAsset, image: ProcessedImage) throws -> SignalValue
}
