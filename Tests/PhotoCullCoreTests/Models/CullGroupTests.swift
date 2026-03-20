import XCTest
@testable import PhotoCullCore

final class CullGroupTests: XCTestCase {
    func testRequiresMinimumTwoMembers() {
        let single = [PhotoAsset(id: "only")]
        XCTAssertThrowsError(try CullGroup(reason: .exactDuplicate, members: single)) { error in
            guard case CullGroupError.insufficientMembers(let count) = error else {
                return XCTFail("Wrong error type")
            }
            XCTAssertEqual(count, 1)
        }
    }

    func testRejectsEmptyMembers() {
        XCTAssertThrowsError(try CullGroup(reason: .exactDuplicate, members: [])) { error in
            guard case CullGroupError.insufficientMembers(let count) = error else {
                return XCTFail("Wrong error type")
            }
            XCTAssertEqual(count, 0)
        }
    }

    func testAcceptsTwoMembers() throws {
        let group = try CullGroup(reason: .exactDuplicate, members: [
            PhotoAsset(id: "a"), PhotoAsset(id: "b")
        ])
        XCTAssertEqual(group.members.count, 2)
        XCTAssertEqual(group.reason, .exactDuplicate)
    }

    func testAcceptsMoreThanTwoMembers() throws {
        let members = (0..<5).map { PhotoAsset(id: "m\($0)") }
        let group = try CullGroup(reason: .exactDuplicate, members: members)
        XCTAssertEqual(group.members.count, 5)
    }

    func testUniqueIds() throws {
        let g1 = try CullGroup(reason: .exactDuplicate, members: [PhotoAsset(id: "a"), PhotoAsset(id: "b")])
        let g2 = try CullGroup(reason: .exactDuplicate, members: [PhotoAsset(id: "a"), PhotoAsset(id: "b")])
        XCTAssertNotEqual(g1.id, g2.id)
    }
}
