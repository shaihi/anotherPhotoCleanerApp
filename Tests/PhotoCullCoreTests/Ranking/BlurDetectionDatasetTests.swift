#if canImport(CoreGraphics)
import XCTest
@testable import PhotoCullCore

/// Dataset regression tests for Phase 5 blur detection.
///
/// All sharpness values are injected synthetic values from manifest.json via
/// TestDatasetLoader.synthesizeWithSignals() — no Metal/Vision/Accelerate
/// computation runs in any of these tests. Values are in the [0,1] range
/// consistent with SharpnessNormalization.normalize(variance:) output.
final class BlurDetectionDatasetTests: XCTestCase {

    private let ranker = BestShotRanker()
    private let safetyGuard = SafetyGuard()

    /// Builds AssetFeatures from injected signal values for a dataset category.
    private func makeFeatures(for category: DatasetCategory) -> [String: AssetFeatures] {
        Dictionary(uniqueKeysWithValues: category.assets.map { da in
            let sharpness = da.signals?.sharpness ?? 0.5
            let exposure  = da.signals?.exposure
            let subject   = da.signals?.subjectQuality
            let feat = AssetFeatures(
                assetId: da.id,
                featureVector: FeatureVector(values: [1.0, 0.0]),
                sharpnessScore: SharpnessScore(value: sharpness),
                exposureScore: exposure,
                subjectScore: subject
            )
            return (da.id, feat)
        })
    }

    /// Builds candidate pairs from the category's nearDuplicatePairs field.
    private func makePairs(for category: DatasetCategory) -> [CandidatePair] {
        (category.nearDuplicatePairs ?? []).map { pair in
            CandidatePair(
                assetIdA: pair[0],
                assetIdB: pair[1],
                prefilterReason: .timeProximity,
                similarityScore: 0.05
            )
        }
    }

    /// Builds a CullGroup from the category's assets and reason.
    private func makeGroup(for category: DatasetCategory) throws -> CullGroup {
        let (assets, _) = TestDatasetLoader.synthesize(category: category)
        let reason: GroupingReason = switch category.groupingReason {
        case "nearDuplicate": .nearDuplicate
        case "burst": .burst
        default: .exactDuplicate
        }
        return try CullGroup(reason: reason, members: assets)
    }

    // Test 12: blur-vs-sharp with enableBlurDetection=true
    // bvs-blurry (sharpness 0.04) should be culled via Rule C; bvs-sharp (0.88) is keeper.
    func testBlurVsSharp_enabledCullsBlurry() throws {
        let category = try TestDatasetLoader.loadCategory("blur-vs-sharp")
        let group    = try makeGroup(for: category)
        let features = makeFeatures(for: category)
        let pairs    = makePairs(for: category)
        let assetMap = Dictionary(uniqueKeysWithValues: group.members.map { ($0.id, $0) })

        var config = CullConfiguration.default
        config.enableNearDuplicates = true
        config.enableBlurDetection  = true

        var recs = ranker.rank(group: group, features: features, pairs: pairs,
                               assets: assetMap, configuration: config)
        recs = try safetyGuard.validate(recommendations: recs, for: group)

        let sharpRec  = recs.first { $0.asset.id == "bvs-sharp" }
        let blurryRec = recs.first { $0.asset.id == "bvs-blurry" }

        XCTAssertEqual(sharpRec?.action, .keep, "bvs-sharp must be kept")
        XCTAssertEqual(blurryRec?.action, .cull, "bvs-blurry must be culled via Rule C")
        XCTAssertTrue(
            blurryRec?.reasons.first?.lowercased().contains("blur") == true,
            "bvs-blurry cull reason must mention blur; got: \(blurryRec?.reasons ?? [])"
        )
    }

    // Test 13: blur-vs-sharp with enableBlurDetection=false
    // Composite scoring still culls bvs-blurry (sharpness delta is large enough to exceed
    // Rule A's suppression threshold with separationScale=0.3 and sharpnessWeight=0.40).
    // What must NOT appear is the blur reason string — only Rule C produces that.
    func testBlurVsSharp_disabledNoBluReasonInCull() throws {
        let category = try TestDatasetLoader.loadCategory("blur-vs-sharp")
        let group    = try makeGroup(for: category)
        let features = makeFeatures(for: category)
        let pairs    = makePairs(for: category)
        let assetMap = Dictionary(uniqueKeysWithValues: group.members.map { ($0.id, $0) })

        var config = CullConfiguration.default
        config.enableNearDuplicates = true
        config.enableBlurDetection  = false

        var recs = ranker.rank(group: group, features: features, pairs: pairs,
                               assets: assetMap, configuration: config)
        recs = try safetyGuard.validate(recommendations: recs, for: group)

        let blurryRec = recs.first { $0.asset.id == "bvs-blurry" }
        XCTAssertEqual(blurryRec?.action, .cull,
            "bvs-blurry should be culled by composite scoring even without blur detection")
        let reasons = blurryRec?.reasons.joined() ?? ""
        XCTAssertFalse(reasons.lowercased().contains("blur"),
            "Blur reason must not appear when enableBlurDetection=false; got: \(reasons)")
    }

    // Test 14: blur-favorite-preserved with enableBlurDetection=true
    // bfp-blurry-fav is isFavorite (Tier 0) → always keeper.
    // bfp-sharp: keeper sharpness 0.04 < blurKeeperSharpnessMinimum 0.50 → Rule C .unclear
    // → Rule A suppresses (keeperScore < assetScore → low confidence) → kept.
    func testBlurFavoritePreserved() throws {
        let category = try TestDatasetLoader.loadCategory("blur-favorite-preserved")
        let group    = try makeGroup(for: category)
        let features = makeFeatures(for: category)
        let pairs    = makePairs(for: category)
        let assetMap = Dictionary(uniqueKeysWithValues: group.members.map { ($0.id, $0) })

        var config = CullConfiguration.default
        config.enableNearDuplicates = true
        config.enableBlurDetection  = true

        var recs = ranker.rank(group: group, features: features, pairs: pairs,
                               assets: assetMap, configuration: config)
        recs = try safetyGuard.validate(recommendations: recs, for: group)

        let favRec = recs.first { $0.asset.id == "bfp-blurry-fav" }
        XCTAssertEqual(favRec?.action, .keep,
            "Blurry isFavorite (Tier 0) must always be kept regardless of blur detection")
        XCTAssertTrue(safetyGuard.isSafe(recs), "SafetyGuard must pass")
    }

    // Test 15: blur-both-blurry with enableBlurDetection=true
    // bbb-blurry-a keeper sharpness 0.05 < blurKeeperSharpnessMinimum 0.50 → Rule C .unclear
    // Rule A then applies: scores very close → both kept.
    func testBlurBothBlurry_bothKept() throws {
        let category = try TestDatasetLoader.loadCategory("blur-both-blurry")
        let group    = try makeGroup(for: category)
        let features = makeFeatures(for: category)
        let pairs    = makePairs(for: category)
        let assetMap = Dictionary(uniqueKeysWithValues: group.members.map { ($0.id, $0) })

        var config = CullConfiguration.default
        config.enableNearDuplicates = true
        config.enableBlurDetection  = true

        var recs = ranker.rank(group: group, features: features, pairs: pairs,
                               assets: assetMap, configuration: config)
        recs = try safetyGuard.validate(recommendations: recs, for: group)

        XCTAssertTrue(recs.allSatisfy { $0.action == .keep },
            "Both blurry photos must be kept when keeper fails blurKeeperSharpnessMinimum")
        XCTAssertTrue(safetyGuard.isSafe(recs), "SafetyGuard must pass")
    }
}
#endif
