import Accelerate
import Foundation

/// CPU sharpness analyzer using a 3×3 Laplacian convolution via Accelerate.
/// Uses the same SharpnessNormalization as the Metal path.
public struct CPUSharpnessAnalyzer: SharpnessAnalyzerProtocol {
    public init() {}

    public func analyzeSharpness(of image: ProcessedImage) async throws -> SharpnessScore {
        guard let pb = image.pixelBuffer else {
            throw ProcessedImageError.missingPixelBuffer(assetId: image.assetId)
        }
        let variance = Self.laplacianVariance(pixelBuffer: pb)
        let score = SharpnessNormalization.normalize(variance: variance)
        return SharpnessScore(value: score)
    }

    /// Computes the variance of a 3×3 Laplacian applied to the luminance channel.
    static func laplacianVariance(pixelBuffer pb: PixelBuffer) -> Double {
        let w = pb.width
        let h = pb.height
        let bpr = pb.bytesPerRow

        // Extract luminance (BT.601 weights) as Float array
        var luma = [Float](repeating: 0, count: w * h)
        pb.data.withUnsafeBytes { rawPtr in
            let bytes = rawPtr.bindMemory(to: UInt8.self)
            for y in 0..<h {
                for x in 0..<w {
                    let offset = y * bpr + x * 4
                    let r = Float(bytes[offset])
                    let g = Float(bytes[offset + 1])
                    let b = Float(bytes[offset + 2])
                    luma[y * w + x] = 0.299 * r + 0.587 * g + 0.114 * b
                }
            }
        }

        // 3×3 Laplacian kernel:  0  1  0
        //                        1 -4  1
        //                        0  1  0
        var laplacian = [Float](repeating: 0, count: w * h)
        for y in 1..<(h - 1) {
            for x in 1..<(w - 1) {
                let center = luma[y * w + x]
                let top    = luma[(y - 1) * w + x]
                let bottom = luma[(y + 1) * w + x]
                let left   = luma[y * w + (x - 1)]
                let right  = luma[y * w + (x + 1)]
                laplacian[y * w + x] = top + bottom + left + right - 4 * center
            }
        }

        // Variance of Laplacian values (interior pixels only)
        let count = vDSP_Length(w * h)
        var mean: Float = 0
        vDSP_meanv(laplacian, 1, &mean, count)

        var variance: Float = 0
        var negMean = -mean
        vDSP_vsadd(laplacian, 1, &negMean, &laplacian, 1, count)
        vDSP_svesq(laplacian, 1, &variance, count)
        variance /= Float(count)

        return Double(variance)
    }
}
