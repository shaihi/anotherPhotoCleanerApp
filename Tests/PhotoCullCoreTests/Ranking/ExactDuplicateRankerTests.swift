import XCTest
@testable import PhotoCullCore

final class ExactDuplicateRankerTests: XCTestCase {
    let ranker = ExactDuplicateRanker()

    func makeGroup(members: [PhotoAsset]) throws -> CullGroup {
        try CullGroup(reason: .exactDuplicate, members: members)
    }

    func testExactlyOneKeepPerGroup() throws {
        let members = (0..<4).map { PhotoAsset(id: "\($0)") }
        let group = try makeGroup(members: members)
        let recs = ranker.rank(group: group)
        XCTAssertEqual(recs.filter { $0.action == .keep }.count, 1)
    }

    func testFavoriteWinsOverNonFavorite() throws {
        let fav = PhotoAsset(id: "fav", isFavorite: true)
        let plain = PhotoAsset(id: "plain")
        let group = try makeGroup(members: [plain, fav])  // deliberately out of order
        let recs = ranker.rank(group: group)
        let kept = recs.first(where: { $0.action == .keep })
        XCTAssertEqual(kept?.asset.id, "fav")
    }

    func testEditedWinsOverUneditedWhenNeitherIsFavorite() throws {
        let edited = PhotoAsset(id: "edited", isEdited: true)
        let plain = PhotoAsset(id: "plain")
        let group = try makeGroup(members: [plain, edited])
        let recs = ranker.rank(group: group)
        let kept = recs.first(where: { $0.action == .keep })
        XCTAssertEqual(kept?.asset.id, "edited")
    }

    func testNewestWinsWhenNeitherFavoriteNorEdited() throws {
        let old = PhotoAsset(id: "old", creationDate: Date(timeIntervalSince1970: 1000))
        let new = PhotoAsset(id: "new", creationDate: Date(timeIntervalSince1970: 2000))
        let group = try makeGroup(members: [old, new])
        let recs = ranker.rank(group: group)
        let kept = recs.first(where: { $0.action == .keep })
        XCTAssertEqual(kept?.asset.id, "new")
    }

    func testFavoriteBeatsEdited() throws {
        let fav = PhotoAsset(id: "fav", isFavorite: true)
        let edited = PhotoAsset(id: "edited", isEdited: true)
        let group = try makeGroup(members: [edited, fav])
        let recs = ranker.rank(group: group)
        let kept = recs.first(where: { $0.action == .keep })
        XCTAssertEqual(kept?.asset.id, "fav")
    }

    func testFavoriteBeatsNewest() throws {
        let fav = PhotoAsset(id: "fav", creationDate: Date(timeIntervalSince1970: 500), isFavorite: true)
        let newer = PhotoAsset(id: "newer", creationDate: Date(timeIntervalSince1970: 9999))
        let group = try makeGroup(members: [newer, fav])
        let recs = ranker.rank(group: group)
        let kept = recs.first(where: { $0.action == .keep })
        XCTAssertEqual(kept?.asset.id, "fav")
    }

    func testAllOthersAreCull() throws {
        let members = (0..<5).map { PhotoAsset(id: "\($0)") }
        let group = try makeGroup(members: members)
        let recs = ranker.rank(group: group)
        XCTAssertEqual(recs.filter { $0.action == .cull }.count, 4)
    }
}
