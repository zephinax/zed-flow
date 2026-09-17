@preconcurrency import SwiftUI
@preconcurrency import AppKit

/// Manages the MenuBarExtra panel window to prevent menu bar auto-hiding
/// when ZedFlow is open, and keeps the panel anchored in place.
struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowConfiguratorView {
        WindowConfiguratorView()
    }

    func updateNSView(_ nsView: WindowConfiguratorView, context: Context) {
        // Re-apply on each SwiftUI update to keep state consistent
        nsView.configureWindow()
    }
}

@MainActor
final class WindowConfiguratorView: NSView {
    private var windowObservers: [any NSObjectProtocol] = []
    private var isConfigured = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureWindow()
        setupWindowObservers()
    }

    func configureWindow() {
        guard let window = self.window else { return }

        // Set window level high enough to stay above full-screen apps
        window.level = .popUpMenu

        // Allow the panel to appear on all spaces including full-screen
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        // Prevent the window from hiding when app deactivates
        if let panel = window as? NSPanel {
            panel.hidesOnDeactivate = false
            panel.becomesKeyOnlyIfNeeded = false
        }

        // Keep the window fixed in position
        window.isMovable = false
        window.isMovableByWindowBackground = false

        if !isConfigured {
            isConfigured = true
            // Force the menu bar to be visible when our window first appears
            MenuBarVisibilityController.shared.panelDidOpen()
        }
    }

    private func setupWindowObservers() {
        // Clean up previous observers
        for observer in windowObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        windowObservers.removeAll()

        guard let window = self.window else { return }

        // When the window becomes visible/key, force menu bar visible
        let becomeKey = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.configureWindow()
                MenuBarVisibilityController.shared.panelDidOpen()
            }
        }
        windowObservers.append(becomeKey)

        // When window resigns key (panel closing), restore original state
        let resignKey = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: window,
            queue: .main
        ) { _ in
            Task { @MainActor in
                MenuBarVisibilityController.shared.panelDidClose()
            }
        }
        windowObservers.append(resignKey)

        // When window is about to close, clean up
        let willClose = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            Task { @MainActor in
                MenuBarVisibilityController.shared.panelDidClose()
            }
        }
        windowObservers.append(willClose)
    }

    override func removeFromSuperview() {
        cleanUpObservers()
        MenuBarVisibilityController.shared.panelDidClose()
        super.removeFromSuperview()
    }

    nonisolated func cleanUpObserversFromDeinit() {
        // We cannot safely access windowObservers from deinit in Swift 6
        // The removeFromSuperview() path handles cleanup instead
    }

    private func cleanUpObservers() {
        for observer in windowObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        windowObservers.removeAll()
    }
}

/// Singleton controller that manages menu bar visibility while ZedFlow panel is open.
/// Uses NSApp activation policy cycling to temporarily prevent the menu bar from auto-hiding.
@MainActor
final class MenuBarVisibilityController {
    static let shared = MenuBarVisibilityController()

    private var isPanelOpen = false

    private init() {}

    func panelDidOpen() {
        guard !isPanelOpen else { return }
        isPanelOpen = true

        // Temporarily activate as a regular app so the menu bar is forced visible.
        // When a regular app is frontmost, macOS always shows the menu bar.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // After a brief moment, switch back to accessory to hide from Dock,
        // but our panel stays on top because its level is .popUpMenu
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self, self.isPanelOpen else { return }
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func panelDidClose() {
        guard isPanelOpen else { return }
        isPanelOpen = false
        NSApp.setActivationPolicy(.accessory)
    }
}
