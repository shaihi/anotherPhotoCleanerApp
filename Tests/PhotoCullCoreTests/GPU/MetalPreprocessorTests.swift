#if canImport(Metal) && canImport(CoreGraphics)
import XCTest
@testable import PhotoCullCore

final class MetalPreprocessorTests: XCTestCase {
    func testSkipsWhenNoMetal() throws {
        try XCTSkipUnless(MetalContext.shared != nil, "No Metal GPU available — skipping")
    }

    func testOutputDimensions() async throws {
        try XCTSkipUnless(MetalContext.shared != nil, "No Metal GPU available")
        let context = MetalContext.shared!
        let imageData = TestImageFactory.solidColor(width: 400, height: 300)
        let preprocessor = MetalPreprocessor(context: context, dataLoader: { _ in imageData })
        let result = try await preprocessor.preprocess(PhotoAsset(id: "m"))
        XCTAssertEqual(result.width, CPUPreprocessor.targetSize)
        XCTAssertEqual(result.height, CPUPreprocessor.targetSize)
    }

    func testPixelBufferByteCount() async throws {
        try XCTSkipUnless(MetalContext.shared != nil, "No Metal GPU available")
        let context = MetalContext.shared!
        let imageData = TestImageFactory.checkerboard()
        let preprocessor = MetalPreprocessor(context: context, dataLoader: { _ in imageData })
        let result = try await preprocessor.preprocess(PhotoAsset(id: "m"))
        let pb = try XCTUnwrap(result.pixelBuffer)
        let size = CPUPreprocessor.targetSize
        XCTAssertEqual(pb.data.count, size * size * 4)
    }

    func testMatchesCPUOutputDimensions() async throws {
        try XCTSkipUnless(MetalContext.shared != nil, "No Metal GPU available")
        let imageData = TestImageFactory.gradient()
        let context = MetalContext.shared!
        let metalResult = try await MetalPreprocessor(context: context, dataLoader: { _ in imageData })
            .preprocess(PhotoAsset(id: "x"))
        let cpuResult = try await CPUPreprocessor(dataLoader: { _ in imageData })
            .preprocess(PhotoAsset(id: "x"))
        XCTAssertEqual(metalResult.width, cpuResult.width)
        XCTAssertEqual(metalResult.height, cpuResult.height)
        XCTAssertEqual(metalResult.pixelBuffer?.bytesPerRow, cpuResult.pixelBuffer?.bytesPerRow)
    }
}
#endif
