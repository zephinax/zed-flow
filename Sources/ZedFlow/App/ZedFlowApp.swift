import SwiftUI
import ZedFlowKit

@main
struct ZedFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // All UI is handled by AppDelegate's NSPopover + NSStatusItem.
        // Settings scene is required as a placeholder; it is never visible
        // because the app uses .accessory activation policy (no app menu).
        Settings {
            EmptyView()
        }
    }
}
