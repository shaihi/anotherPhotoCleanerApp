import XCTest
@testable import PhotoCullCore

final class ProcessedImageTests: XCTestCase {
    // Backward compat: three-argument init still works, pixelBuffer defaults to nil
    func testLegacyInitProducesNilPixelBuffer() {
        let img = ProcessedImage(assetId: "a", width: 100, height: 100)
        XCTAssertNil(img.pixelBuffer)
    }

    func testNewInitPopulatesPixelBuffer() {
        let pb = PixelBuffer(data: Data(repeating: 0, count: 16),
                             width: 2, height: 2, bytesPerRow: 8, pixelFormat: .rgba8Unorm)
        let img = ProcessedImage(assetId: "b", width: 2, height: 2, pixelBuffer: pb)
        XCTAssertNotNil(img.pixelBuffer)
        XCTAssertEqual(img.pixelBuffer?.pixelFormat, .rgba8Unorm)
    }

    func testPixelBufferEquality() {
        let pb = PixelBuffer(data: Data([1,2,3,4]), width: 1, height: 1, bytesPerRow: 4, pixelFormat: .rgba8Unorm)
        let a = ProcessedImage(assetId: "x", width: 1, height: 1, pixelBuffer: pb)
        let b = ProcessedImage(assetId: "x", width: 1, height: 1, pixelBuffer: pb)
        XCTAssertEqual(a, b)
    }

    func testPixelBufferStoresAllMetadata() {
        let pb = PixelBuffer(data: Data(repeating: 255, count: 512*512*4),
                             width: 512, height: 512, bytesPerRow: 512*4, pixelFormat: .bgra8Unorm)
        XCTAssertEqual(pb.width, 512)
        XCTAssertEqual(pb.height, 512)
        XCTAssertEqual(pb.bytesPerRow, 512 * 4)
        XCTAssertEqual(pb.pixelFormat, .bgra8Unorm)
    }
}
