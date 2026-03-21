#if canImport(CoreImage)
import XCTest
import CoreImage
@testable import PhotoCullCore

final class ExposureScorerTests: XCTestCase {
    let scorer = ExposureScorer()

    // MARK: - Helpers

    private func processedImage(pixelBuffer: PixelBuffer) -> ProcessedImage {
        ProcessedImage(
            assetId: "test",
            width: pixelBuffer.width,
            height: pixelBuffer.height,
            pixelBuffer: pixelBuffer
        )
    }

    private func asset() -> PhotoAsset { PhotoAsset(id: "test") }

    // MARK: - Mid-grey image → high score (close to ideal exposure)

    func testMidGreyImageScoresHighExposure() throws {
        // Mid-grey: luminance ≈ 0.5 → score ≈ 1.0
        let pb = TestImageFactory.solidColorPixelBuffer(width: 64, height: 64, r: 128, g: 128, b: 128)
        let image = processedImage(pixelBuffer: pb)
        let signal = try scorer.score(asset: asset(), image: image)
        XCTAssertEqual(signal.signal, .exposure)
        // Score should be high (close to 1.0)
        XCTAssertGreaterThan(signal.value, 0.6, "Mid-grey image should have high exposure score")
    }

    // MARK: - All-black image → lower score (under-exposed)

    func testBlackImageScoresLowerExposure() throws {
        let pb = TestImageFactory.solidColorPixelBuffer(width: 64, height: 64, r: 0, g: 0, b: 0)
        let image = processedImage(pixelBuffer: pb)
        let signal = try scorer.score(asset: asset(), image: image)
        XCTAssertEqual(signal.signal, .exposure)
        // Very dark image: score should be lower than neutral
        XCTAssertLessThan(signal.value, 0.6, "Completely black image should score below mid-tone")
    }

    // MARK: - All-white image → lower score (over-exposed)

    func testWhiteImageScoresLowerExposure() throws {
        let pb = TestImageFactory.solidColorPixelBuffer(width: 64, height: 64, r: 255, g: 255, b: 255)
        let image = processedImage(pixelBuffer: pb)
        let signal = try scorer.score(asset: asset(), image: image)
        XCTAssertEqual(signal.signal, .exposure)
        // Very bright image: score should be lower than mid-tone
        XCTAssertLessThan(signal.value, 0.6, "Completely white image should score below mid-tone")
    }

    // MARK: - Missing pixel buffer → neutral 0.5 fallback

    func testMissingPixelBufferReturnsFallback() throws {
        let image = ProcessedImage(assetId: "test", width: 64, height: 64, pixelBuffer: nil)
        let signal = try scorer.score(asset: asset(), image: image)
        XCTAssertEqual(signal.signal, .exposure)
        XCTAssertEqual(signal.value, 0.5, "Missing pixel buffer should return neutral 0.5")
    }

    // MARK: - Score is in [0, 1]

    func testScoreIsAlwaysInRange() throws {
        let pb = TestImageFactory.checkerboardPixelBuffer(width: 64, height: 64)
        let image = processedImage(pixelBuffer: pb)
        let signal = try scorer.score(asset: asset(), image: image)
        XCTAssertGreaterThanOrEqual(signal.value, 0.0)
        XCTAssertLessThanOrEqual(signal.value, 1.0)
    }
}
#endif
