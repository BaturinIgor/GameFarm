import Foundation

enum QuestType: String, Codable {
    case gather, harvest, sell, deposit, tame, treasure
}

/// Задание с доски заданий. Три задания активны одновременно.
struct Quest: Codable, Identifiable, Equatable {
    var id = UUID()
    var type: QuestType
    var resource: String?
    var target: Int
    var progress: Int = 0
    var coins: Int
    var xp: Int

    var kind: ResourceKind? { resource.flatMap { ResourceKind(rawValue: $0) } }
    var done: Bool { progress >= target }
    var fraction: Double { min(1, Double(progress) / Double(max(1, target))) }

    var icon: String {
        switch type {
        case .gather: kind?.emoji ?? "⛏️"
        case .harvest: "⛏️"
        case .sell: "🪙"
        case .deposit: "📦"
        case .tame: "🐾"
        case .treasure: "🎁"
        }
    }

    var title: String {
        switch type {
        case .gather: tr("quest.gather", kind?.name ?? "")
        case .harvest: tr("quest.harvest", Fmt.n(target))
        case .sell: tr("quest.sell", Fmt.n(target))
        case .deposit: tr("quest.deposit", Fmt.n(target))
        case .tame: tr("quest.tame")
        case .treasure: target > 1 ? tr("quest.treasures", target) : tr("quest.treasure")
        }
    }

    static func make(level: Int, available: [ResourceKind], producers: [ResourceKind], avoid: [Quest]) -> Quest {
        let usedTypes = avoid.map(\.type)
        let usedKinds = avoid.compactMap(\.kind)
        var options: [QuestType] = [.gather, .gather, .harvest, .sell, .deposit, .gather, .treasure]
        if level >= 2 { options.append(.tame) }
        options = options.filter { $0 == .gather || !usedTypes.contains($0) }
        let type = options.randomElement() ?? .gather
        let xpBase = Double(GameRules.xpToNext(level))
        let lvl = Double(level)

        switch type {
        case .gather:
            let pool = (available + producers).filter { !usedKinds.contains($0) }
            let kind = pool.randomElement() ?? .wood
            let raw = (40 + lvl * 6) / pow(Double(kind.price), 0.55)
            let target = max(5, Int((raw / 5).rounded()) * 5)
            return Quest(type: .gather, resource: kind.rawValue, target: target,
                         coins: Int(Double(target * kind.price) * 1.5) + level * 20, xp: Int(xpBase * 0.18))
        case .harvest:
            let target = 20 + level * 2
            return Quest(type: .harvest, target: target, coins: 40 + level * 30, xp: Int(xpBase * 0.2))
        case .sell:
            let target = max(100, Int((pow(lvl, 1.5) * 40 / 50).rounded()) * 50)
            return Quest(type: .sell, target: target, coins: target / 4 + level * 10, xp: Int(xpBase * 0.15))
        case .deposit:
            let target = 50 + level * 10
            return Quest(type: .deposit, target: target, coins: 30 + level * 25, xp: Int(xpBase * 0.18))
        case .tame:
            return Quest(type: .tame, target: 1, coins: 100 + level * 40, xp: Int(xpBase * 0.25))
        case .treasure:
            let target = level >= 15 ? 2 : 1
            return Quest(type: .treasure, target: target, coins: 60 + level * 30, xp: Int(xpBase * 0.2))
        }
    }
}

/// Постоянные достижения с наградами. Прогресс считается по статистике сохранения.
struct Achievement: Identifiable {
    enum Metric {
        case gathered(ResourceKind)
        case category(ResourceCategory)
        case harvests
        case coinsEarned
        case animals
        case stars
        case locations
        case level
        case minTool
        case talents
        case quests
        case treasures
        case floors
        case kills
    }

    let id: String
    let family: String
    let icon: String
    let metric: Metric
    let target: Int
    let coins: Int
    let talentPoints: Int

    var title: String { tr("ach.\(id)") }
    var detail: String { tr("ach.\(family).detail", Fmt.n(target)) }

    static let all: [Achievement] = {
        var list: [Achievement] = []
        func family(_ key: String, _ icon: String, _ metric: Metric, _ targets: [Int], _ coins: [Int], points: [Int]) {
            for (i, target) in targets.enumerated() {
                list.append(Achievement(
                    id: "\(key)_\(i + 1)", family: key, icon: icon, metric: metric, target: target,
                    coins: coins[min(i, coins.count - 1)], talentPoints: points[min(i, points.count - 1)]
                ))
            }
        }
        family("wood", "🪓", .gathered(.wood), [200, 2_000, 20_000, 100_000],
               [100, 1_000, 8_000, 30_000], points: [0, 0, 1, 1])
        family("stone", "🪨", .gathered(.stone), [200, 2_000, 20_000],
               [100, 1_000, 8_000], points: [0, 0, 1])
        family("ore", "⛏️", .category(.ore), [100, 1_500, 15_000],
               [300, 3_000, 20_000], points: [0, 1, 1])
        family("gem", "💎", .category(.gem), [20, 300, 3_000],
               [1_000, 10_000, 60_000], points: [0, 1, 1])
        family("fish", "🎣", .gathered(.fish), [50, 800, 8_000],
               [200, 3_000, 20_000], points: [0, 0, 1])
        family("food", "🍎", .category(.food), [300, 3_000, 30_000],
               [150, 2_000, 15_000], points: [0, 0, 1])
        family("farm", "🥚", .category(.farm), [50, 600, 6_000],
               [300, 3_000, 20_000], points: [0, 0, 1])
        family("treasure", "🐚", .category(.treasure), [100, 2_000],
               [5_000, 50_000], points: [0, 1])
        family("harvest", "💪", .harvests, [500, 5_000, 25_000, 100_000],
               [200, 2_000, 10_000, 40_000], points: [0, 1, 1, 1])
        family("coins", "💰", .coinsEarned, [2_000, 100_000, 2_000_000],
               [200, 5_000, 50_000], points: [0, 1, 1])
        family("animals", "🐾", .animals, [3, 8, AnimalID.allCases.filter { !$0.spec.isPremium }.count],
               [300, 5_000, 50_000], points: [0, 1, 2])
        family("stars", "⭐", .stars, [10, 50, 120],
               [500, 5_000, 30_000], points: [0, 1, 1])
        family("locations", "🗺️", .locations, [3, 6, LocationID.world.count],
               [500, 5_000, 50_000], points: [0, 1, 2])
        family("level", "🎖️", .level, [10, 25, 40, 60],
               [500, 4_000, 20_000, 100_000], points: [1, 1, 1, 2])
        family("tools", "🛠️", .minTool, [3, 6, 8],
               [500, 8_000, 60_000], points: [0, 1, 2])
        family("talents", "🌟", .talents, [10, 35, 70],
               [300, 4_000, 30_000], points: [0, 1, 1])
        family("quests", "📜", .quests, [10, 60, 250],
               [500, 5_000, 40_000], points: [0, 1, 1])
        family("chests", "🎁", .treasures, [10, 100],
               [500, 10_000], points: [0, 1])
        family("crops", "🌾", .category(.crop), [50, 600, 6_000],
               [300, 3_000, 20_000], points: [0, 1, 1])
        family("house", "🏠", .floors, [2, 4],
               [1_000, 10_000], points: [1, 1])
        family("kills", "⚔️", .kills, [20, 200, 2_000],
               [300, 4_000, 30_000], points: [0, 1, 1])
        return list
    }()
}
