import XCTest
@testable import PhotoCullCore

final class SimilarityScorerTests: XCTestCase {
    let scorer = SimilarityScorer()

    // MARK: - score(a:b:)

    func testIdenticalVectorsHaveDistanceNearZero() {
        let v: [Float] = [1, 2, 3, 4]
        let distance = scorer.score(a: v, b: v)
        XCTAssertEqual(distance, 0.0, accuracy: 1e-6)
    }

    func testOrthogonalVectorsHaveDistanceNearOne() {
        let a: [Float] = [1, 0]
        let b: [Float] = [0, 1]
        let distance = scorer.score(a: a, b: b)
        XCTAssertEqual(distance, 1.0, accuracy: 1e-6)
    }

    func testZeroNormVectorReturnsOneDotZero() {
        let zero: [Float] = [0, 0, 0]
        let other: [Float] = [1, 2, 3]
        XCTAssertEqual(scorer.score(a: zero, b: other), 1.0)
        XCTAssertEqual(scorer.score(a: other, b: zero), 1.0)
        XCTAssertEqual(scorer.score(a: zero, b: zero), 1.0)
    }

    func testEmptyVectorsReturnOneDotZero() {
        XCTAssertEqual(scorer.score(a: [], b: []), 1.0)
    }

    func testMismatchedLengthReturnsOneDotZero() {
        XCTAssertEqual(scorer.score(a: [1, 2], b: [1, 2, 3]), 1.0)
    }

    // MARK: - isConfirmed(distance:threshold:)

    func testDistanceBelowThresholdIsConfirmed() {
        XCTAssertTrue(scorer.isConfirmed(distance: 0.10, threshold: 0.15))
    }

    func testDistanceAtThresholdIsNotConfirmed() {
        XCTAssertFalse(scorer.isConfirmed(distance: 0.15, threshold: 0.15))
    }

    func testDistanceAboveThresholdIsNotConfirmed() {
        XCTAssertFalse(scorer.isConfirmed(distance: 0.20, threshold: 0.15))
    }

    // MARK: - confirmPairs

    func testConfirmPairsFiltersBelowThreshold() {
        let features: [String: AssetFeatures] = [
            "a": AssetFeatures(
                assetId: "a",
                featureVector: FeatureVector(values: [1, 0]),
                sharpnessScore: SharpnessScore(value: 0.8)
            ),
            "b": AssetFeatures(
                assetId: "b",
                featureVector: FeatureVector(values: [1, 0]),  // identical → distance 0
                sharpnessScore: SharpnessScore(value: 0.7)
            ),
        ]
        let pair = CandidatePair(assetIdA: "a", assetIdB: "b", prefilterReason: .timeProximity)
        let confirmed = scorer.confirmPairs([pair], features: features, threshold: 0.15)
        XCTAssertEqual(confirmed.count, 1)
        XCTAssertNotNil(confirmed.first?.similarityScore)
    }

    func testConfirmPairsDropsAboveThreshold() {
        let features: [String: AssetFeatures] = [
            "a": AssetFeatures(
                assetId: "a",
                featureVector: FeatureVector(values: [1, 0]),
                sharpnessScore: SharpnessScore(value: 0.5)
            ),
            "b": AssetFeatures(
                assetId: "b",
                featureVector: FeatureVector(values: [0, 1]),  // orthogonal → distance 1
                sharpnessScore: SharpnessScore(value: 0.5)
            ),
        ]
        let pair = CandidatePair(assetIdA: "a", assetIdB: "b", prefilterReason: .timeProximity)
        let confirmed = scorer.confirmPairs([pair], features: features, threshold: 0.15)
        XCTAssertTrue(confirmed.isEmpty)
    }

    func testConfirmPairsDropsMissingFeatures() {
        let features: [String: AssetFeatures] = [:]
        let pair = CandidatePair(assetIdA: "a", assetIdB: "b", prefilterReason: .timeProximity)
        let confirmed = scorer.confirmPairs([pair], features: features, threshold: 0.15)
        XCTAssertTrue(confirmed.isEmpty)
    }
}
