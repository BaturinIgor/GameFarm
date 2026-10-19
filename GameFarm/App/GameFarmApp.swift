import SwiftUI

@main
struct GameFarmApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var game = GameState.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(game)
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                game.applyOfflineProgress()
            case .inactive, .background:
                game.saveNow()
            @unknown default:
                break
            }
        }
    }
}
