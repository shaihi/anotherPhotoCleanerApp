import Foundation

/// Pixel format matching MTLPixelFormat naming conventions.
public enum PixelFormat: String, Sendable, Equatable, Hashable {
    case rgba8Unorm
    case bgra8Unorm
}

/// Self-describing raw pixel buffer. Bundles bytes with layout metadata so
/// downstream analyzers make no implicit assumptions about stride or format.
public struct PixelBuffer: Sendable, Equatable {
    public let data: Data
    public let width: Int
    public let height: Int
    public let bytesPerRow: Int
    public let pixelFormat: PixelFormat

    public init(data: Data, width: Int, height: Int, bytesPerRow: Int, pixelFormat: PixelFormat) {
        self.data = data
        self.width = width
        self.height = height
        self.bytesPerRow = bytesPerRow
        self.pixelFormat = pixelFormat
    }
}
