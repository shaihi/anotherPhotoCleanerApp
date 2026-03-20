import CoreGraphics
import Foundation
import ImageIO

/// CPU fallback for ImagePreprocessorProtocol.
/// Uses CoreGraphics to decode and resize images to the analysis size.
public struct CPUPreprocessor: ImagePreprocessorProtocol {
    /// Side length of the square output image.
    public static let targetSize = 512

    private let dataLoader: @Sendable (PhotoAsset) async throws -> Data

    public init(dataLoader: @escaping @Sendable (PhotoAsset) async throws -> Data) {
        self.dataLoader = dataLoader
    }

    public func preprocess(_ asset: PhotoAsset) async throws -> ProcessedImage {
        let rawData = try await dataLoader(asset)
        let pixelBuffer = try Self.resize(data: rawData, assetId: asset.id)
        return ProcessedImage(
            assetId: asset.id,
            width: Self.targetSize,
            height: Self.targetSize,
            pixelBuffer: pixelBuffer
        )
    }

    /// Resize raw image data to targetSize×targetSize RGBA.
    static func resize(data: Data, assetId: String) throws -> PixelBuffer {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw CPUPreprocessorError.cannotDecodeImage(assetId: assetId)
        }

        let size = targetSize
        let bytesPerRow = size * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw CPUPreprocessorError.cannotCreateContext(assetId: assetId)
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))

        guard let ptr = context.data else {
            throw CPUPreprocessorError.cannotReadPixels(assetId: assetId)
        }

        let pixelData = Data(bytes: ptr, count: size * bytesPerRow)
        return PixelBuffer(
            data: pixelData,
            width: size,
            height: size,
            bytesPerRow: bytesPerRow,
            pixelFormat: .rgba8Unorm
        )
    }
}

public enum CPUPreprocessorError: Error, Sendable, Equatable {
    case cannotDecodeImage(assetId: String)
    case cannotCreateContext(assetId: String)
    case cannotReadPixels(assetId: String)
}
