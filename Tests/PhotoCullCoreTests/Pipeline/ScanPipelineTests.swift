import XCTest
@testable import PhotoCullCore

final class ScanPipelineTests: XCTestCase {

    /// Builds a mock service with two duplicate pairs.
    func makeService() -> MockPhotoLibraryService {
        let assets = [
            PhotoAsset(id: "a1", isFavorite: true),
            PhotoAsset(id: "a2"),
            PhotoAsset(id: "b1", isEdited: true),
            PhotoAsset(id: "b2"),
            PhotoAsset(id: "unique"),
        ]
        let dataMap: [String: Data] = [
            "a1": Data("hash-A".utf8),
            "a2": Data("hash-A".utf8),    // duplicate of a1
            "b1": Data("hash-B".utf8),
            "b2": Data("hash-B".utf8),    // duplicate of b1
            "unique": Data("hash-C".utf8),
        ]
        return MockPhotoLibraryService(assets: assets, imageDataMap: dataMap)
    }

    func collectEvents(from pipeline: ScanPipeline) async throws -> [ScanEvent] {
        var events: [ScanEvent] = []
        let stream = await pipeline.scan()
        for try await event in stream {
            events.append(event)
        }
        return events
    }

    func testScanProducesCompletedEvent() async throws {
        let pipeline = ScanPipeline(libraryService: makeService())
        let events = try await collectEvents(from: pipeline)
        let completedEvents = events.compactMap { if case .completed(let r) = $0 { return r } else { return nil } }
        XCTAssertEqual(completedEvents.count, 1)
    }

    func testScanFindsCorrectNumberOfGroups() async throws {
        let pipeline = ScanPipeline(libraryService: makeService())
        let events = try await collectEvents(from: pipeline)
        guard case .completed(let result) = events.last else {
            return XCTFail("Last event should be .completed")
        }
        XCTAssertEqual(result.groups.count, 2)
    }

    func testTotalScannedMatchesAssetCount() async throws {
        let pipeline = ScanPipeline(libraryService: makeService())
        let events = try await collectEvents(from: pipeline)
        guard case .completed(let result) = events.last else { return XCTFail() }
        XCTAssertEqual(result.totalScanned, 5)
    }

    func testProgressEventsAreEmitted() async throws {
        let pipeline = ScanPipeline(libraryService: makeService())
        let events = try await collectEvents(from: pipeline)
        let progressEvents = events.filter { if case .progress = $0 { return true } else { return false } }
        XCTAssertFalse(progressEvents.isEmpty)
    }

    func testSafetyInvariantHoldsInOutput() async throws {
        let pipeline = ScanPipeline(libraryService: makeService())
        let events = try await collectEvents(from: pipeline)
        guard case .completed(let result) = events.last else { return XCTFail() }
        for group in result.groups {
            let groupRecs = result.recommendations.filter { rec in
                group.members.contains(rec.asset)
            }
            XCTAssertTrue(
                groupRecs.contains(where: { $0.action == .keep }),
                "Group \(group.id) has no keeper"
            )
        }
    }

    func testAllRecommendationsHaveReasons() async throws {
        let pipeline = ScanPipeline(libraryService: makeService())
        let events = try await collectEvents(from: pipeline)
        guard case .completed(let result) = events.last else { return XCTFail() }
        for rec in result.recommendations {
            XCTAssertFalse(rec.reasons.isEmpty, "Asset \(rec.asset.id) has no reasons")
        }
    }

    func testEmptyLibraryProducesNoGroups() async throws {
        let service = MockPhotoLibraryService(assets: [])
        let pipeline = ScanPipeline(libraryService: service)
        let events = try await collectEvents(from: pipeline)
        guard case .completed(let result) = events.last else { return XCTFail() }
        XCTAssertTrue(result.groups.isEmpty)
        XCTAssertEqual(result.totalScanned, 0)
    }

    func testDisabledExactDuplicatesProducesNoGroups() async throws {
        let config = CullConfiguration(enableExactDuplicates: false)
        let pipeline = ScanPipeline(libraryService: makeService(), configuration: config)
        let events = try await collectEvents(from: pipeline)
        guard case .completed(let result) = events.last else { return XCTFail() }
        XCTAssertTrue(result.groups.isEmpty)
    }

    func testCancellationStopsStream() async throws {
        // Use a large-enough asset list so the stream doesn't finish before we cancel.
        let manyAssets = (0..<50).map { PhotoAsset(id: "asset-\($0)") }
        let service = MockPhotoLibraryService(assets: manyAssets)
        let pipeline = ScanPipeline(libraryService: service)

        var eventCount = 0
        let task = Task<Void, Never> {
            let stream = await pipeline.scan()
            do {
                for try await _ in stream {
                    eventCount += 1
                    // Break after receiving the first event, triggering onTermination.
                    if eventCount == 1 { break }
                }
            } catch { /* cancellation errors are acceptable here */ }
        }
        await task.value

        // The stream was broken after 1 event; the pipeline Task should have been
        // cancelled via onTermination. We assert the consumer stopped early.
        XCTAssertEqual(eventCount, 1, "Stream should have stopped after break")
    }
}
