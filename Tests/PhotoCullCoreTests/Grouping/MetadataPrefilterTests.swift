import XCTest
@testable import PhotoCullCore

final class MetadataPrefilterTests: XCTestCase {
    let prefilter = MetadataPrefilter()
    let config = CullConfiguration(
        nearDuplicateTimeWindowSeconds: 60.0,
        similarityThreshold: 0.15
    )

    // MARK: - Empty / single

    func testEmptyInputReturnsNoPairs() {
        XCTAssertTrue(prefilter.candidates(from: [], configuration: config).isEmpty)
    }

    func testSingleAssetReturnsNoPairs() {
        let asset = PhotoAsset(id: "solo")
        XCTAssertTrue(prefilter.candidates(from: [asset], configuration: config).isEmpty)
    }

    // MARK: - Burst pairing

    func testBurstIdPairingGroupsBurstMembers() {
        let a = PhotoAsset(id: "a", burstIdentifier: "burst-1")
        let b = PhotoAsset(id: "b", burstIdentifier: "burst-1")
        let pairs = prefilter.candidates(from: [a, b], configuration: config)
        XCTAssertEqual(pairs.count, 1)
        XCTAssertEqual(pairs[0].prefilterReason, .burstId)
        XCTAssertTrue(
            (pairs[0].assetIdA == "a" && pairs[0].assetIdB == "b") ||
            (pairs[0].assetIdA == "b" && pairs[0].assetIdB == "a")
        )
    }

    func testNilBurstIdentifierSkippedForBurstPass() {
        let a = PhotoAsset(id: "a", burstIdentifier: nil)
        let b = PhotoAsset(id: "b", burstIdentifier: nil)
        let pairs = prefilter.candidates(from: [a, b], configuration: config)
        XCTAssertTrue(pairs.filter { $0.prefilterReason == .burstId }.isEmpty)
    }

    // MARK: - Time-proximity pairing

    func testTimeWindowPairsAssetsWithinThreshold() {
        let now = Date()
        let a = PhotoAsset(id: "a", creationDate: now)
        let b = PhotoAsset(id: "b", creationDate: now.addingTimeInterval(30))
        let pairs = prefilter.candidates(from: [a, b], configuration: config)
        let timePairs = pairs.filter { $0.prefilterReason == .timeProximity }
        XCTAssertEqual(timePairs.count, 1)
    }

    func testTimeWindowDoesNotPairAssetsOutsideThreshold() {
        let now = Date()
        let a = PhotoAsset(id: "a", creationDate: now)
        let b = PhotoAsset(id: "b", creationDate: now.addingTimeInterval(120)) // 2 minutes
        let pairs = prefilter.candidates(from: [a, b], configuration: config)
        let timePairs = pairs.filter { $0.prefilterReason == .timeProximity }
        XCTAssertTrue(timePairs.isEmpty)
    }

    func testNilCreationDateSkippedForTimeWindowPass() {
        let a = PhotoAsset(id: "a", creationDate: nil)
        let b = PhotoAsset(id: "b", creationDate: nil)
        let pairs = prefilter.candidates(from: [a, b], configuration: config)
        XCTAssertTrue(pairs.filter { $0.prefilterReason == .timeProximity }.isEmpty)
    }

    // MARK: - Cross-media-type rejection

    func testCrossMediaTypePairIsRejected() {
        let now = Date()
        let photo = PhotoAsset(id: "p", creationDate: now, mediaType: .image)
        let video = PhotoAsset(id: "v", creationDate: now.addingTimeInterval(5), mediaType: .video)
        let pairs = prefilter.candidates(from: [photo, video], configuration: config)
        XCTAssertTrue(pairs.isEmpty)
    }

    func testSameMediaTypeDifferentSubtypesNotRejected() {
        // HDR photo vs standard photo — both are .image; pair should be allowed.
        let now = Date()
        let standard = PhotoAsset(id: "std", creationDate: now, mediaSubtypes: [], mediaType: .image)
        let hdr = PhotoAsset(id: "hdr", creationDate: now.addingTimeInterval(1),
                             mediaSubtypes: ["hdr"], mediaType: .image)
        let pairs = prefilter.candidates(from: [standard, hdr], configuration: config)
        XCTAssertFalse(pairs.isEmpty, "Same media type with differing subtypes should not be rejected")
    }

    // MARK: - Aspect-ratio filter

    func testAspectRatioMismatchBeyond5PercentIsRejected() {
        // 4:3 vs 16:9 — large ratio difference, should be rejected.
        let now = Date()
        let landscape43 = PhotoAsset(id: "43", creationDate: now, pixelWidth: 400, pixelHeight: 300)
        let landscape169 = PhotoAsset(id: "169", creationDate: now.addingTimeInterval(5),
                                      pixelWidth: 1600, pixelHeight: 900)
        let pairs = prefilter.candidates(from: [landscape43, landscape169], configuration: config)
        XCTAssertTrue(pairs.isEmpty, "Aspect-ratio mismatch >5% should be rejected")
    }

    func testSimilarAspectRatioIsAccepted() {
        // Both approximately 4:3 (400×300 vs 400×302 ≈ 0.66% difference).
        let now = Date()
        let a = PhotoAsset(id: "a", creationDate: now, pixelWidth: 400, pixelHeight: 300)
        let b = PhotoAsset(id: "b", creationDate: now.addingTimeInterval(2),
                           pixelWidth: 400, pixelHeight: 302)
        let pairs = prefilter.candidates(from: [a, b], configuration: config)
        XCTAssertFalse(pairs.isEmpty, "Similar aspect ratios should be accepted")
    }

    func testZeroDimensionAssetsSkipAspectRatioCheck() {
        // Assets with pixelWidth/Height == 0 should not be rejected by aspect-ratio.
        let now = Date()
        let a = PhotoAsset(id: "a", creationDate: now, pixelWidth: 0, pixelHeight: 0)
        let b = PhotoAsset(id: "b", creationDate: now.addingTimeInterval(2), pixelWidth: 0, pixelHeight: 0)
        // Both have .image mediaType (default), so cross-media check passes.
        let pairs = prefilter.candidates(from: [a, b], configuration: config)
        XCTAssertFalse(pairs.isEmpty, "Zero-dimension assets should skip aspect-ratio check")
    }

    // MARK: - Burst group size cap

    func testBurstGroupExceedingMaxSizeProducesCappedPairs() {
        // Create a burst group of 35 members, which exceeds the default cap of 30.
        // The prefilter should truncate to 30 members and produce C(30,2) = 435 pairs
        // rather than C(35,2) = 595 pairs.
        let now = Date()
        let capConfig = CullConfiguration(
            nearDuplicateTimeWindowSeconds: 60.0,
            similarityThreshold: 0.15,
            maxBurstGroupSize: 30
        )
        let burstMembers: [PhotoAsset] = (0 ..< 35).map { i in
            PhotoAsset(
                id: "burst-\(i)",
                creationDate: now.addingTimeInterval(Double(i)),
                burstIdentifier: "group-A"
            )
        }
        let pairs = prefilter.candidates(from: burstMembers, configuration: capConfig)
        let burstPairs = pairs.filter { $0.prefilterReason == .burstId }

        // C(30,2) = 435; all pairs will pass the compatibility check (same media type,
        // no aspect-ratio data since pixelWidth/Height default to 0).
        XCTAssertEqual(burstPairs.count, 435,
                       "A burst group of 35 capped to 30 should produce C(30,2)=435 pairs, got \(burstPairs.count)")
    }

    func testBurstGroupUnderCapProducesAllPairs() {
        // A burst group of exactly maxBurstGroupSize members should not be truncated.
        let now = Date()
        let capConfig = CullConfiguration(
            nearDuplicateTimeWindowSeconds: 60.0,
            similarityThreshold: 0.15,
            maxBurstGroupSize: 5
        )
        let burstMembers: [PhotoAsset] = (0 ..< 5).map { i in
            PhotoAsset(
                id: "burst-\(i)",
                creationDate: now.addingTimeInterval(Double(i)),
                burstIdentifier: "group-B"
            )
        }
        let pairs = prefilter.candidates(from: burstMembers, configuration: capConfig)
        let burstPairs = pairs.filter { $0.prefilterReason == .burstId }
        // C(5,2) = 10
        XCTAssertEqual(burstPairs.count, 10,
                       "A burst group of 5 at cap=5 should produce C(5,2)=10 pairs, got \(burstPairs.count)")
    }
}
