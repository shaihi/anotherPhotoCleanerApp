#if canImport(CoreGraphics)
import XCTest
@testable import PhotoCullCore

final class CPUSharpnessAnalyzerTests: XCTestCase {
    let analyzer = CPUSharpnessAnalyzer()

    func testSolidColorIsNearZero() async throws {
        let pb = TestImageFactory.solidColorPixelBuffer(width: 64, height: 64)
        let img = ProcessedImage(assetId: "s", width: 64, height: 64, pixelBuffer: pb)
        let score = try await analyzer.analyzeSharpness(of: img)
        XCTAssertLessThan(score.value, 0.1, "Solid color should score near zero")
    }

    func testCheckerboardIsHigh() async throws {
        let pb = TestImageFactory.checkerboardPixelBuffer(width: 64, height: 64, squareSize: 2)
        let img = ProcessedImage(assetId: "c", width: 64, height: 64, pixelBuffer: pb)
        let score = try await analyzer.analyzeSharpness(of: img)
        XCTAssertGreaterThan(score.value, 0.7, "Checkerboard should score high")
    }

    func testScoreIsInRange() async throws {
        let pb = TestImageFactory.gradientPixelBuffer(width: 64, height: 64)
        let img = ProcessedImage(assetId: "g", width: 64, height: 64, pixelBuffer: pb)
        let score = try await analyzer.analyzeSharpness(of: img)
        XCTAssertGreaterThanOrEqual(score.value, 0)
        XCTAssertLessThanOrEqual(score.value, 1)
    }

    func testMissingPixelBufferThrows() async throws {
        let img = ProcessedImage(assetId: "x", width: 64, height: 64)
        do {
            _ = try await analyzer.analyzeSharpness(of: img)
            XCTFail("Expected throw")
        } catch ProcessedImageError.missingPixelBuffer(let id) {
            XCTAssertEqual(id, "x")
        }
    }
}
#endif
