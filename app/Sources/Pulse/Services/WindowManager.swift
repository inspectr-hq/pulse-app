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

    private var hasOpenWindows: Bool {
        [
            siteManagerWindow,
            historyWindow,
            historyReportsWindow,
            settingsWindow
        ].contains { $0 != nil }
    }

    private func updateActivationPolicy() {
        NSApp.setActivationPolicy(activationPolicy(hasOpenWindows: hasOpenWindows))
    }

    func showSiteManager(appVM: AppViewModel) {
        logger.info("showSiteManager called")
        updateActivationPolicy()
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
        let delegate = WindowStateDelegate { [weak self] in
            self?.siteManagerWindow = nil
            self?.siteManagerDelegate = nil
            self?.updateActivationPolicy()
        }
        siteManagerDelegate = delegate
        window.delegate = delegate
        siteManagerWindow = window
        updateActivationPolicy()
        window.center()
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        logger.info("showSiteManager created and opened window")
    }

    func showHistory(
        appVM: AppViewModel,
        selectedName: String? = nil,
        timeFilter: HistoryViewModel.TimeFilter? = nil,
        graphSite: String? = nil,
        graphRange: HistoryViewModel.GraphRange? = nil
    ) {
        logger.info("showHistory called")
        updateActivationPolicy()
        if let window = historyWindow {
            logger.info("showHistory reusing existing window")
            window.contentView = NSHostingView(rootView: HistoryView(
                selectedName: selectedName,
                timeFilter: timeFilter,
                graphSite: graphSite,
                graphRange: graphRange
            ).environmentObject(appVM))
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            NSApp.unhide(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = HistoryView(
            selectedName: selectedName,
            timeFilter: timeFilter,
            graphSite: graphSite,
            graphRange: graphRange
        ).environmentObject(appVM)
        let window = NSWindow(
            contentRect: historyWindowFrame(),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "History Logs"
        window.contentView = NSHostingView(rootView: view)
        window.isReleasedWhenClosed = false
        let delegate = WindowStateDelegate { [weak self] in
            self?.historyWindow = nil
            self?.historyDelegate = nil
            self?.updateActivationPolicy()
        }
        historyDelegate = delegate
        window.delegate = delegate
        historyWindow = window
        updateActivationPolicy()
        window.center()
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        logger.info("showHistory created and opened window")
    }

    func showHistoryReports(appVM: AppViewModel) {
        logger.info("showHistoryReports called")
        updateActivationPolicy()
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
        let delegate = WindowStateDelegate { [weak self] in
            self?.historyReportsWindow = nil
            self?.historyReportsDelegate = nil
            self?.updateActivationPolicy()
        }
        historyReportsDelegate = delegate
        window.delegate = delegate
        historyReportsWindow = window
        updateActivationPolicy()
        window.center()
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        logger.info("showHistoryReports created and opened window")
    }

    func showSettings(appVM: AppViewModel) {
        logger.info("showSettings called")
        updateActivationPolicy()
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
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.minSize = NSSize(width: 600, height: 620)
        window.contentView = NSHostingView(rootView: view)
        window.isReleasedWhenClosed = false
        let delegate = WindowStateDelegate(onClose: { [weak self] in
            self?.settingsWindow = nil
            self?.settingsDelegate = nil
            self?.updateActivationPolicy()
        }, preserveTopOnResize: true)
        settingsDelegate = delegate
        window.delegate = delegate
        settingsWindow = window
        updateActivationPolicy()
        window.center()
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        logger.info("showSettings created and opened window")
    }
}

func activationPolicy(hasOpenWindows: Bool) -> NSApplication.ActivationPolicy {
    hasOpenWindows ? .regular : .accessory
}

private func centerHorizontally(_ window: NSWindow, topEdge: CGFloat? = nil) {
    let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
    window.setFrameOrigin(
        windowCenteredOrigin(
            frame: window.frame,
            visibleFrame: visibleFrame,
            topEdge: topEdge
        )
    )
}

private final class WindowStateDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void
    private let preserveTopOnResize: Bool
    private var topEdgeBeforeResize: CGFloat?

    init(onClose: @escaping () -> Void, preserveTopOnResize: Bool = false) {
        self.onClose = onClose
        self.preserveTopOnResize = preserveTopOnResize
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }

    func windowWillResize(_ window: NSWindow, to frameSize: NSSize) -> NSSize {
        guard preserveTopOnResize else { return frameSize }
        topEdgeBeforeResize = window.frame.maxY
        return frameSize
    }

    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        guard preserveTopOnResize else { return }
        centerHorizontally(window, topEdge: topEdgeBeforeResize)
    }
}

func windowCenteredOrigin(frame: NSRect, visibleFrame: NSRect, topEdge: CGFloat? = nil) -> CGPoint {
    let top = topEdge ?? frame.maxY
    return CGPoint(
        x: visibleFrame.midX - frame.width / 2,
        y: top - frame.height
    )
}

func historyWindowFrame() -> NSRect {
    NSRect(x: 0, y: 0, width: 1_120, height: 560)
}
