import XCTest
@testable import PhotoCullCore

final class CompositeScorerTests: XCTestCase {
    let scorer = CompositeScorer()

    // MARK: - Default weights weighted sum

    func testCorrectWeightedSumWithDefaultWeights() {
        let signals: [QualitySignal: Double] = [
            .sharpness: 0.8,
            .exposure: 0.6,
            .subjectQuality: 0.4,
            .resolution: 1.0
        ]
        let weights: [QualitySignal: Double] = [
            .sharpness: 0.40,
            .exposure: 0.25,
            .subjectQuality: 0.25,
            .resolution: 0.10
        ]
        let result = scorer.score(signals: signals, weights: weights)
        // Expected: (0.8*0.40 + 0.6*0.25 + 0.4*0.25 + 1.0*0.10) / 1.0
        // = (0.32 + 0.15 + 0.10 + 0.10) / 1.0 = 0.67
        XCTAssertEqual(result, 0.67, accuracy: 1e-9)
    }

    // MARK: - Custom weights

    func testCustomWeightsNormalized() {
        let signals: [QualitySignal: Double] = [
            .sharpness: 1.0,
            .resolution: 0.0
        ]
        let weights: [QualitySignal: Double] = [
            .sharpness: 2.0,
            .resolution: 2.0
        ]
        // Expected: (1.0*2.0 + 0.0*2.0) / 4.0 = 0.5
        let result = scorer.score(signals: signals, weights: weights)
        XCTAssertEqual(result, 0.5, accuracy: 1e-9)
    }

    // MARK: - All signals at 0 → 0.0

    func testAllSignalsAtZeroReturnsZero() {
        let signals: [QualitySignal: Double] = [
            .sharpness: 0.0,
            .exposure: 0.0,
            .subjectQuality: 0.0,
            .resolution: 0.0
        ]
        let weights: [QualitySignal: Double] = [
            .sharpness: 1.0,
            .exposure: 1.0,
            .subjectQuality: 1.0,
            .resolution: 1.0
        ]
        XCTAssertEqual(scorer.score(signals: signals, weights: weights), 0.0, accuracy: 1e-9)
    }

    // MARK: - Missing signal → neutral 0.5 substituted

    func testMissingSignalUsesNeutralFallback() {
        // Only sharpness is in signals, exposure is missing — should substitute 0.5
        let signals: [QualitySignal: Double] = [
            .sharpness: 1.0
        ]
        let weights: [QualitySignal: Double] = [
            .sharpness: 1.0,
            .exposure: 1.0
        ]
        // Expected: (1.0*1.0 + 0.5*1.0) / 2.0 = 0.75
        let result = scorer.score(signals: signals, weights: weights)
        XCTAssertEqual(result, 0.75, accuracy: 1e-9)
    }

    // MARK: - Empty weights → 0.0

    func testEmptyWeightsReturnsZero() {
        let signals: [QualitySignal: Double] = [.sharpness: 1.0]
        XCTAssertEqual(scorer.score(signals: signals, weights: [:]), 0.0)
    }

    // MARK: - Breakdown

    func testBreakdownContainsWeightedSignals() {
        let signals: [QualitySignal: Double] = [
            .sharpness: 0.9,
            .exposure: 0.7
        ]
        let weights: [QualitySignal: Double] = [
            .sharpness: 1.0,
            .exposure: 1.0
        ]
        let breakdown = scorer.breakdown(signals: signals, weights: weights)
        XCTAssertEqual(breakdown["sharpness"], 0.9)
        XCTAssertEqual(breakdown["exposure"], 0.7)
    }

    func testBreakdownUsesNeutralForMissingSignal() {
        let signals: [QualitySignal: Double] = [:]
        let weights: [QualitySignal: Double] = [.resolution: 1.0]
        let breakdown = scorer.breakdown(signals: signals, weights: weights)
        XCTAssertEqual(breakdown["resolution"], 0.5)
    }
}
