import Foundation

/// Этажи дома. Первый есть сразу, остальные строятся за уровень, монеты и ресурсы.
enum HouseFloor: String, CaseIterable, Identifiable, Codable {
    case attic, upper, ground, basement

    var id: String { rawValue }

    var title: String { tr("house.floor.\(rawValue)") }
    var room: String { tr("house.room.\(rawValue)") }
    var perk: String { tr("house.perk.\(rawValue)") }

    var level: Int {
        switch self {
        case .ground: 1
        case .upper: 8
        case .basement: 14
        case .attic: 22
        }
    }

    var cost: Cost {
        switch self {
        case .ground: Cost()
        case .upper: Cost(coins: 1500, (.wood, 60), (.stone, 40))
        case .basement: Cost(coins: 4000, (.stone, 120), (.iron, 30))
        case .attic: Cost(coins: 10000, (.wood, 200), (.gold, 15))
        }
    }

    /// Места для украшений на этаже.
    var slots: [String] { (0..<3).map { "\(rawValue)_\($0)" } }
}

/// Украшения для дома: дают уют, а уют прибавляет добычу и опыт.
enum DecorID: String, CaseIterable, Identifiable, Codable {
    case potGreen, potRed, potBlue, lantern, clock, painting, stool, table, bench, rug, bookshelf, barrel, anvil, hay
    // Награды ивентов
    case jackLantern, slimeLamp, snowman, sandcastle

    var id: String { rawValue }

    var name: String { tr("decor.\(rawValue)") }

    var sprite: String {
        switch self {
        case .potGreen: "pot_green"
        case .potRed: "pot_red"
        case .potBlue: "pot_blue"
        case .table: "table_small"
        case .barrel: "barrel_berries"
        case .hay: "hay_big"
        case .jackLantern: "jack_lantern"
        case .slimeLamp: "slime_lamp"
        default: rawValue
        }
    }

    /// Ивент, за который выдаётся украшение (его нельзя купить).
    var event: EventID? { EventID.allCases.first { $0.decor == self } }

    var comfort: Int {
        switch self {
        case .potGreen, .potRed, .potBlue, .stool, .hay: 1
        case .lantern, .clock, .barrel, .table: 2
        case .painting, .bench, .anvil: 3
        case .rug, .bookshelf: 4
        case .jackLantern, .slimeLamp, .snowman, .sandcastle: 5
        }
    }

    var cost: Cost {
        switch self {
        case .potGreen: Cost(coins: 120, (.berries, 10))
        case .potRed: Cost(coins: 150, (.berries, 15))
        case .potBlue: Cost(coins: 180, (.berries, 20))
        case .stool: Cost(coins: 100, (.wood, 15))
        case .hay: Cost(coins: 120, (.wheat, 10))
        case .lantern: Cost(coins: 400, (.iron, 5))
        case .clock: Cost(coins: 500, (.wood, 20), (.iron, 4))
        case .barrel: Cost(coins: 350, (.wood, 30))
        case .table: Cost(coins: 450, (.wood, 40))
        case .painting: Cost(coins: 1200, (.wood, 20), (.gold, 2))
        case .bench: Cost(coins: 1000, (.wood, 60))
        case .anvil: Cost(coins: 1500, (.iron, 20))
        case .rug: Cost(coins: 2500, (.wool, 15))
        case .bookshelf: Cost(coins: 3000, (.wood, 120))
        case .jackLantern, .slimeLamp, .snowman, .sandcastle: Cost()
        }
    }
}

enum Comfort {
    /// Уют: +1% к добыче и опыту за очко, не больше 30%.
    static func bonus(_ points: Int) -> Double { min(0.3, Double(points) * 0.01) }
}

// MARK: Кухня

/// Что даёт блюдо, пока действует.
struct MealBuff {
    var yield = 0.0
    var xp = 0.0
    var speed = 0.0
    var sell = 0.0
    var crit = 0.0
    var animals = 0.0
}

enum DishID: String, CaseIterable, Identifiable, Codable {
    case bread, omelette, salad, soup, pancakes, pie, pumpkinSoup, popcorn, stew, juice

    var id: String { rawValue }

    var name: String { tr("dish.\(rawValue)") }
    var icon: String { "dish_\(rawValue)" }

    var emoji: String {
        switch self {
        case .bread: "🍞"
        case .omelette: "🍳"
        case .salad: "🥗"
        case .soup: "🍲"
        case .pancakes: "🥞"
        case .pie: "🥧"
        case .pumpkinSoup: "🎃"
        case .popcorn: "🍿"
        case .stew: "🌶️"
        case .juice: "🧃"
        }
    }

    var ingredients: [ResourceAmount] {
        func r(_ k: ResourceKind, _ n: Int) -> ResourceAmount { ResourceAmount(kind: k, amount: n) }
        switch self {
        case .bread: return [r(.wheat, 3)]
        case .omelette: return [r(.egg, 2), r(.milk, 1)]
        case .salad: return [r(.tomato, 2), r(.cabbage, 1)]
        case .soup: return [r(.carrots, 3), r(.potato, 2)]
        case .pancakes: return [r(.wheat, 2), r(.egg, 1), r(.milk, 1), r(.honey, 1)]
        case .pie: return [r(.strawberry, 3), r(.wheat, 2), r(.egg, 1)]
        case .pumpkinSoup: return [r(.pumpkin, 1), r(.milk, 2)]
        case .popcorn: return [r(.corn, 3)]
        case .stew: return [r(.chili, 2), r(.eggplant, 2), r(.potato, 2)]
        case .juice: return [r(.grapes, 3)]
        }
    }

    /// Время готовки в секундах.
    var cookTime: Double {
        switch self {
        case .bread, .omelette: 20
        case .salad: 30
        case .soup, .pancakes: 40
        case .popcorn: 45
        case .pie, .pumpkinSoup, .juice: 60
        case .stew: 75
        }
    }

    /// Сколько действует, в секундах.
    var duration: Double {
        switch self {
        case .bread, .omelette, .salad: 600
        case .soup, .pancakes, .pie, .popcorn: 900
        case .pumpkinSoup, .stew, .juice: 1200
        }
    }

    var buff: MealBuff {
        var b = MealBuff()
        switch self {
        case .bread: b.xp = 0.15
        case .omelette: b.speed = 0.15
        case .salad: b.yield = 0.15
        case .soup: b.yield = 0.2
        case .pancakes: b.xp = 0.25
        case .pie: b.sell = 0.2
        case .pumpkinSoup: b.yield = 0.3
        case .popcorn: b.crit = 0.1
        case .stew: b.animals = 0.25
        case .juice:
            b.yield = 0.15
            b.xp = 0.15
        }
        return b
    }

    /// Описание эффекта для списка рецептов.
    var effectText: String {
        let b = buff
        var parts: [String] = []
        if b.yield > 0 { parts.append(tr("meal.yield", Fmt.pct(b.yield))) }
        if b.xp > 0 { parts.append(tr("meal.xp", Fmt.pct(b.xp))) }
        if b.speed > 0 { parts.append(tr("meal.speed", Fmt.pct(b.speed))) }
        if b.sell > 0 { parts.append(tr("meal.sell", Fmt.pct(b.sell))) }
        if b.crit > 0 { parts.append(tr("meal.crit", Fmt.pct(b.crit))) }
        if b.animals > 0 { parts.append(tr("meal.animals", Fmt.pct(b.animals))) }
        return parts.joined(separator: ", ")
    }
}

/// Блюдо на плите.
struct CookJob: Codable, Equatable, Identifiable {
    var id = UUID()
    let dish: DishID
    let readyAt: Date
}

// MARK: Календарь наград за вход

enum LoginCalendar {
    static let days = 7

    enum Reward: Equatable {
        case coins(Int)
        case seeds(CropID, Int)
        case tickets(Int)
        case coinsAndWood(Int, Int)
        case dish(DishID)
        case resource(ResourceKind, Int)
        case chest(tickets: Int, coins: Int)
    }

    /// Награда за заход номер claim (с нуля). Неделя повторяется, а монет становится больше с уровнем.
    static func reward(claim: Int, level: Int) -> Reward {
        let m = 1 + Double(level) / 10
        func coins(_ base: Double) -> Int { Int((base * m).rounded()) }
        let best = CropID.allCases.last { $0.spec.level <= level } ?? .wheat
        let dishes: [DishID] = [.bread, .omelette, .salad, .soup]
        switch claim % days {
        case 0: return .coins(coins(150))
        case 1: return .seeds(best, 4)
        case 2: return .tickets(1)
        case 3: return .coinsAndWood(coins(400), 30)
        case 4: return .dish(dishes[(claim / days) % dishes.count])
        case 5: return .resource(level >= 12 ? .iron : .stone, 20)
        default: return .chest(tickets: 2, coins: coins(800))
        }
    }
}
