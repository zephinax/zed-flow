import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure as a background menu bar accessory (no Dock icon, no App Switcher)
        NSApp.setActivationPolicy(.accessory)
    }
}
