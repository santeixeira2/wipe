import SwiftUI

@main
struct WipeApp: App {
    var body: some Scene {
        MenuBarExtra("Wipe", systemImage: "internaldrive") {
            ContentView()
        }
        .menuBarExtraStyle(.menu)
    }
}
