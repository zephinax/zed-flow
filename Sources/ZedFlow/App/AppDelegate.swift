import AppKit
import SwiftUI
import ZedFlowKit

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var lastCloseTime: Date = .distantPast

    // MARK: - Application Lifecycle

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Enforce single-instance core: check if another instance of ZedFlow is already running
        let bundleID = Bundle.main.bundleIdentifier ?? "com.zephinax.ZedFlow"
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        let myPID = ProcessInfo.processInfo.processIdentifier
        if runningApps.contains(where: { $0.processIdentifier != myPID }) {
            NSApp.terminate(nil)
            return
        }

        // Configure as a background menu bar accessory (no Dock icon, no App Switcher)
        NSApp.setActivationPolicy(.accessory)

        // Create the status bar item
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: "ZedFlow")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        self.statusItem = item

        // Create the popover with SwiftUI content
        let pop = NSPopover()
        pop.contentViewController = NSHostingController(
            rootView: MenuBarContentView(store: ScriptStore.shared)
        )
        pop.behavior = .transient
        pop.animates = true
        pop.delegate = self
        self.popover = pop

        // Load scripts and start IPC server
        Task {
            await ScriptStore.shared.loadScripts()
        }

        // Start polling the running-state for the status bar icon
        startIconPolling()
    }

    // MARK: - Popover Toggle

    @objc private func togglePopover(_ sender: Any?) {
        guard let popover, let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            // Prevent immediate re-open when transient-close races with the button click
            guard Date().timeIntervalSince(lastCloseTime) > 0.25 else { return }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    // MARK: - Icon Polling

    private func startIconPolling() {
        Task {
            while !Task.isCancelled {
                let running = ScriptStore.shared.runningCount > 0
                statusItem?.button?.image = NSImage(
                    systemSymbolName: running ? "terminal.fill" : "terminal",
                    accessibilityDescription: "ZedFlow"
                )
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    // MARK: - NSPopoverDelegate

    public func popoverDidClose(_ notification: Notification) {
        lastCloseTime = Date()
    }
}
