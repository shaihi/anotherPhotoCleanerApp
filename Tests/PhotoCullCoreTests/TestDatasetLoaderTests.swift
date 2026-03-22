#if canImport(CoreGraphics)
import XCTest
@testable import PhotoCullCore

final class TestDatasetLoaderTests: XCTestCase {

    // MARK: - 1. Manifest loads successfully

    func testManifestLoadsSuccessfully() throws {
        let manifest = try TestDatasetLoader.loadManifest()
        XCTAssertEqual(manifest.version, 1)
        XCTAssertEqual(manifest.categories.count, 12)
    }

    // MARK: - 2. All categories have unique IDs

    func testAllCategoriesHaveUniqueIds() throws {
        let manifest = try TestDatasetLoader.loadManifest()
        let ids = manifest.categories.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Category IDs must be unique; found duplicates in: \(ids)")
    }

    // MARK: - 3. All categories have parseable expected files

    func testAllCategoriesHaveExpectedFiles() throws {
        let manifest = try TestDatasetLoader.loadManifest()
        for category in manifest.categories {
            XCTAssertNoThrow(
                try TestDatasetLoader.loadExpected(for: category),
                "loadExpected failed for category '\(category.id)'"
            )
        }
    }

    // MARK: - 4. Asset counts match spec

    func testAssetCountsMatchSpec() throws {
        let expected: [String: Int] = [
            "exact-duplicates": 3,
            "near-duplicates": 3,
            "burst": 4,
            "favorites": 2,
            "edited": 2,
            "low-confidence-suppression": 2,
            "missing-signal-suppression": 2,
            "unrelated-controls": 3,
            "transitive-chain": 3,
            "blur-vs-sharp": 2,
            "blur-favorite-preserved": 2,
            "blur-both-blurry": 2
        ]
        let manifest = try TestDatasetLoader.loadManifest()
        for category in manifest.categories {
            let expectedCount = expected[category.id]
            XCTAssertNotNil(expectedCount, "No expected count for category '\(category.id)'")
            if let count = expectedCount {
                XCTAssertEqual(category.assets.count, count,
                    "Category '\(category.id)' expected \(count) assets, got \(category.assets.count)")
            }
        }
    }

    // MARK: - 5. Synthesize produces correct asset count

    func testSynthesizeProducesCorrectAssetCount() throws {
        let category = try TestDatasetLoader.loadCategory("exact-duplicates")
        let (assets, _) = TestDatasetLoader.synthesize(category: category)
        XCTAssertEqual(assets.count, 3)
    }

    // MARK: - 6. Synthesize image data map has entry per asset

    func testSynthesizeImageDataMapHasEntryPerAsset() throws {
        let category = try TestDatasetLoader.loadCategory("exact-duplicates")
        let (_, imageDataMap) = TestDatasetLoader.synthesize(category: category)
        XCTAssertEqual(imageDataMap.count, 3)
        for (id, data) in imageDataMap {
            XCTAssertFalse(data.isEmpty, "Image data for asset '\(id)' must not be empty")
        }
    }

    // MARK: - 7. Exact duplicates share crypto hash

    func testExactDuplicatesShareCryptoHash() throws {
        let category = try TestDatasetLoader.loadCategory("exact-duplicates")
        let results = TestDatasetLoader.hashResults(for: category)
        // Results sorted by asset.id ascending: ed-different < ed-newest < ed-oldest (lexicographic)
        // ed-oldest and ed-newest share hashSeed "ed-shared" → same cryptoHash
        // ed-different has nil hashSeed → unique hash derived from id "ed-different"
        let resultById = Dictionary(uniqueKeysWithValues: results.map { ($0.asset.id, $0) })
        let oldest = try XCTUnwrap(resultById["ed-oldest"], "ed-oldest not found in hashResults")
        let newest = try XCTUnwrap(resultById["ed-newest"], "ed-newest not found in hashResults")
        let different = try XCTUnwrap(resultById["ed-different"], "ed-different not found in hashResults")
        XCTAssertEqual(oldest.cryptoHash, newest.cryptoHash,
            "ed-oldest and ed-newest share hashSeed 'ed-shared' and must produce identical cryptoHash")
        XCTAssertNotEqual(different.cryptoHash, oldest.cryptoHash,
            "ed-different has nil hashSeed and must produce a unique cryptoHash")
    }

    // MARK: - 8. Unique hash seeds produce different hashes

    func testUniqueHashSeedsProduceDifferentHashes() throws {
        let category = try TestDatasetLoader.loadCategory("near-duplicates")
        let results = TestDatasetLoader.hashResults(for: category)
        // Results sorted by asset.id ascending: nd-best < nd-mid < nd-worst (lexicographic)
        // All assets have nil hashSeed → each gets a hash derived from its own id
        XCTAssertEqual(results.count, 3)
        XCTAssertNotEqual(results[0].cryptoHash, results[1].cryptoHash,
            "nd-best and nd-mid must have different cryptoHash (nil hashSeeds, different ids)")
        XCTAssertNotEqual(results[1].cryptoHash, results[2].cryptoHash,
            "nd-mid and nd-worst must have different cryptoHash (nil hashSeeds, different ids)")
    }

    // MARK: - 9. Favorite asset has isFavorite == true

    func testFavoriteAssetHasIsFavoriteTrue() throws {
        let category = try TestDatasetLoader.loadCategory("favorites")
        let (assets, _) = TestDatasetLoader.synthesize(category: category)
        let favorite = assets.first(where: { $0.id == "fav-favorite" })
        let found = try XCTUnwrap(favorite, "fav-favorite not found in synthesized assets")
        XCTAssertTrue(found.isFavorite, "fav-favorite must have isFavorite == true")
    }

    // MARK: - 10. Edited asset has isEdited == true

    func testEditedAssetHasIsEditedTrue() throws {
        let category = try TestDatasetLoader.loadCategory("edited")
        let (assets, _) = TestDatasetLoader.synthesize(category: category)
        let edited = assets.first(where: { $0.id == "edit-edited" })
        let found = try XCTUnwrap(edited, "edit-edited not found in synthesized assets")
        XCTAssertTrue(found.isEdited, "edit-edited must have isEdited == true")
    }

    // MARK: - 11. Burst assets share burst identifier

    func testBurstAssetsShareBurstIdentifier() throws {
        let category = try TestDatasetLoader.loadCategory("burst")
        let (assets, _) = TestDatasetLoader.synthesize(category: category)
        XCTAssertEqual(assets.count, 4)
        let burstIds = Set(assets.compactMap(\.burstIdentifier))
        XCTAssertEqual(burstIds.count, 1, "All burst assets must share exactly one burstIdentifier; found: \(burstIds)")
    }

    // MARK: - 12. Transitive chain pairs are correct

    func testTransitiveChainPairsAreCorrect() throws {
        let category = try TestDatasetLoader.loadCategory("transitive-chain")
        let pairs = try XCTUnwrap(category.nearDuplicatePairs, "transitive-chain must have nearDuplicatePairs")
        XCTAssertEqual(pairs.count, 2, "Expected exactly 2 near-duplicate pairs in transitive-chain")
        XCTAssertTrue(pairs.contains(["tc-a", "tc-b"]), "Pairs must include [tc-a, tc-b]")
        XCTAssertTrue(pairs.contains(["tc-b", "tc-c"]), "Pairs must include [tc-b, tc-c]")
        let hasDirectACPair = pairs.contains { pair in
            Set(pair) == Set(["tc-a", "tc-c"])
        }
        XCTAssertFalse(hasDirectACPair, "Pairs must NOT include a direct [tc-a, tc-c] pair (tests transitivity)")
    }

    // MARK: - 13. Missing signal asset has nil signals

    func testMissingSignalAssetHasNilSignals() throws {
        let category = try TestDatasetLoader.loadCategory("missing-signal-suppression")
        let missingAsset = category.assets.first(where: { $0.id == "mss-missing" })
        let da = try XCTUnwrap(missingAsset, "mss-missing DatasetAsset not found in category")
        XCTAssertNil(da.signals, "mss-missing must have nil signals in the manifest")

        let (_, _, signals) = TestDatasetLoader.synthesizeWithSignals(category: category)
        let missingSig = try XCTUnwrap(signals["mss-missing"], "mss-missing must have an entry in signalMap")
        XCTAssertTrue(missingSig.isEmpty, "mss-missing must produce an empty SignalValue array (nil signals → [])")
    }

    // MARK: - 14. Mock service creation

    func testMockServiceCreation() throws {
        let service = try TestDatasetLoader.mockService(for: "burst")
        let assets = service.assets
        XCTAssertEqual(assets.count, 4, "MockPhotoLibraryService for 'burst' must contain 4 assets")
    }

    // MARK: - 15. synthesizeWithSignals returns correct signal keys

    func testSynthesizeWithSignalsReturnsCorrectSignalKeys() throws {
        let category = try TestDatasetLoader.loadCategory("near-duplicates")
        let (_, _, signals) = TestDatasetLoader.synthesizeWithSignals(category: category)
        let ndBestSignals = try XCTUnwrap(signals["nd-best"], "nd-best must have signal values")
        // nd-best has all 4 signals: sharpness, exposure, subjectQuality, resolution
        XCTAssertEqual(ndBestSignals.count, 4,
            "nd-best must have exactly 4 SignalValues (sharpness, exposure, subjectQuality, resolution)")
    }
}
#endif
