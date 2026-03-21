import XCTest
@testable import PhotoCullCore

final class ResolutionScorerTests: XCTestCase {
    let scorer = ResolutionScorer()

    private func asset(id: String = "a", width: Int, height: Int) -> PhotoAsset {
        PhotoAsset(id: id, pixelWidth: width, pixelHeight: height)
    }

    // MARK: - Equal resolutions → all 1.0

    func testEqualResolutionsAllScoreOne() {
        let a = asset(id: "a", width: 100, height: 100)
        let b = asset(id: "b", width: 100, height: 100)
        let groupMaxPixels = 100 * 100
        XCTAssertEqual(scorer.score(asset: a, groupMaxPixels: groupMaxPixels).value, 1.0)
        XCTAssertEqual(scorer.score(asset: b, groupMaxPixels: groupMaxPixels).value, 1.0)
        XCTAssertEqual(scorer.score(asset: a, groupMaxPixels: groupMaxPixels).signal, .resolution)
    }

    // MARK: - Largest scores 1.0, others proportional

    func testLargestAssetScoresOne() {
        let large = asset(id: "large", width: 200, height: 200)
        let small = asset(id: "small", width: 100, height: 100)
        let groupMaxPixels = 200 * 200  // 40000
        XCTAssertEqual(scorer.score(asset: large, groupMaxPixels: groupMaxPixels).value, 1.0)
        let smallScore = scorer.score(asset: small, groupMaxPixels: groupMaxPixels).value
        XCTAssertEqual(smallScore, Double(100 * 100) / Double(200 * 200), accuracy: 1e-9)
    }

    func testProportionalScoring() {
        // 4x the pixels → 4x the score
        let huge = asset(id: "huge", width: 400, height: 400)   // 160000 px
        let tiny = asset(id: "tiny", width: 200, height: 200)   // 40000 px
        let groupMaxPixels = 400 * 400
        let hugeScore = scorer.score(asset: huge, groupMaxPixels: groupMaxPixels).value
        let tinyScore = scorer.score(asset: tiny, groupMaxPixels: groupMaxPixels).value
        XCTAssertEqual(hugeScore, 1.0)
        XCTAssertEqual(tinyScore, 0.25, accuracy: 1e-9)
    }

    // MARK: - Zero dimensions → 0.0

    func testZeroWidthReturnsZero() {
        let a = asset(id: "a", width: 0, height: 100)
        XCTAssertEqual(scorer.score(asset: a, groupMaxPixels: 10000).value, 0.0)
    }

    func testZeroHeightReturnsZero() {
        let a = asset(id: "a", width: 100, height: 0)
        XCTAssertEqual(scorer.score(asset: a, groupMaxPixels: 10000).value, 0.0)
    }

    // MARK: - groupMaxPixels = 0 → 0.0 (no crash)

    func testGroupMaxPixelsZeroReturnsZeroNoCrash() {
        let a = asset(id: "a", width: 1000, height: 1000)
        let result = scorer.score(asset: a, groupMaxPixels: 0)
        XCTAssertEqual(result.value, 0.0)
    }
}
