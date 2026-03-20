#if canImport(Vision)
import Vision
import CoreGraphics
import Foundation

/// Extracts image feature vectors using the Vision framework.
/// Vision manages hardware dispatch internally (CPU, GPU, or Neural Engine).
/// This component treats Vision as a black-box system service.
public struct VisionFeatureExtractor: FeatureExtractorProtocol {
    public init() {}

    public func extractFeatures(from image: ProcessedImage) async throws -> FeatureVector {
        guard let pb = image.pixelBuffer else {
            throw ProcessedImageError.missingPixelBuffer(assetId: image.assetId)
        }

        let cgImage = try Self.makeCGImage(from: pb, assetId: image.assetId)

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNGenerateImageFeaturePrintRequest { req, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let obs = req.results?.first as? VNFeaturePrintObservation else {
                    continuation.resume(throwing: VisionFeatureExtractorError.noObservation(assetId: image.assetId))
                    return
                }
                do {
                    let vector = try Self.extractVector(from: obs)
                    continuation.resume(returning: vector)
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func makeCGImage(from pb: PixelBuffer, assetId: String) throws -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let provider = CGDataProvider(data: pb.data as CFData),
              let cgImage = CGImage(
                width: pb.width,
                height: pb.height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: pb.bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            throw VisionFeatureExtractorError.cannotMakeCGImage(assetId: assetId)
        }
        return cgImage
    }

    private static func extractVector(from obs: VNFeaturePrintObservation) throws -> FeatureVector {
        guard obs.elementCount > 0 else {
            throw VisionFeatureExtractorError.emptyFeaturePrint
        }
        // elementType is .float for VNGenerateImageFeaturePrintRequest
        let floats = obs.data.withUnsafeBytes { rawPtr -> [Float] in
            let count = obs.elementCount
            let ptr = rawPtr.bindMemory(to: Float.self)
            return Array(ptr.prefix(count))
        }
        return FeatureVector(values: floats)
    }
}

public enum VisionFeatureExtractorError: Error, Sendable, Equatable {
    case noObservation(assetId: String)
    case cannotMakeCGImage(assetId: String)
    case emptyFeaturePrint
    case visionUnavailable
}

#else

import Foundation

/// Stub for platforms without Vision framework.
public struct VisionFeatureExtractor: FeatureExtractorProtocol {
    public init() {}
    public func extractFeatures(from image: ProcessedImage) async throws -> FeatureVector {
        throw VisionFeatureExtractorError.visionUnavailable
    }
}

public enum VisionFeatureExtractorError: Error, Sendable, Equatable {
    case noObservation(assetId: String)
    case cannotMakeCGImage(assetId: String)
    case emptyFeaturePrint
    case visionUnavailable
}
#endif
