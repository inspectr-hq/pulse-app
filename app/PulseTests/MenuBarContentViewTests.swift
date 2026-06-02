import XCTest
@testable import Pulse

final class MenuBarContentViewTests: XCTestCase {
    func testVisibleMonitorsKeepsPausedSitesWhenSettingIsOff() {
        let active = SiteMonitor(url: URL(string: "https://a.com")!, displayName: "Active", isEnabled: true)
        let paused = SiteMonitor(url: URL(string: "https://b.com")!, displayName: "Paused", isEnabled: false)

        let visible = MenuBarContentView.visibleMonitors(
            monitors: [active, paused],
            hidePausedSitesInMenuBar: false
        )

        XCTAssertEqual(visible.map(\.displayName), ["Active", "Paused"])
    }

    func testVisibleMonitorsHidesPausedSitesWhenSettingIsOn() {
        let active = SiteMonitor(url: URL(string: "https://a.com")!, displayName: "Active", isEnabled: true)
        let paused = SiteMonitor(url: URL(string: "https://b.com")!, displayName: "Paused", isEnabled: false)

        let visible = MenuBarContentView.visibleMonitors(
            monitors: [active, paused],
            hidePausedSitesInMenuBar: true
        )

        XCTAssertEqual(visible.map(\.displayName), ["Active"])
    }

    func testAccessoryActionUsesBrowserForGetMonitors() {
        let monitor = SiteMonitor(url: URL(string: "https://example.com")!, displayName: "Example", method: .get)

        let action = MenuBarContentView.accessoryAction(for: monitor)

        XCTAssertEqual(action, .openURL)
    }

    func testAccessoryActionUsesCurlForPostMonitors() {
        let monitor = SiteMonitor(url: URL(string: "https://example.com/webhook")!, displayName: "Webhook", method: .post)

        let action = MenuBarContentView.accessoryAction(for: monitor)

        XCTAssertEqual(action, .copyCurl)
    }

    func testCurlCommandIncludesMethodHeadersBodyAndURL() {
        let monitor = SiteMonitor(
            url: URL(string: "https://example.com/webhook")!,
            displayName: "Webhook",
            method: .post,
            body: #"{"hello":"world"}"#,
            headers: [
                HeaderEntry(name: "Content-Type", value: "application/json"),
                HeaderEntry(name: "", value: "ignored")
            ]
        )

        let command = MenuBarContentView.curlCommand(for: monitor)

        XCTAssertTrue(command.contains("curl"))
        XCTAssertTrue(command.contains("-X POST"))
        XCTAssertTrue(command.contains("-H \"Content-Type: application/json\""))
        XCTAssertTrue(command.contains("--data-raw \"{\\\"hello\\\":\\\"world\\\"}\""))
        XCTAssertTrue(command.contains("\"https://example.com/webhook\""))
        XCTAssertFalse(command.contains("ignored"))
    }
}
