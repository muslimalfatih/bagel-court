import SwiftUI
import SwiftData

/// Root coordinator: NavigationStack + overlay presenters.
struct ContentView: View {
    @State private var activeController: LiveMatchController? = nil
    /// Sources for the system zoom transitions: sheets grow out of the button that opened them,
    /// and a scorecard grows out of its history row.
    @Namespace private var transitions

    var body: some View {
        NavigationStack {
            HistoryView(transitions: transitions, onResumeMatch: { ctrl in
                activeController = ctrl
            })
            .navigationDestination(for: MatchRecord.self) { record in
                ResultView(record: record)
                    .navigationTransition(.zoom(sourceID: record.id, in: transitions))
            }
        }
        .preferredColorScheme(.dark)
        .tint(Color.bcAccent)   // the AccentColor asset is empty, so untinted icons fell back to iOS blue
        .fullScreenCover(item: $activeController) { ctrl in
            InMatchView(controller: ctrl) {
                activeController = nil
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: MatchRecord.self, inMemory: true)
}
