import Foundation

enum AnimalID: String, CaseIterable, Identifiable {
    // Лавка
    case dog, chicken, cat, hamster, cow, horse, sheep, turkey, bee, owl, llama, pig, panda, unicorn
    // Дикие
    case rabbit, squirrel, goat, hedgehog, duck, beaver, otter, frog, turtle, crocodile, camel, lizard
    case penguin, fox, polarBear, bat, dragon, parrot, monkey, crab, phoenix, lavasaur, eagle, swan, dove
    // Из стартового набора
    case lion

    var id: String { rawValue }
    var spec: AnimalSpec { AnimalSpec.table[self]! }
}

struct HelperSpec {
    let damage: Double
    let interval: Double
    let tools: Set<ToolKind>
    let maxTier: Int
}

enum AnimalEffect {
    case xp(Double)
    case yield(ResourceCategory?, Double)
    case yieldKind(ResourceKind, Double)
    case speed(Double)
    case respawn(Double)
    case crit(Double)
    case backpack(Int)
    case sell(Double)
    /// Приносит 1 ресурс раз в указанное число секунд.
    case produce(ResourceKind, Double)
    /// Ходит рядом и сам добывает ресурсы.
    case helper(HelperSpec)

    func text(multiplier m: Double) -> String {
        switch self {
        case .xp(let v):
            return tr("effect.xp", Fmt.pct(v * m))
        case .yield(let category, let v):
            if let category { return tr("effect.yield.\(category.rawValue)", Fmt.pct(v * m)) }
            return tr("effect.yield.all", Fmt.pct(v * m))
        case .yieldKind(let kind, let v):
            return tr("effect.yieldKind", Fmt.pct(v * m), kind.name)
        case .speed(let v):
            return tr("effect.speed", Fmt.pct(v * m))
        case .respawn(let v):
            return tr("effect.respawn", Fmt.pct(v * m))
        case .crit(let v):
            return tr("effect.crit", Fmt.pct(v * m))
        case .backpack(let v):
            return tr("effect.backpack", Int(Double(v) * m))
        case .sell(let v):
            return tr("effect.sell", Fmt.pct(v * m))
        case .produce(let kind, let interval):
            return tr("effect.produce", kind.emoji ?? "", kind.name, Fmt.seconds(interval / m))
        case .helper(let h):
            let tools = ToolKind.allCases.filter { h.tools.contains($0) }.map(\.emoji).joined(separator: " ")
            return tr("effect.helper", tools, h.maxTier, Fmt.decimal(h.damage * m, digits: 1))
        }
    }
}

enum AnimalSource {
    case shop(price: Int, level: Int)
    case wild(LocationID, Cost, weight: Double)
    /// Только из платного набора.
    case premium
}

struct AnimalSpec {
    let id: AnimalID
    let emoji: String
    let effects: [AnimalEffect]
    let source: AnimalSource

    static let maxStars = 5

    var name: String { tr("animal.\(id.rawValue)") }

    /// Множитель силы зверя от звёзд. step - прибавка за каждую звезду после первой.
    static func starMultiplier(_ stars: Int, step: Double = 0.25) -> Double {
        1 + step * Double(max(1, stars) - 1)
    }

    var isHelper: Bool {
        effects.contains { if case .helper = $0 { return true } else { return false } }
    }

    var isProducer: Bool {
        effects.contains { if case .produce = $0 { return true } else { return false } }
    }

    var role: String {
        if isHelper { return tr("role.helper") }
        if isProducer { return tr("role.producer") }
        return tr("role.bonus")
    }

    var isPremium: Bool {
        if case .premium = source { return true }
        return false
    }

    var shopLevel: Int? {
        if case .shop(_, let level) = source { return level }
        return nil
    }

    var wildLocation: LocationID? {
        if case .wild(let location, _, _) = source { return location }
        return nil
    }

    static let table: [AnimalID: AnimalSpec] = {
        let list: [AnimalSpec] = [
            AnimalSpec(id: .dog, emoji: "🐕",
                       effects: [.helper(HelperSpec(damage: 1, interval: 1.1, tools: [.hand, .axe], maxTier: 2))],
                       source: .shop(price: 120, level: 2)),
            AnimalSpec(id: .chicken, emoji: "🐔",
                       effects: [.produce(.egg, 25)],
                       source: .shop(price: 200, level: 3)),
            AnimalSpec(id: .cat, emoji: "🐈",
                       effects: [.crit(0.06), .xp(0.05)],
                       source: .shop(price: 400, level: 5)),
            AnimalSpec(id: .hamster, emoji: "🐹",
                       effects: [.backpack(25)],
                       source: .shop(price: 900, level: 8)),
            AnimalSpec(id: .cow, emoji: "🐄",
                       effects: [.produce(.milk, 35)],
                       source: .shop(price: 700, level: 7)),
            AnimalSpec(id: .horse, emoji: "🐎",
                       effects: [.speed(0.2)],
                       source: .shop(price: 1200, level: 10)),
            AnimalSpec(id: .sheep, emoji: "🐑",
                       effects: [.produce(.wool, 40)],
                       source: .shop(price: 1600, level: 12)),
            AnimalSpec(id: .turkey, emoji: "🦃",
                       effects: [.produce(.feather, 25), .yield(.farm, 0.1)],
                       source: .shop(price: 2200, level: 14)),
            AnimalSpec(id: .bee, emoji: "🐝",
                       effects: [.produce(.honey, 45), .yield(.food, 0.1)],
                       source: .shop(price: 2500, level: 15)),
            AnimalSpec(id: .owl, emoji: "🦉",
                       effects: [.xp(0.2)],
                       source: .shop(price: 4000, level: 18)),
            AnimalSpec(id: .llama, emoji: "🦙",
                       effects: [.produce(.wool, 30), .backpack(30)],
                       source: .shop(price: 9000, level: 20)),
            AnimalSpec(id: .pig, emoji: "🐖",
                       effects: [.yield(.food, 0.25), .sell(0.1)],
                       source: .shop(price: 7000, level: 24)),
            AnimalSpec(id: .panda, emoji: "🐼",
                       effects: [.helper(HelperSpec(damage: 6, interval: 1.2, tools: [.hand, .axe], maxTier: 6)), .yieldKind(.bamboo, 0.6)],
                       source: .shop(price: 15000, level: 26)),
            AnimalSpec(id: .unicorn, emoji: "🦄",
                       effects: [.yield(nil, 0.15), .xp(0.15), .speed(0.1)],
                       source: .shop(price: 40000, level: 35)),

            AnimalSpec(id: .rabbit, emoji: "🐇",
                       effects: [.yield(.food, 0.2), .speed(0.05)],
                       source: .wild(.meadow, Cost(coins: 0, (.berries, 20), (.apples, 10)), weight: 1)),
            AnimalSpec(id: .squirrel, emoji: "🐿️",
                       effects: [.yield(.wood, 0.15)],
                       source: .wild(.meadow, Cost(coins: 0, (.berries, 15), (.mushrooms, 10)), weight: 1)),
            AnimalSpec(id: .goat, emoji: "🐐",
                       effects: [.yield(.stone, 0.15), .yield(.ore, 0.1)],
                       source: .wild(.hills, Cost(coins: 0, (.carrots, 25), (.berries, 20)), weight: 1)),
            AnimalSpec(id: .hedgehog, emoji: "🦔",
                       effects: [.helper(HelperSpec(damage: 1.5, interval: 1.2, tools: [.hand, .pickaxe], maxTier: 2))],
                       source: .wild(.hills, Cost(coins: 0, (.mushrooms, 25), (.apples, 20)), weight: 1)),
            AnimalSpec(id: .duck, emoji: "🦆",
                       effects: [.produce(.feather, 30), .yieldKind(.fish, 0.1)],
                       source: .wild(.lake, Cost(coins: 0, (.berries, 30), (.carrots, 20)), weight: 1)),
            AnimalSpec(id: .beaver, emoji: "🦫",
                       effects: [.helper(HelperSpec(damage: 3, interval: 1.0, tools: [.axe], maxTier: 4))],
                       source: .wild(.lake, Cost(coins: 0, (.apples, 30), (.carrots, 20)), weight: 1)),
            AnimalSpec(id: .otter, emoji: "🦦",
                       effects: [.yieldKind(.fish, 0.4), .respawn(0.05)],
                       source: .wild(.lake, Cost(coins: 0, (.fish, 25)), weight: 1)),
            AnimalSpec(id: .frog, emoji: "🐸",
                       effects: [.respawn(0.1), .yield(.food, 0.1)],
                       source: .wild(.swamp, Cost(coins: 0, (.herbs, 30), (.mushrooms, 30)), weight: 1)),
            AnimalSpec(id: .turtle, emoji: "🐢",
                       effects: [.backpack(50), .crit(0.04)],
                       source: .wild(.swamp, Cost(coins: 0, (.fish, 40), (.herbs, 20)), weight: 1)),
            AnimalSpec(id: .crocodile, emoji: "🐊",
                       effects: [.helper(HelperSpec(damage: 10, interval: 1.4, tools: [.axe, .pickaxe, .rod], maxTier: 5))],
                       source: .wild(.swamp, Cost(coins: 0, (.fish, 120), (.clay, 40)), weight: 0.5)),
            AnimalSpec(id: .camel, emoji: "🐪",
                       effects: [.backpack(40), .speed(0.05)],
                       source: .wild(.desert, Cost(coins: 0, (.cactus, 30), (.coconut, 20)), weight: 1)),
            AnimalSpec(id: .lizard, emoji: "🦎",
                       effects: [.respawn(0.12)],
                       source: .wild(.desert, Cost(coins: 0, (.berries, 50), (.cactus, 20)), weight: 1)),
            AnimalSpec(id: .penguin, emoji: "🐧",
                       effects: [.helper(HelperSpec(damage: 4, interval: 1.1, tools: [.rod, .hand], maxTier: 3))],
                       source: .wild(.snow, Cost(coins: 0, (.fish, 60)), weight: 1)),
            AnimalSpec(id: .fox, emoji: "🦊",
                       effects: [.crit(0.1), .sell(0.05)],
                       source: .wild(.snow, Cost(coins: 0, (.carrots, 60), (.egg, 20)), weight: 1)),
            AnimalSpec(id: .polarBear, emoji: "🐻‍❄️",
                       effects: [.helper(HelperSpec(damage: 8, interval: 1.3, tools: [.axe, .pickaxe], maxTier: 5))],
                       source: .wild(.snow, Cost(coins: 0, (.fish, 80), (.honey, 30)), weight: 0.7)),
            AnimalSpec(id: .bat, emoji: "🦇",
                       effects: [.xp(0.25)],
                       source: .wild(.caves, Cost(coins: 0, (.mushrooms, 100), (.berries, 60)), weight: 1)),
            AnimalSpec(id: .dragon, emoji: "🐉",
                       effects: [.helper(HelperSpec(damage: 15, interval: 1.0, tools: [.hand, .axe, .pickaxe, .rod], maxTier: 6)),
                                 .yield(.gem, 0.15)],
                       source: .wild(.caves, Cost(coins: 0, (.crystal, 10), (.diamond, 10), (.coconut, 50)), weight: 0.2))
        ]
        let late: [AnimalSpec] = [
            AnimalSpec(id: .parrot, emoji: "🦜",
                       effects: [.sell(0.12), .xp(0.08)],
                       source: .wild(.island, Cost(coins: 0, (.banana, 30), (.pineapple, 20)), weight: 1)),
            AnimalSpec(id: .monkey, emoji: "🐒",
                       effects: [.helper(HelperSpec(damage: 9, interval: 0.9, tools: [.hand, .axe], maxTier: 7))],
                       source: .wild(.island, Cost(coins: 0, (.banana, 60)), weight: 1)),
            AnimalSpec(id: .crab, emoji: "🦀",
                       effects: [.helper(HelperSpec(damage: 10, interval: 1.1, tools: [.pickaxe, .rod], maxTier: 7))],
                       source: .wild(.island, Cost(coins: 0, (.shell, 40), (.fish, 100)), weight: 1)),
            AnimalSpec(id: .phoenix, emoji: "🐦‍🔥",
                       effects: [.xp(0.35), .respawn(0.1)],
                       source: .wild(.volcano, Cost(coins: 0, (.ruby, 5), (.sulfur, 60), (.pineapple, 60)), weight: 0.4)),
            AnimalSpec(id: .lavasaur, emoji: "🦖",
                       effects: [.helper(HelperSpec(damage: 30, interval: 1.2, tools: [.hand, .axe, .pickaxe, .rod], maxTier: 8))],
                       source: .wild(.volcano, Cost(coins: 0, (.obsidian, 20), (.coconut, 80), (.banana, 80)), weight: 0.5)),
            AnimalSpec(id: .eagle, emoji: "🦅",
                       effects: [.speed(0.3), .crit(0.05)],
                       source: .wild(.sky, Cost(coins: 0, (.stardust, 5), (.fish, 200)), weight: 1)),
            AnimalSpec(id: .swan, emoji: "🦢",
                       effects: [.produce(.cloud, 45)],
                       source: .wild(.sky, Cost(coins: 0, (.cloud, 20), (.goldenApple, 5)), weight: 1)),
            AnimalSpec(id: .dove, emoji: "🕊️",
                       effects: [.xp(0.2), .yield(nil, 0.08)],
                       source: .wild(.sky, Cost(coins: 0, (.herbs, 100), (.berries, 300)), weight: 1))
        ]
        var dict: [AnimalID: AnimalSpec] = [:]
        for spec in late { dict[spec.id] = spec }
        dict[.lion] = AnimalSpec(id: .lion, emoji: "🦁", effects: [.yield(nil, 0.08), .xp(0.1), .sell(0.1)], source: .premium)
        for spec in list { dict[spec.id] = spec }
        return dict
    }()
}
