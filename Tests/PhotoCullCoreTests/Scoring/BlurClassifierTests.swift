import XCTest
@testable import PhotoCullCore

/// BlurClassifier unit tests.
///
/// All sharpness values are injected synthetically — no Metal/Vision/Accelerate
/// computation runs in any of these tests. Values are chosen to deterministically
/// satisfy or violate the two-condition threshold rule using the default configuration
/// parameters: accidentalBlurThreshold=0.10, blurRelativeFactor=0.50,
/// blurKeeperSharpnessMinimum=0.50.
final class BlurClassifierTests: XCTestCase {

    private let classifier = BlurClassifier()
    private let config = CullConfiguration.default

    private func asset(id: String = "a", isFavorite: Bool = false, isEdited: Bool = false) -> PhotoAsset {
        PhotoAsset(id: id, isFavorite: isFavorite, isEdited: isEdited)
    }

    // Test 1: Both conditions met → .accidental
    func test_accidental_whenBothConditionsMet() {
        // candidate=0.04: absolute (0.04 < 0.10 ✓), relative (0.04 < 0.88*0.50=0.44 ✓),
        // keeper=0.88 ≥ 0.50 ✓, Tier 2
        let result = classifier.classify(
            candidateSharpness: 0.04,
            keeperSharpness: 0.88,
            asset: asset(),
            configuration: config
        )
        XCTAssertEqual(result, .accidental)
    }

    // Test 2: Keeper not sharp enough → .unclear
    func test_unclear_whenKeeperNotSharpEnough() {
        // keeper=0.30 < blurKeeperSharpnessMinimum=0.50 → relative condition blocked
        let result = classifier.classify(
            candidateSharpness: 0.04,
            keeperSharpness: 0.30,
            asset: asset(),
            configuration: config
        )
        XCTAssertEqual(result, .unclear)
    }

    // Test 3: Only relative condition met (absolute not breached) → .unclear
    func test_unclear_whenOnlyRelativeConditionMet() {
        // candidate=0.30: absolute (0.30 > 0.10 ✗) — fails absolute condition
        let result = classifier.classify(
            candidateSharpness: 0.30,
            keeperSharpness: 0.88,
            asset: asset(),
            configuration: config
        )
        XCTAssertEqual(result, .unclear)
    }

    // Test 4: Candidate sharp enough → .unclear
    func test_unclear_whenSharpEnough() {
        // candidate=0.50: above threshold in absolute sense
        let result = classifier.classify(
            candidateSharpness: 0.50,
            keeperSharpness: 0.88,
            asset: asset(),
            configuration: config
        )
        XCTAssertEqual(result, .unclear)
    }

    // Test 5: Both conditions met but isFavorite → .preserved
    func test_preserved_whenFavorite() {
        let result = classifier.classify(
            candidateSharpness: 0.04,
            keeperSharpness: 0.88,
            asset: asset(isFavorite: true),
            configuration: config
        )
        XCTAssertEqual(result, .preserved)
    }

    // Test 6: Both conditions met but isEdited → .preserved
    func test_preserved_whenEdited() {
        let result = classifier.classify(
            candidateSharpness: 0.04,
            keeperSharpness: 0.88,
            asset: asset(isEdited: true),
            configuration: config
        )
        XCTAssertEqual(result, .preserved)
    }
}
