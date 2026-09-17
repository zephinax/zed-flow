import SwiftUI
import AppKit
import ZedFlowKit

@main
struct ZedFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var store = ScriptStore()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(store: store)
                .task {
                    await store.loadScripts()
                }
        } label: {
            Label {
                Text("ZedFlow")
            } icon: {
                Image(systemName: store.runningCount > 0 ? "terminal.fill" : "terminal")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
