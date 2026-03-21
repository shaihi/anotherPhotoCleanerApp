import XCTest
@testable import PhotoCullCore

final class SubjectScorerTests: XCTestCase {
    let scorer = SubjectScorer()

    private func asset() -> PhotoAsset { PhotoAsset(id: "test") }

    // MARK: - Fallback when pixel buffer is missing

    func testMissingPixelBufferReturnsNeutral() throws {
        let image = ProcessedImage(assetId: "test", width: 64, height: 64, pixelBuffer: nil)
        let signal = try scorer.score(asset: asset(), image: image)
        XCTAssertEqual(signal.signal, .subjectQuality)
        XCTAssertEqual(signal.value, 0.5, "Missing pixel buffer should return neutral 0.5 fallback")
    }

    // MARK: - Score is always in [0, 1]

    func testScoreIsInRange() throws {
        // Use a synthetic pixel buffer — Vision may or may not find salient objects,
        // but the score must always be clamped to [0, 1].
        let pb = TestImageFactory.solidColorPixelBuffer(width: 64, height: 64, r: 128, g: 128, b: 128)
        let image = ProcessedImage(assetId: "test", width: 64, height: 64, pixelBuffer: pb)
        let signal = try scorer.score(asset: asset(), image: image)
        XCTAssertEqual(signal.signal, .subjectQuality)
        XCTAssertGreaterThanOrEqual(signal.value, 0.0)
        XCTAssertLessThanOrEqual(signal.value, 1.0)
    }

    // MARK: - Does not throw on valid input

    func testDoesNotThrowOnValidInput() {
        let pb = TestImageFactory.checkerboardPixelBuffer(width: 64, height: 64)
        let image = ProcessedImage(assetId: "test", width: 64, height: 64, pixelBuffer: pb)
        XCTAssertNoThrow(try scorer.score(asset: asset(), image: image))
    }

    // MARK: - Signal identity

    func testSignalIsSubjectQuality() throws {
        let pb = TestImageFactory.solidColorPixelBuffer(width: 64, height: 64, r: 200, g: 100, b: 50)
        let image = ProcessedImage(assetId: "test", width: 64, height: 64, pixelBuffer: pb)
        let signal = try scorer.score(asset: asset(), image: image)
        XCTAssertEqual(signal.signal, .subjectQuality)
    }
}
