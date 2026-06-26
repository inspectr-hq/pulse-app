import XCTest
@testable import Pulse

final class SettingsViewTests: XCTestCase {
    func testSettingsIncludesAboutTab() {
        XCTAssertTrue(SettingsView.Tab.allCases.contains(.about))
        XCTAssertEqual(SettingsView.Tab.about.rawValue, "About")
        XCTAssertEqual(SettingsView.Tab.about.icon, "info.circle")
    }

    func testAboutMetadataUsesExpectedAppNameAndGitHubURL() {
        XCTAssertEqual(SettingsView.appDisplayName, "Pulse")
        XCTAssertEqual(SettingsView.githubURL.absoluteString, "https://github.com/inspectr-hq/pulse-app")
        XCTAssertEqual(SettingsView.inspectrURL.absoluteString, "https://inspectr.dev")
    }
}
