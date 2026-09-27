import SwiftUI
import SwiftData

@main
struct BagelCourtApp: App {
    init() {
        BCFonts.register()
        WatchBridge.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: MatchRecord.self)
    }
}
