#if canImport(CoreImage)
import CoreImage
import Foundation

/// Scores exposure quality using mean luminance via CIAreaHistogram.
///
/// A score of 1.0 means ideal mid-tone exposure (mean luminance ≈ 0.5).
/// Extreme under- or over-exposure yields lower scores.
///
/// On any failure the scorer returns a neutral 0.5 rather than throwing.
public struct ExposureScorer: ImageScorerProtocol, Sendable {
    public init() {}

    public func score(asset: PhotoAsset, image: ProcessedImage) throws -> SignalValue {
        guard let ciImage = makeCIImage(from: image) else {
            return SignalValue(signal: .exposure, value: 0.5)
        }
        let meanLuminance = computeMeanLuminance(from: ciImage)
        let raw = 1.0 - 2.0 * abs(meanLuminance - 0.5)
        let clamped = min(1.0, max(0.0, raw))
        return SignalValue(signal: .exposure, value: clamped)
    }

    // MARK: - Private helpers

    private func makeCIImage(from image: ProcessedImage) -> CIImage? {
        guard let pb = image.pixelBuffer else { return nil }

        // Build CIImage directly from the raw RGBA pixel data.
        let bitmapFormat: CIFormat
        switch pb.pixelFormat {
        case .rgba8Unorm:
            bitmapFormat = .RGBA8
        case .bgra8Unorm:
            bitmapFormat = .BGRA8
        }
        let ciImage = pb.data.withUnsafeBytes { rawPtr -> CIImage? in
            guard let base = rawPtr.baseAddress else { return nil }
            return CIImage(
                bitmapData: Data(bytes: base, count: pb.data.count),
                bytesPerRow: pb.bytesPerRow,
                size: CGSize(width: pb.width, height: pb.height),
                format: bitmapFormat,
                colorSpace: CGColorSpaceCreateDeviceRGB()
            )
        }
        return ciImage
    }

    private func computeMeanLuminance(from ciImage: CIImage) -> Double {
        // Use CIAreaAverage (single-pixel average of the whole image) to get mean color.
        // CIAreaHistogram is also valid but CIAreaAverage gives us mean luminance more directly.
        let context = CIContext(options: [.useSoftwareRenderer: false])
        let extent = ciImage.extent
        guard !extent.isNull, !extent.isInfinite else { return 0.5 }

        guard let filter = CIFilter(name: "CIAreaAverage") else { return 0.5 }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: extent), forKey: "inputExtent")
        guard let output = filter.outputImage else { return 0.5 }

        // Read back the single averaged pixel.
        var pixel = [Float](repeating: 0, count: 4)
        context.render(
            output,
            toBitmap: &pixel,
            rowBytes: 16,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBAf,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        let r = Double(pixel[0])
        let g = Double(pixel[1])
        let b = Double(pixel[2])

        // Rec 709 luma coefficients.
        let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
        guard luma.isFinite else { return 0.5 }
        return min(1.0, max(0.0, luma))
    }
}

#else
import Foundation

/// Stub when CoreImage is unavailable — always returns neutral exposure score.
public struct ExposureScorer: ImageScorerProtocol, Sendable {
    public init() {}

    public func score(asset: PhotoAsset, image: ProcessedImage) throws -> SignalValue {
        SignalValue(signal: .exposure, value: 0.5)
    }
}
#endif
