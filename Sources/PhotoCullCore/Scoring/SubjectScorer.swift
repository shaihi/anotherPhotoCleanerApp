#if canImport(Vision) && canImport(CoreGraphics)
import Vision
import CoreGraphics
import Foundation

/// Scores subject quality using Vision attention-based saliency.
///
/// A higher score indicates more prominent or more plentiful salient subjects.
/// On any failure (Vision unavailable, request fails, etc.) returns a neutral 0.5.
///
/// Vision execution is system-managed; `usesCPUOnly` is never set.
public struct SubjectScorer: ImageScorerProtocol, Sendable {
    public init() {}

    public func score(asset: PhotoAsset, image: ProcessedImage) throws -> SignalValue {
        guard let cgImage = makeCGImage(from: image) else {
            return SignalValue(signal: .subjectQuality, value: 0.5)
        }
        return SignalValue(signal: .subjectQuality, value: saliencyScore(for: cgImage))
    }

    // MARK: - Private helpers

    private func makeCGImage(from image: ProcessedImage) -> CGImage? {
        guard let pb = image.pixelBuffer else { return nil }
        let bitmapInfo: UInt32
        switch pb.pixelFormat {
        case .rgba8Unorm:
            bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        case .bgra8Unorm:
            bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        }
        guard let provider = CGDataProvider(data: pb.data as CFData) else { return nil }
        return CGImage(
            width: pb.width,
            height: pb.height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: pb.bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    private func saliencyScore(for cgImage: CGImage) -> Double {
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return 0.5
        }
        guard let observation = request.results?.first as? VNSaliencyImageObservation,
              let objects = observation.salientObjects, !objects.isEmpty else {
            return 0.5
        }
        let totalArea = objects.reduce(0.0) { sum, obj in
            sum + Double(obj.boundingBox.width * obj.boundingBox.height)
        }
        return min(1.0, max(0.0, totalArea))
    }
}

#else
import Foundation

/// Stub when Vision or CoreGraphics is unavailable — always returns neutral score.
public struct SubjectScorer: ImageScorerProtocol, Sendable {
    public init() {}

    public func score(asset: PhotoAsset, image: ProcessedImage) throws -> SignalValue {
        SignalValue(signal: .subjectQuality, value: 0.5)
    }
}
#endif
