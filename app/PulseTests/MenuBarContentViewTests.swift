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
}
