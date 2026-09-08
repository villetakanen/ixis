import AppKit
import SwiftUI

@main
struct PraxisApp: App {
    @Environment(\.openWindow) private var openWindow

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
            DebugView()
        }
        .defaultSize(width: 480, height: 360)
        // The debug window is opened only from the menu bar item.
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
    }
}
