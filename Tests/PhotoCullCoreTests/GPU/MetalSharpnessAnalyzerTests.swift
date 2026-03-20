#if canImport(Metal) && canImport(CoreGraphics)
import XCTest
@testable import PhotoCullCore

final class MetalSharpnessAnalyzerTests: XCTestCase {
    func testSkipsWhenNoMetal() throws {
        try XCTSkipUnless(MetalContext.shared != nil, "No Metal GPU available — skipping")
    }

    func testSolidColorIsNearZero() async throws {
        try XCTSkipUnless(MetalContext.shared != nil, "No Metal GPU available")
        let context = MetalContext.shared!
        let analyzer = try MetalSharpnessAnalyzer(context: context)
        let pb = TestImageFactory.solidColorPixelBuffer(width: 64, height: 64)
        let img = ProcessedImage(assetId: "s", width: 64, height: 64, pixelBuffer: pb)
        let score = try await analyzer.analyzeSharpness(of: img)
        XCTAssertLessThan(score.value, 0.15)
    }

    func testCheckerboardIsHigh() async throws {
        try XCTSkipUnless(MetalContext.shared != nil, "No Metal GPU available")
        let context = MetalContext.shared!
        let analyzer = try MetalSharpnessAnalyzer(context: context)
        let pb = TestImageFactory.checkerboardPixelBuffer(width: 64, height: 64, squareSize: 2)
        let img = ProcessedImage(assetId: "c", width: 64, height: 64, pixelBuffer: pb)
        let score = try await analyzer.analyzeSharpness(of: img)
        XCTAssertGreaterThan(score.value, 0.5)
    }

    func testScoreWithin0_05OfCPU() async throws {
        try XCTSkipUnless(MetalContext.shared != nil, "No Metal GPU available")
        let context = MetalContext.shared!
        let pb = TestImageFactory.checkerboardPixelBuffer(width: 64, height: 64, squareSize: 4)
        let img = ProcessedImage(assetId: "x", width: 64, height: 64, pixelBuffer: pb)
        let metalScore = try await (try MetalSharpnessAnalyzer(context: context)).analyzeSharpness(of: img)
        let cpuScore   = try await CPUSharpnessAnalyzer().analyzeSharpness(of: img)
        XCTAssertEqual(metalScore.value, cpuScore.value, accuracy: 0.05,
                       "Metal and CPU sharpness scores should agree within 0.05")
    }

    func testMissingPixelBufferThrows() async throws {
        try XCTSkipUnless(MetalContext.shared != nil, "No Metal GPU available")
        let context = MetalContext.shared!
        let img = ProcessedImage(assetId: "x", width: 64, height: 64)
        do {
            _ = try await (try MetalSharpnessAnalyzer(context: context)).analyzeSharpness(of: img)
            XCTFail("Expected throw")
        } catch ProcessedImageError.missingPixelBuffer { /* expected */ }
    }
}
#endif
