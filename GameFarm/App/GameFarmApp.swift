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
                    Sound.shared.start()
                    Store.shared.start()
                    Ads.shared.start()
                    CloudSync.shared.start()
                    GameCenter.shared.authenticate()
                }
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
        .onChange(of: scenePhase) { old, phase in
            switch phase {
            case .active:
                game.applyOfflineProgress()
                Sound.shared.resumeAll()
            case .background:
                game.saveNow()
                CloudSync.shared.push(game.save, force: true)
                Sound.shared.pauseAll()
            case .inactive where old == .active:
                game.saveNow()
            default:
                // Переход из фона в inactive не должен затирать время ухода,
                // иначе офлайн-добыча считается от нуля.
                break
            }
        }
    }
}
