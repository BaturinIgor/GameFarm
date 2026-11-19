import Foundation
import SwiftUI

#if DEBUG
/// Макеты всех экранов (design/<версия>/screens): с -design игра запускается на прогрессе середины игры
/// (сохранение на диске не читается), -design-new - первый запуск, -design-sheet <окно> открывает окно,
/// -design-overlay <карточка> показывает карточку поверх игры. Только отладочная сборка.
enum DesignDemo {
    static var args: [String] { ProcessInfo.processInfo.arguments }
    static var active: Bool { args.contains("-design") }

    static func value(_ name: String) -> String? {
        guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    static func save() -> SaveData? {
        guard active else { return nil }
        var s = SaveData()
        if args.contains("-design-new") { return s }
        s.tutorialDone = true
        s.level = 18
        s.xp = 40
        s.coins = 4820
        for (i, kind) in ResourceKind.allCases.prefix(12).enumerated() { s.storage[kind] = 6 + i * 7 }
        for (i, kind) in ResourceKind.allCases.prefix(4).enumerated() { s.backpack[kind] = 2 + i }
        for tool in ToolKind.allCases { s.tools[tool] = 3 }
        s.unlocked = Array(LocationID.allCases.prefix(4))
        for (i, id) in AnimalID.allCases.prefix(6).enumerated() { s.animals[id] = 1 + i % 3 }
        s.active = Array(AnimalID.allCases.prefix(3))
        s.harvests = 640
        s.coinsEarned = 9400
        return s
    }

    @MainActor
    static func start(_ game: GameState) async -> GameSheet? {
        guard active else { return nil }
        try? await Task.sleep(for: .milliseconds(800))
        let items = ResourceKind.allCases.prefix(4).enumerated().map { ResourceAmount(kind: $0.element, amount: 3 + $0.offset * 4) }
        switch value("-design-overlay") {
        case "levelUp": game.levelUp = LevelUpInfo(from: 17, to: 18)
        case "offline": game.offlineReport = OfflineReport(duration: 3 * 3600 + 25 * 60, items: items)
        case "treasure": game.treasureFound = Treasure(coins: 120, items: Array(items.prefix(2)))
        default: break
        }
        return value("-design-sheet").flatMap(GameSheet.init(rawValue:))
    }
}
#endif

extension View {
    /// Отладочная сборка: окно или карточка для макетов. В релизе ничего не делает.
    @ViewBuilder
    func designDemo(_ game: GameState, open: @escaping (GameSheet) -> Void) -> some View {
        #if DEBUG
        task { if let sheet = await DesignDemo.start(game) { open(sheet) } }
        #else
        self
        #endif
    }
}
