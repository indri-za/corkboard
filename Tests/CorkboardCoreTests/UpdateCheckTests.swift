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

final class UpdateCheckTests: XCTestCase {
    private let page = URL(string: "https://github.com/indri-za/corkboard/releases/tag/v0.10.0")!

    private func response(status: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: UpdateChecker.request().url!, statusCode: status, httpVersion: nil,
            headerFields: nil
        )!
    }

    func testANewerReleaseIsAvailable() {
        let body = Data(
            """
            {"tag_name":"v0.10.0","html_url":"\(page.absoluteString)"}
            """.utf8)
        let report = UpdateChecker.report(
            current: "0.2.0", data: body, response: response(status: 200), error: nil)
        XCTAssertEqual(
            report,
            .available(current: "0.2.0", latest: "0.10.0", page: page))
    }

    func testTheSameReleaseIsUpToDate() {
        let body = Data(
            """
            {"tag_name":"v0.2.0","html_url":"https://github.com/indri-za/corkboard/releases/tag/v0.2.0"}
            """.utf8)
        let report = UpdateChecker.report(
            current: "0.2.0", data: body, response: response(status: 200), error: nil)
        XCTAssertEqual(report, .upToDate(current: "0.2.0"))
    }

    func testALocalBuildAheadOfTheReleaseIsReported() {
        let body = Data(
            """
            {"tag_name":"v0.2.0","html_url":"https://github.com/indri-za/corkboard/releases/tag/v0.2.0"}
            """.utf8)
        let report = UpdateChecker.report(
            current: "0.3.0", data: body, response: response(status: 200), error: nil)
        XCTAssertEqual(report, .ahead(current: "0.3.0", latest: "0.2.0"))
    }

    func testABadPayloadAndHTTPErrorFail() {
        let garbage = UpdateChecker.report(
            current: "0.2.0", data: Data("nope".utf8), response: response(status: 200), error: nil)
        XCTAssertEqual(garbage, .failed("Couldn't read the latest release."))
        let denied = UpdateChecker.report(
            current: "0.2.0", data: nil, response: response(status: 403), error: nil)
        XCTAssertEqual(denied, .failed("Couldn't check for updates (HTTP 403)."))
        let offline = NSError(
            domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "offline"])
        let failed = UpdateChecker.report(
            current: "0.2.0", data: nil, response: nil, error: offline)
        XCTAssertEqual(failed, .failed("Couldn't check for updates. offline"))
    }
}
