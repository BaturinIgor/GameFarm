import Foundation

/// Этажи дома. Первый есть сразу, остальные строятся за уровень, монеты и ресурсы.
/// На каждом этаже две комнаты, по которым ходит герой.
enum HouseFloor: String, CaseIterable, Identifiable, Codable {
    case greenhouse, attic, upper, ground, basement

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
        case .greenhouse: 30
        }
    }

    var cost: Cost {
        switch self {
        case .ground: Cost()
        case .upper: Cost(coins: 1500, (.wood, 60), (.stone, 40))
        case .basement: Cost(coins: 4000, (.stone, 120), (.iron, 30))
        case .attic: Cost(coins: 10000, (.wood, 200), (.gold, 15))
        case .greenhouse: Cost(coins: 25000, (.ice, 60), (.crystal, 10), (.pumpkin, 10))
        }
    }

    /// Локация этажа, по которой ходит герой.
    var location: LocationID {
        switch self {
        case .ground: .homeGround
        case .upper: .homeUpper
        case .basement: .homeBasement
        case .attic: .homeAttic
        case .greenhouse: .homeGreenhouse
        }
    }

    /// Куда ведут лестницы.
    var up: HouseFloor? {
        switch self {
        case .basement: .ground
        case .ground: .upper
        case .upper: .attic
        case .attic: .greenhouse
        case .greenhouse: nil
        }
    }

    var down: HouseFloor? {
        switch self {
        case .ground: .basement
        case .upper: .ground
        case .attic: .upper
        case .greenhouse: .attic
        case .basement: nil
        }
    }

    /// Места для украшений на этаже: по три в каждой комнате.
    var slots: [String] { (0..<6).map { "\(rawValue)_\($0)" } }
}

/// Что стоит в доме и с чем можно взаимодействовать.
enum HomeStation: String {
    case exit, up, down, trophies, plan, stove, calendar
    case bed, wardrobe, desk, lectern
    case pantry, workbench, anvil
    case telescope, chest, map
    case compost, seedlings

    /// Переход между этажами или выход: срабатывает, когда герой подходит вплотную.
    var isPassage: Bool { self == .exit || self == .up || self == .down }

    var title: String { tr("home.\(rawValue)") }
    var hint: String { tr("home.\(rawValue).hint") }

    /// Пиксельная иконка для карточки (ic_<имя>).
    var icon: String {
        switch self {
        case .exit: "door"
        case .up, .down: "stairs"
        case .trophies: "trophy"
        case .plan: "plan"
        case .stove: "stove"
        case .calendar: "calendar"
        case .bed: "bed"
        case .wardrobe: "wardrobe"
        case .desk: "book"
        case .lectern: "spark"
        case .pantry: "chest"
        case .workbench, .anvil: "hammer"
        case .telescope: "telescope"
        case .chest: "ticket"
        case .map: "map"
        case .compost: "compost"
        case .seedlings: "seed_wheat"
        }
    }
}

/// Что показывает карточка внизу экрана в доме.
enum HomePrompt: Equatable {
    case station(HomeStation)
    /// Лестница на ещё не построенный этаж.
    case build(HouseFloor)
    /// Место для украшения.
    case slot(String)
}

/// Трофеи на стене гостиной: появляются за достижения.
enum Trophy: String, CaseIterable, Identifiable {
    case wolf, bear, shield, sword, star, cup

    var id: String { rawValue }
    var name: String { tr("trophy.\(rawValue)") }

    var sprite: String {
        switch self {
        case .wolf: "hm_wolf"
        case .bear: "hm_bear"
        case .shield: "hm_shield"
        case .sword: "hm_sword"
        case .star: "hm_star"
        case .cup: "hm_cup"
        }
    }

    /// Сколько нужно и для чего (текст условия).
    var target: Int {
        switch self {
        case .wolf: 50
        case .bear: 300
        case .shield: 15
        case .sword: 4
        case .star: 1
        case .cup: 1
        }
    }

    var condition: String { tr("trophy.\(rawValue).how", target) }
}

/// Кухня прокачивается: больше плит, готовка быстрее, больше блюд сразу.
enum Kitchen {
    static let maxLevel = 5

    static func slots(_ level: Int) -> Int { max(1, min(maxLevel, level)) }

    /// Множитель времени готовки.
    static func speed(_ level: Int) -> Double { 1 - 0.08 * Double(max(1, level) - 1) }

    static func mealSlots(_ level: Int) -> Int { 3 + (level >= 3 ? 1 : 0) + (level >= 5 ? 1 : 0) }

    static func requiredLevel(_ next: Int) -> Int {
        switch next {
        case 2: 6
        case 3: 14
        case 4: 24
        default: 34
        }
    }

    static func cost(_ next: Int) -> Cost {
        switch next {
        case 2: Cost(coins: 800, (.wood, 80), (.stone, 40))
        case 3: Cost(coins: 3000, (.iron, 40), (.clay, 30))
        case 4: Cost(coins: 9000, (.gold, 30), (.ice, 30))
        default: Cost(coins: 25000, (.diamond, 10), (.crystal, 10))
        }
    }
}

/// Украшения для дома: дают уют, а уют прибавляет добычу и опыт.
enum DecorID: String, CaseIterable, Identifiable, Codable {
    case potGreen, potRed, potBlue, lantern, clock, painting, stool, table, bench, rug, bookshelf, barrel, anvil, hay
    case plantPink, plantFern, plantLush, redStool, roundTable, greenRug, sofa, displayCase, cupboard, bathtub
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
        case .plantPink: "hm_plant_pink"
        case .plantFern: "hm_plant_fern"
        case .plantLush: "hm_plant_big"
        case .redStool: "hm_stool_red"
        case .roundTable: "hm_table_round"
        case .greenRug: "hm_rug_green"
        case .sofa: "hm_sofa"
        case .displayCase: "hm_display"
        case .cupboard: "hm_cupboard"
        case .bathtub: "hm_bath"
        default: rawValue
        }
    }

    /// Ивент, за который выдаётся украшение (его нельзя купить).
    var event: EventID? { EventID.allCases.first { $0.decor == self } }

    var comfort: Int {
        switch self {
        case .potGreen, .potRed, .potBlue, .stool, .hay, .redStool: 1
        case .lantern, .clock, .barrel, .table, .plantPink, .plantFern: 2
        case .painting, .bench, .anvil, .plantLush, .roundTable: 3
        case .rug, .bookshelf, .greenRug, .cupboard: 4
        case .sofa, .displayCase: 6
        case .bathtub: 8
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
        case .redStool: Cost(coins: 150, (.wood, 10))
        case .plantPink: Cost(coins: 400, (.berries, 20), (.clay, 4))
        case .plantFern: Cost(coins: 450, (.herbs, 10), (.clay, 4))
        case .plantLush: Cost(coins: 1100, (.herbs, 20), (.clay, 10))
        case .roundTable: Cost(coins: 1200, (.wood, 80))
        case .greenRug: Cost(coins: 2800, (.wool, 20), (.herbs, 10))
        case .cupboard: Cost(coins: 3500, (.wood, 150), (.iron, 10))
        case .sofa: Cost(coins: 6000, (.wool, 40), (.wood, 100))
        case .displayCase: Cost(coins: 9000, (.ice, 30), (.gold, 10))
        case .bathtub: Cost(coins: 15000, (.iron, 80), (.pearl, 3))
        case .jackLantern, .slimeLamp, .snowman, .sandcastle: Cost()
        }
    }
}

enum Comfort {
    /// Уют: +1% к добыче и опыту за очко, не больше 30%.
    static func bonus(_ points: Int) -> Double { min(0.3, Double(points) * 0.01) }
}

// MARK: Кухня

/// Блюдо, которое сейчас действует.
struct ActiveMeal: Identifiable {
    let dish: DishID
    let until: Date
    var id: DishID { dish }
}

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
