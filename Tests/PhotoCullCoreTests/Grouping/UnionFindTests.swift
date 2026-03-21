import XCTest
@testable import PhotoCullCore

final class UnionFindTests: XCTestCase {

    func testTwoElementUnion() {
        var uf = UnionFind<String>()
        uf.union("A", "B")
        let components = uf.components()
        XCTAssertEqual(components.count, 1)
        XCTAssertEqual(Set(components[0]), ["A", "B"])
    }

    func testTransitiveUnion() {
        // A-B and B-C should merge into one component {A, B, C}.
        var uf = UnionFind<String>()
        uf.union("A", "B")
        uf.union("B", "C")
        let components = uf.components()
        XCTAssertEqual(components.count, 1)
        XCTAssertEqual(Set(components[0]), ["A", "B", "C"])
    }

    func testThreeSingletons() {
        var uf = UnionFind<String>()
        uf.insert("X")
        uf.insert("Y")
        uf.insert("Z")
        let components = uf.components()
        XCTAssertEqual(components.count, 3)
        for comp in components {
            XCTAssertEqual(comp.count, 1)
        }
    }

    func testIdempotentUnion() {
        // Unioning the same pair twice should produce the same result as once.
        var uf = UnionFind<String>()
        uf.union("A", "B")
        uf.union("A", "B")
        let components = uf.components()
        XCTAssertEqual(components.count, 1)
        XCTAssertEqual(Set(components[0]), ["A", "B"])
    }

    func testDisjointPairsProduceTwoComponents() {
        var uf = UnionFind<String>()
        uf.union("A", "B")
        uf.union("C", "D")
        let components = uf.components()
        XCTAssertEqual(components.count, 2)
        let allSets = components.map { Set($0) }
        XCTAssertTrue(allSets.contains(["A", "B"]))
        XCTAssertTrue(allSets.contains(["C", "D"]))
    }

    func testEmptyUnionFindHasNoComponents() {
        let uf = UnionFind<Int>()
        XCTAssertTrue(uf.components().isEmpty)
    }

    func testFindReturnsSelfForSingleton() {
        var uf = UnionFind<String>()
        uf.insert("solo")
        XCTAssertEqual(uf.find("solo"), "solo")
    }
}
