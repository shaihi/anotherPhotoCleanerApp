#if canImport(CoreGraphics)
import XCTest
@testable import PhotoCullCore

final class CPUPreprocessorTests: XCTestCase {
    let targetSize = CPUPreprocessor.targetSize

    func makeLoader(_ data: Data) -> @Sendable (PhotoAsset) async throws -> Data {
        { _ in data }
    }

    func testOutputDimensions() async throws {
        let imageData = TestImageFactory.solidColor(width: 200, height: 150)
        let preprocessor = CPUPreprocessor(dataLoader: makeLoader(imageData))
        let result = try await preprocessor.preprocess(PhotoAsset(id: "t"))
        XCTAssertEqual(result.width, targetSize)
        XCTAssertEqual(result.height, targetSize)
    }

    func testPixelBufferIsPopulated() async throws {
        let imageData = TestImageFactory.solidColor()
        let preprocessor = CPUPreprocessor(dataLoader: makeLoader(imageData))
        let result = try await preprocessor.preprocess(PhotoAsset(id: "t"))
        XCTAssertNotNil(result.pixelBuffer)
    }

    func testPixelBufferByteCount() async throws {
        let imageData = TestImageFactory.solidColor()
        let preprocessor = CPUPreprocessor(dataLoader: makeLoader(imageData))
        let result = try await preprocessor.preprocess(PhotoAsset(id: "t"))
        let pb = try XCTUnwrap(result.pixelBuffer)
        XCTAssertEqual(pb.data.count, targetSize * targetSize * 4)
        XCTAssertEqual(pb.bytesPerRow, targetSize * 4)
    }

    func testPixelBufferFormat() async throws {
        let imageData = TestImageFactory.solidColor()
        let preprocessor = CPUPreprocessor(dataLoader: makeLoader(imageData))
        let result = try await preprocessor.preprocess(PhotoAsset(id: "t"))
        XCTAssertEqual(result.pixelBuffer?.pixelFormat, .rgba8Unorm)
    }

    func testAssetIdPreserved() async throws {
        let preprocessor = CPUPreprocessor(dataLoader: makeLoader(TestImageFactory.solidColor()))
        let result = try await preprocessor.preprocess(PhotoAsset(id: "my-asset"))
        XCTAssertEqual(result.assetId, "my-asset")
    }
}
#endif
