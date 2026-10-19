import SwiftUI

@main
struct GameFarmApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var game = GameState.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(game)
                .environment(Lang.shared)
                .environment(Store.shared)
                .environment(Ads.shared)
                .task {
                    Store.shared.start()
                    Ads.shared.start()
                }
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
