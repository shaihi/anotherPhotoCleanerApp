import XCTest
@testable import PhotoCullCore

final class ScanProgressTests: XCTestCase {
    func testFractionZeroWhenTotalIsZero() {
        let p = ScanProgress(phase: .fetchingAssets, processed: 0, total: 0, message: "")
        XCTAssertEqual(p.fraction, 0)
    }

    func testFractionCalculation() {
        let p = ScanProgress(phase: .hashing, processed: 50, total: 100, message: "")
        XCTAssertEqual(p.fraction, 0.5, accuracy: 0.001)
    }

    func testFractionCappedAtOne() {
        let p = ScanProgress(phase: .complete, processed: 110, total: 100, message: "")
        XCTAssertEqual(p.fraction, 1.0, accuracy: 0.001)
    }

    func testAllPhasesExist() {
        // Ensure enum is iterable and non-empty
        XCTAssertFalse(ScanPhase.allCases.isEmpty)
        XCTAssertTrue(ScanPhase.allCases.contains(.complete))
    }
}
