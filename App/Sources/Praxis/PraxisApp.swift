import AppKit
import PraxisDesktop
import SwiftUI

@main
struct PraxisApp: App {
    @Environment(\.openWindow) private var openWindow

    /// One probe per process. A relaunch therefore starts disabled and
    /// unconfirmed; only the shortcut mappings are read back from UserDefaults.
    @State private var probe = ProductionProbe.production()

    var body: some Scene {
        MenuBarExtra("Praxis", systemImage: "hand.raised") {
            Button("Open Debug Window") {
                openWindow(id: DebugView.windowID)
                // Menu bar (LSUIElement) apps are not activated by default, so
                // the window would otherwise open behind the frontmost app.
                NSApplication.shared.activate()
            }
            Divider()
            Button("Quit Praxis") {
                NSApplication.shared.terminate(nil)
            }
        }

        Window("Praxis Debug", id: DebugView.windowID) {
            DebugView(probe: probe)
                .onAppear { NSApplication.shared.activate() }
        }
        .defaultSize(width: 560, height: 720)
        // Keep the probe reachable even when the menu bar icon is hidden.
        .defaultLaunchBehavior(.presented)
        .restorationBehavior(.disabled)
    }
}
