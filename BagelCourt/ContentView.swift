import SwiftUI
import SwiftData

/// Root coordinator: NavigationStack + overlay presenters.
struct ContentView: View {
    @State private var activeController: LiveMatchController? = nil
    @State private var showingSettings = false
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            HistoryView(
                onNewMatch: { match in
                    activeController = LiveMatchController(match: match, modelContext: context)
                },
                onResumeMatch: { ctrl in
                    activeController = ctrl
                }
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.cbMuted)
                    }
                }
            }
            .navigationDestination(for: MatchRecord.self) { record in
                ResultView(record: record)
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(item: $activeController) { ctrl in
            InMatchView(controller: ctrl) {
                activeController = nil
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: MatchRecord.self, inMemory: true)
}
