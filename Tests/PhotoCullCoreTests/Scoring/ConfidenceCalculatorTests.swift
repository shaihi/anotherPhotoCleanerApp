import XCTest
@testable import PhotoCullCore

final class ConfidenceCalculatorTests: XCTestCase {
    let calculator = ConfidenceCalculator()

    // MARK: - Large score delta → high confidence (capped at 0.95)

    func testLargeScoreDeltaYieldsHighConfidence() {
        let conf = calculator.confidence(
            keeperScore: 1.0,
            nextBestScore: 0.0,
            similarityConfidence: 0.9,
            separationScale: 0.3
        )
        XCTAssertGreaterThan(conf, 0.8, "Large delta should produce high confidence")
        XCTAssertLessThanOrEqual(conf, 0.95, "Confidence must not exceed 0.95")
    }

    // MARK: - Zero delta → floor (0.5)

    func testZeroDeltaYieldsFloorConfidence() {
        let conf = calculator.confidence(
            keeperScore: 0.7,
            nextBestScore: 0.7,
            similarityConfidence: 0.5,
            separationScale: 0.3
        )
        // signalSeparation = 0, result = 0.4 * 0.5 = 0.2 → clamped to 0.5
        XCTAssertEqual(conf, 0.5, accuracy: 1e-9)
    }

    // MARK: - Clamp at 0.95 for very large delta

    func testConfidenceClampedAt0_95() {
        let conf = calculator.confidence(
            keeperScore: 1.0,
            nextBestScore: 0.0,
            similarityConfidence: 1.0,
            separationScale: 0.3
        )
        XCTAssertLessThanOrEqual(conf, 0.95)
    }

    // MARK: - Threshold suppression

    func testIsSuppressedReturnsTrueWhenBelowThreshold() {
        XCTAssertTrue(calculator.isSuppressed(confidence: 0.59, threshold: 0.60))
    }

    func testIsSuppressedReturnsFalseWhenAtOrAboveThreshold() {
        XCTAssertFalse(calculator.isSuppressed(confidence: 0.60, threshold: 0.60))
        XCTAssertFalse(calculator.isSuppressed(confidence: 0.80, threshold: 0.60))
    }

    // MARK: - High similarity confidence boosts result

    func testHighSimilarityConfidenceBoostsResult() {
        let lowSim = calculator.confidence(
            keeperScore: 0.8, nextBestScore: 0.5,
            similarityConfidence: 0.5, separationScale: 0.3
        )
        let highSim = calculator.confidence(
            keeperScore: 0.8, nextBestScore: 0.5,
            similarityConfidence: 0.9, separationScale: 0.3
        )
        XCTAssertGreaterThan(highSim, lowSim)
    }
}
