import XCTest
@testable import PhotoCullCore

final class GroupBuilderTests: XCTestCase {
    let builder = GroupBuilder()

    func testTwoAssetsWithSameHashFormOneGroup() {
        let results = SyntheticAssetFactory.duplicateSet(count: 2, hashSeed: "same")
        let groups = builder.buildGroups(from: results)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].members.count, 2)
    }

    func testThreeAssetsWithSameHashFormOneGroup() {
        let results = SyntheticAssetFactory.duplicateSet(count: 3, hashSeed: "triple")
        let groups = builder.buildGroups(from: results)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].members.count, 3)
    }

    func testUniqueHashesProduceNoGroups() {
        let results = [
            SyntheticAssetFactory.hashResult(asset: PhotoAsset(id: "a"), hashSeed: "h1"),
            SyntheticAssetFactory.hashResult(asset: PhotoAsset(id: "b"), hashSeed: "h2"),
            SyntheticAssetFactory.hashResult(asset: PhotoAsset(id: "c"), hashSeed: "h3"),
        ]
        let groups = builder.buildGroups(from: results)
        XCTAssertTrue(groups.isEmpty)
    }

    func testEmptyInputProducesNoGroups() {
        XCTAssertTrue(builder.buildGroups(from: []).isEmpty)
    }

    func testTwoDistinctDuplicatePairsFormTwoGroups() {
        let pairA = SyntheticAssetFactory.duplicateSet(count: 2, hashSeed: "A")
        let pairB = SyntheticAssetFactory.duplicateSet(count: 2, hashSeed: "B")
        let groups = builder.buildGroups(from: pairA + pairB)
        XCTAssertEqual(groups.count, 2)
    }

    func testGroupReasonIsExactDuplicate() {
        let results = SyntheticAssetFactory.duplicateSet(count: 2, hashSeed: "x")
        let groups = builder.buildGroups(from: results)
        XCTAssertEqual(groups[0].reason, .exactDuplicate)
    }

    func testSingletonAssetsAreExcluded() {
        let singleton = SyntheticAssetFactory.hashResult(asset: PhotoAsset(id: "lone"), hashSeed: "unique-lone")
        let pair = SyntheticAssetFactory.duplicateSet(count: 2, hashSeed: "paired")
        let groups = builder.buildGroups(from: [singleton] + pair)
        XCTAssertEqual(groups.count, 1)
        XCTAssertFalse(groups[0].members.contains(where: { $0.id == "lone" }))
    }

    func testLargerGroupSortedFirst() {
        let big = SyntheticAssetFactory.duplicateSet(count: 4, hashSeed: "big")
        let small = SyntheticAssetFactory.duplicateSet(count: 2, hashSeed: "small")
        let groups = builder.buildGroups(from: big + small)
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].members.count, 4)
    }
}
