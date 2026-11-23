import XCTest

@testable import CorkboardCore

final class AppVersionTests: XCTestCase {
    func testCurrentVersionIsAReleaseNumber() {
        XCTAssertNotNil(AppVersion(tag: CorkboardVersion.current))
        XCTAssertEqual(
            AppVersion(tag: CorkboardVersion.current)?.description, CorkboardVersion.current)
    }

    func testTagParsesALeadingVAndShortForms() {
        XCTAssertEqual(AppVersion(tag: "v0.2.0"), AppVersion(major: 0, minor: 2, patch: 0))
        XCTAssertEqual(AppVersion(tag: "V1.4"), AppVersion(major: 1, minor: 4, patch: 0))
        XCTAssertEqual(AppVersion(tag: " 3 "), AppVersion(major: 3, minor: 0, patch: 0))
        XCTAssertNil(AppVersion(tag: "0.2.0-beta"))
        XCTAssertNil(AppVersion(tag: "nope"))
        XCTAssertNil(AppVersion(tag: "1.2.3.4"))
    }

    func testOrderingIsNumeric() {
        let older = AppVersion(major: 0, minor: 2, patch: 0)
        let newer = AppVersion(major: 0, minor: 10, patch: 0)
        XCTAssertLessThan(older, newer)
        XCTAssertFalse(newer < older)
        XCTAssertEqual(older, AppVersion(tag: "0.2.0"))
    }
}
