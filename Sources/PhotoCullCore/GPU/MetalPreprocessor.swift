#if canImport(Metal) && canImport(MetalPerformanceShaders)
import Metal
import MetalPerformanceShaders
import CoreGraphics
import ImageIO
import Foundation

/// GPU-accelerated preprocessor using MPS bilinear scaling.
/// Falls back to CPUPreprocessor when Metal is unavailable.
public struct MetalPreprocessor: ImagePreprocessorProtocol {
    private let context: MetalContext
    private let dataLoader: @Sendable (PhotoAsset) async throws -> Data

    public init(context: MetalContext, dataLoader: @escaping @Sendable (PhotoAsset) async throws -> Data) {
        self.context = context
        self.dataLoader = dataLoader
    }

    public func preprocess(_ asset: PhotoAsset) async throws -> ProcessedImage {
        let rawData = try await dataLoader(asset)

        let maxSourcePixels = 2048

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSourcePixels
        ]

        guard let source = CGImageSourceCreateWithData(rawData as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            throw CPUPreprocessorError.cannotDecodeImage(assetId: asset.id)
        }

        let size = CPUPreprocessor.targetSize
        let device = context.device

        // Input texture
        let inputDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: cgImage.width,
            height: cgImage.height,
            mipmapped: false
        )
        inputDesc.usage = [.shaderRead, .shaderWrite]
        guard let inputTexture = device.makeTexture(descriptor: inputDesc) else {
            // Fall back to CPU
            let pixelBuffer = try CPUPreprocessor.resize(data: rawData, assetId: asset.id)
            return ProcessedImage(assetId: asset.id, width: size, height: size, pixelBuffer: pixelBuffer)
        }

        // Upload CGImage pixels to the input texture
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let bytesPerRow = cgImage.width * 4
        var rawPixels = [UInt8](repeating: 0, count: cgImage.height * bytesPerRow)
        rawPixels.withUnsafeMutableBytes { ptr in
            guard let ctx = CGContext(
                data: ptr.baseAddress,
                width: cgImage.width,
                height: cgImage.height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else { return }
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        }
        inputTexture.replace(
            region: MTLRegionMake2D(0, 0, cgImage.width, cgImage.height),
            mipmapLevel: 0,
            withBytes: rawPixels,
            bytesPerRow: bytesPerRow
        )

        // Output texture at target size
        let outputDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: size,
            height: size,
            mipmapped: false
        )
        outputDesc.usage = [.shaderRead, .shaderWrite]
        guard let outputTexture = device.makeTexture(descriptor: outputDesc),
              let commandBuffer = context.commandQueue.makeCommandBuffer() else {
            let pixelBuffer = try CPUPreprocessor.resize(data: rawData, assetId: asset.id)
            return ProcessedImage(assetId: asset.id, width: size, height: size, pixelBuffer: pixelBuffer)
        }

        // MPS bilinear scale
        let scale = MPSImageBilinearScale(device: device)
        scale.encode(commandBuffer: commandBuffer, sourceTexture: inputTexture, destinationTexture: outputTexture)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            commandBuffer.addCompletedHandler { buffer in
                if let error = buffer.error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
            commandBuffer.commit()
        }

        // Read back pixels
        let outBytesPerRow = size * 4
        var outPixels = [UInt8](repeating: 0, count: size * outBytesPerRow)
        outPixels.withUnsafeMutableBytes { ptr in
            outputTexture.getBytes(
                ptr.baseAddress!,
                bytesPerRow: outBytesPerRow,
                from: MTLRegionMake2D(0, 0, size, size),
                mipmapLevel: 0
            )
        }

        let pixelData = Data(outPixels)
        let pixelBuffer = PixelBuffer(
            data: pixelData,
            width: size,
            height: size,
            bytesPerRow: outBytesPerRow,
            pixelFormat: .rgba8Unorm
        )
        return ProcessedImage(assetId: asset.id, width: size, height: size, pixelBuffer: pixelBuffer)
    }
}
#else
/// Stub when Metal is not available — delegates to CPUPreprocessor.
public struct MetalPreprocessor: ImagePreprocessorProtocol {
    private let fallback: CPUPreprocessor

    public init(context: MetalContext?, dataLoader: @escaping @Sendable (PhotoAsset) async throws -> Data) {
        self.fallback = CPUPreprocessor(dataLoader: dataLoader)
    }

    public func preprocess(_ asset: PhotoAsset) async throws -> ProcessedImage {
        try await fallback.preprocess(asset)
    }
}
#endif
