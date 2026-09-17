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
            let img = NSImage(systemSymbolName: "terminal", accessibilityDescription: "ZedFlow")
            img?.isTemplate = true
            button.image = img
            button.contentTintColor = nil
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

        // Start polling running count for terminal vs terminal.fill icon
        startIconPolling()
    }

    // MARK: - Popover Toggle

    @objc private func togglePopover(_ sender: Any?) {
        guard let popover, let button = statusItem?.button else { return }

        if popover.isShown {
            popover.close()
        } else {
            // Guard against instantaneous event-loop bounce (within 80ms)
            if Date().timeIntervalSince(lastCloseTime) < 0.08 {
                return
            }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            if let window = popover.contentViewController?.view.window {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    // MARK: - Icon Polling

    private func startIconPolling() {
        Task {
            var lastRunning: Bool? = nil

            while !Task.isCancelled {
                let running = ScriptStore.shared.runningCount > 0

                if running != lastRunning {
                    lastRunning = running

                    let img = NSImage(
                        systemSymbolName: running ? "terminal.fill" : "terminal",
                        accessibilityDescription: "ZedFlow"
                    )
                    img?.isTemplate = true
                    statusItem?.button?.image = img
                    statusItem?.button?.contentTintColor = nil
                }

                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    // MARK: - NSPopoverDelegate

    public func popoverDidShow(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        if let window = popover?.contentViewController?.view.window {
            window.makeKeyAndOrderFront(nil)
        }
    }

    public func popoverDidClose(_ notification: Notification) {
        lastCloseTime = Date()
    }
}
