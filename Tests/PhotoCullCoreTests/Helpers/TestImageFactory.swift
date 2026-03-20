#if canImport(CoreGraphics)
import CoreGraphics
import Foundation
import ImageIO
@testable import PhotoCullCore

/// Generates synthetic images as Data for use in tests.
enum TestImageFactory {
    /// Solid single-color image. Laplacian variance ≈ 0 → sharpness score ≈ 0.
    static func solidColor(width: Int = 64, height: Int = 64,
                           r: UInt8 = 128, g: UInt8 = 128, b: UInt8 = 128) -> Data {
        makeImageData(width: width, height: height) { x, y in (r, g, b) }
    }

    /// High-contrast checkerboard. High Laplacian variance → sharpness score > 0.7.
    static func checkerboard(width: Int = 64, height: Int = 64, squareSize: Int = 4) -> Data {
        makeImageData(width: width, height: height) { x, y in
            let even = ((x / squareSize) + (y / squareSize)) % 2 == 0
            return even ? (UInt8(255), UInt8(255), UInt8(255)) : (UInt8(0), UInt8(0), UInt8(0))
        }
    }

    /// Horizontal gradient — medium sharpness.
    static func gradient(width: Int = 64, height: Int = 64) -> Data {
        makeImageData(width: width, height: height) { x, y in
            let v = UInt8(x * 255 / max(1, width - 1))
            return (v, v, v)
        }
    }

    // MARK: - PixelBuffer helpers (for analyzer unit tests — no encode/decode round-trip)

    static func solidColorPixelBuffer(width: Int = 64, height: Int = 64,
                                      r: UInt8 = 128, g: UInt8 = 128, b: UInt8 = 128) -> PixelBuffer {
        makePixelBuffer(width: width, height: height) { x, y in (r, g, b) }
    }

    static func checkerboardPixelBuffer(width: Int = 64, height: Int = 64, squareSize: Int = 4) -> PixelBuffer {
        makePixelBuffer(width: width, height: height) { x, y in
            let even = ((x / squareSize) + (y / squareSize)) % 2 == 0
            return even ? (UInt8(255), UInt8(255), UInt8(255)) : (UInt8(0), UInt8(0), UInt8(0))
        }
    }

    static func gradientPixelBuffer(width: Int = 64, height: Int = 64) -> PixelBuffer {
        makePixelBuffer(width: width, height: height) { x, y in
            let v = UInt8(x * 255 / max(1, width - 1))
            return (v, v, v)
        }
    }

    // MARK: - Private

    private static func makePixelBuffer(
        width: Int, height: Int,
        pixel: (Int, Int) -> (UInt8, UInt8, UInt8)
    ) -> PixelBuffer {
        let bpr = width * 4
        var bytes = [UInt8](repeating: 255, count: height * bpr)
        for y in 0..<height {
            for x in 0..<width {
                let (r, g, b) = pixel(x, y)
                let i = y * bpr + x * 4
                bytes[i] = r; bytes[i+1] = g; bytes[i+2] = b; bytes[i+3] = 255
            }
        }
        return PixelBuffer(data: Data(bytes), width: width, height: height, bytesPerRow: bpr, pixelFormat: .rgba8Unorm)
    }

    private static func makeImageData(
        width: Int, height: Int,
        pixel: (Int, Int) -> (UInt8, UInt8, UInt8)
    ) -> Data {
        let pb = makePixelBuffer(width: width, height: height, pixel: pixel)
        // Encode as PNG via CGImage
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(data: nil, width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: pb.bytesPerRow,
                                  space: colorSpace, bitmapInfo: bitmapInfo) else {
            return pb.data  // fallback: return raw bytes (not valid PNG but usable for some tests)
        }
        pb.data.withUnsafeBytes { rawPtr in
            guard let baseAddress = rawPtr.baseAddress else { return }
            let src = baseAddress.assumingMemoryBound(to: UInt8.self)
            let dst = ctx.data!.assumingMemoryBound(to: UInt8.self)
            dst.update(from: src, count: pb.data.count)
        }
        guard let cgImage = ctx.makeImage() else { return pb.data }
        let mutable = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(mutable, "public.png" as CFString, 1, nil) else {
            return pb.data
        }
        CGImageDestinationAddImage(dest, cgImage, nil)
        CGImageDestinationFinalize(dest)
        return mutable as Data
    }
}
#endif
