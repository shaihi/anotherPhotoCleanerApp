import Foundation

/// Preprocessed image ready for GPU analysis.
/// `pixelBuffer` is nil when constructed by Phase 1 callers (no pixel data attached).
/// Phase 2 preprocessors always populate it.
public struct ProcessedImage: Sendable, Equatable {
    public let assetId: String
    public let width: Int
    public let height: Int
    public let pixelBuffer: PixelBuffer?

    public init(assetId: String, width: Int, height: Int, pixelBuffer: PixelBuffer? = nil) {
        self.assetId = assetId
        self.width = width
        self.height = height
        self.pixelBuffer = pixelBuffer
    }
}

public enum ProcessedImageError: Error, Sendable, Equatable {
    case missingPixelBuffer(assetId: String)
}

/// Converts a PhotoAsset into a ProcessedImage for analysis.
/// Phase 2: MetalPreprocessor (GPU), CPUPreprocessor (fallback).
public protocol ImagePreprocessorProtocol: Sendable {
    func preprocess(_ asset: PhotoAsset) async throws -> ProcessedImage
}
