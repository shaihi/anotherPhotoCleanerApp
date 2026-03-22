import XCTest
@testable import PhotoCullCore

final class ReviewDecisionStoreTests: XCTestCase {

    // MARK: - InMemoryReviewDecisionStore

    func test_record_and_retrieve_decision() async {
        let store = InMemoryReviewDecisionStore()
        await store.record(assetId: "a1", decision: .deleted)
        let d = await store.decision(for: "a1")
        XCTAssertEqual(d, .deleted)
    }

    func test_unknown_assetId_returns_nil() async {
        let store = InMemoryReviewDecisionStore()
        let d = await store.decision(for: "unknown")
        XCTAssertNil(d)
    }

    func test_overwrite_decision() async {
        let store = InMemoryReviewDecisionStore()
        await store.record(assetId: "a1", decision: .deleted)
        await store.record(assetId: "a1", decision: .kept)
        let d = await store.decision(for: "a1")
        XCTAssertEqual(d, .kept)
    }

    func test_decisions_batch_lookup() async {
        let store = InMemoryReviewDecisionStore()
        await store.record(assetId: "a1", decision: .kept)
        await store.record(assetId: "a2", decision: .deleted)
        let map = await store.decisions(for: ["a1", "a2", "a3"])
        XCTAssertEqual(map["a1"], .kept)
        XCTAssertEqual(map["a2"], .deleted)
        XCTAssertNil(map["a3"])
    }

    func test_decisions_returns_only_known_ids() async {
        let store = InMemoryReviewDecisionStore()
        await store.record(assetId: "x", decision: .kept)
        let map = await store.decisions(for: ["x", "y"])
        XCTAssertEqual(map.count, 1)
    }

    // MARK: - ScanPipeline integration

    func test_pipeline_skips_deleted_assets() async throws {
        // "a2" was previously deleted — it should not appear in the next scan's result.
        // "a1" and "a3" share the same hash so they still form a duplicate group without "a2".
        let assets = [
            PhotoAsset(id: "a1"),
            PhotoAsset(id: "a2"),
            PhotoAsset(id: "a3"),
        ]
        let dataMap: [String: Data] = [
            "a1": Data("hash-A".utf8),
            "a2": Data("hash-A".utf8),
            "a3": Data("hash-A".utf8),  // all three are hash-A; removing a2 leaves a1+a3 pair
        ]
        let service = MockPhotoLibraryService(assets: assets, imageDataMap: dataMap)
        let store = InMemoryReviewDecisionStore()
        await store.record(assetId: "a2", decision: .deleted)

        let pipeline = ScanPipeline(libraryService: service, decisionStore: store)
        var result: ScanResult?
        for try await event in await pipeline.scan() {
            if case .completed(let r) = event { result = r }
        }
        let scannedIds = result?.recommendations.map(\.asset.id) ?? []
        XCTAssertFalse(scannedIds.contains("a2"), "Deleted asset should be excluded from scan")
        XCTAssertTrue(scannedIds.contains("a1"), "Remaining duplicate a1 should be scanned")
        XCTAssertTrue(scannedIds.contains("a3"), "Remaining duplicate a3 should be scanned")
    }

    func test_pipeline_includes_kept_assets() async throws {
        // .kept assets are still included so they can pair with new arrivals.
        let assets = [
            PhotoAsset(id: "a1"),
            PhotoAsset(id: "a2"),
        ]
        let dataMap: [String: Data] = [
            "a1": Data("hash-A".utf8),
            "a2": Data("hash-A".utf8),
        ]
        let service = MockPhotoLibraryService(assets: assets, imageDataMap: dataMap)
        let store = InMemoryReviewDecisionStore()
        await store.record(assetId: "a1", decision: .kept)

        let pipeline = ScanPipeline(libraryService: service, decisionStore: store)
        var result: ScanResult?
        for try await event in await pipeline.scan() {
            if case .completed(let r) = event { result = r }
        }
        let scannedIds = result?.recommendations.map(\.asset.id) ?? []
        XCTAssertTrue(scannedIds.contains("a1"), "Kept asset should still be scanned")
    }

    func test_pipeline_without_store_scans_all_assets() async throws {
        let assets = [PhotoAsset(id: "a1"), PhotoAsset(id: "a2")]
        let dataMap: [String: Data] = [
            "a1": Data("hash-A".utf8),
            "a2": Data("hash-A".utf8),
        ]
        let service = MockPhotoLibraryService(assets: assets, imageDataMap: dataMap)
        let pipeline = ScanPipeline(libraryService: service)
        var result: ScanResult?
        for try await event in await pipeline.scan() {
            if case .completed(let r) = event { result = r }
        }
        XCTAssertEqual(result?.recommendations.count, 2)
    }
}
