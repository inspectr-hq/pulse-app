import AppKit
import OSLog
import SwiftUI

@MainActor
final class WindowManager {
    static let shared = WindowManager()
    private let logger = Logger(subsystem: "dev.pulse.app", category: "WindowManager")

    private var siteManagerWindow: NSWindow?
    private var historyWindow: NSWindow?
    private var historyReportsWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var siteManagerDelegate: NSWindowDelegate?
    private var historyDelegate: NSWindowDelegate?
    private var historyReportsDelegate: NSWindowDelegate?
    private var settingsDelegate: NSWindowDelegate?

    private init() {}

    func showSiteManager(appVM: AppViewModel) {
        logger.info("showSiteManager called")
        NSApp.setActivationPolicy(.regular)
        if let window = siteManagerWindow {
            logger.info("showSiteManager reusing existing window")
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            NSApp.unhide(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SiteManagerView().environmentObject(appVM)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 940, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Site Manager"
        window.contentView = NSHostingView(rootView: view)
        window.isReleasedWhenClosed = false
        let delegate = WindowCloseDelegate { [weak self] in
            self?.siteManagerWindow = nil
            self?.siteManagerDelegate = nil
        }
        siteManagerDelegate = delegate
        window.delegate = delegate
        siteManagerWindow = window
        window.center()
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        logger.info("showSiteManager created and opened window")
    }

    func showHistory(appVM: AppViewModel) {
        logger.info("showHistory called")
        NSApp.setActivationPolicy(.regular)
        if let window = historyWindow {
            logger.info("showHistory reusing existing window")
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            NSApp.unhide(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = HistoryView().environmentObject(appVM)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 940, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "History Logs"
        window.contentView = NSHostingView(rootView: view)
        window.isReleasedWhenClosed = false
        let delegate = WindowCloseDelegate { [weak self] in
            self?.historyWindow = nil
            self?.historyDelegate = nil
        }
        historyDelegate = delegate
        window.delegate = delegate
        historyWindow = window
        window.center()
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        logger.info("showHistory created and opened window")
    }

    func showHistoryReports(appVM: AppViewModel) {
        logger.info("showHistoryReports called")
        NSApp.setActivationPolicy(.regular)
        if let window = historyReportsWindow {
            logger.info("showHistoryReports reusing existing window")
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            NSApp.unhide(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = HistoryReportsView().environmentObject(appVM)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1040, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Dashboard"
        window.contentView = NSHostingView(rootView: view)
        window.isReleasedWhenClosed = false
        let delegate = WindowCloseDelegate { [weak self] in
            self?.historyReportsWindow = nil
            self?.historyReportsDelegate = nil
        }
        historyReportsDelegate = delegate
        window.delegate = delegate
        historyReportsWindow = window
        window.center()
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        logger.info("showHistoryReports created and opened window")
    }

    func showSettings(appVM: AppViewModel) {
        logger.info("showSettings called")
        NSApp.setActivationPolicy(.regular)
        if let window = settingsWindow {
            logger.info("showSettings reusing existing window")
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            NSApp.unhide(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SettingsView().environmentObject(appVM)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 380),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.contentView = NSHostingView(rootView: view)
        window.isReleasedWhenClosed = false
        let delegate = WindowCloseDelegate { [weak self] in
            self?.settingsWindow = nil
            self?.settingsDelegate = nil
        }
        settingsDelegate = delegate
        window.delegate = delegate
        settingsWindow = window
        window.center()
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        logger.info("showSettings created and opened window")
    }
}

private final class WindowCloseDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
