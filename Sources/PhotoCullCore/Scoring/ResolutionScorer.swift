import Foundation

/// Scores resolution relative to the group maximum pixel count.
///
/// This scorer reads only from `PhotoAsset` metadata — it does NOT conform to
/// `ImageScorerProtocol` because it requires no image data.
public struct ResolutionScorer: Sendable {
    public init() {}

    /// Returns a `.resolution` signal value in [0, 1] relative to `groupMaxPixels`.
    ///
    /// - Parameters:
    ///   - asset: The asset whose pixel dimensions to evaluate.
    ///   - groupMaxPixels: Pixel count of the largest-resolution asset in the group.
    /// - Returns: `SignalValue` with `.resolution` signal.
    public func score(asset: PhotoAsset, groupMaxPixels: Int) -> SignalValue {
        let pixels = asset.pixelWidth * asset.pixelHeight
        guard groupMaxPixels > 0, pixels > 0 else {
            return SignalValue(signal: .resolution, value: 0.0)
        }
        let value = Double(pixels) / Double(groupMaxPixels)
        return SignalValue(signal: .resolution, value: value)
    }
}
