import Foundation

enum AnimalID: String, CaseIterable, Identifiable {
    // Лавка
    case chicken, cow, horse, sheep, bee, rooster, pig, unicorn
    // Дикие
    case mouse, goose, duck, frog, butterfly, swan, goldenGoose
    // Из стартового набора
    case duckHat

    var id: String { rawValue }
    var spec: AnimalSpec { AnimalSpec.table[self]! }

    /// Старые звери из прошлых версий: во что они превращаются в сохранении.
    static let migration: [String: AnimalID] = [
        "dog": .mouse, "cat": .butterfly, "hamster": .horse, "turkey": .chicken, "owl": .rooster, "llama": .sheep,
        "panda": .pig, "rabbit": .mouse, "squirrel": .mouse, "goat": .goose, "hedgehog": .goose, "beaver": .goose,
        "otter": .duck, "turtle": .swan, "crocodile": .pig, "camel": .horse, "lizard": .butterfly, "penguin": .duck,
        "fox": .swan, "polarBear": .pig, "bat": .butterfly, "dragon": .unicorn, "parrot": .butterfly, "monkey": .pig,
        "crab": .duck, "phoenix": .goldenGoose, "lavasaur": .unicorn, "eagle": .swan, "dove": .goldenGoose, "lion": .duckHat
    ]

    static func from(_ raw: String) -> AnimalID? {
        AnimalID(rawValue: raw) ?? migration[raw]
    }
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
            AnimalSpec(id: .chicken, emoji: "🐔",
                       effects: [.produce(.egg, 25)],
                       source: .shop(price: 200, level: 2)),
            AnimalSpec(id: .cow, emoji: "🐄",
                       effects: [.produce(.milk, 35)],
                       source: .shop(price: 700, level: 5)),
            AnimalSpec(id: .horse, emoji: "🐎",
                       effects: [.speed(0.12), .backpack(20)],
                       source: .shop(price: 1200, level: 8)),
            AnimalSpec(id: .sheep, emoji: "🐑",
                       effects: [.produce(.wool, 40)],
                       source: .shop(price: 1600, level: 11)),
            AnimalSpec(id: .bee, emoji: "🐝",
                       effects: [.produce(.honey, 45), .yield(.food, 0.1)],
                       source: .shop(price: 2500, level: 14)),
            AnimalSpec(id: .rooster, emoji: "🐓",
                       effects: [.helper(HelperSpec(damage: 4, interval: 1.0, tools: [.hand, .axe, .pickaxe], maxTier: 4)), .xp(0.1)],
                       source: .shop(price: 5000, level: 18)),
            AnimalSpec(id: .pig, emoji: "🐖",
                       effects: [.helper(HelperSpec(damage: 12, interval: 1.2, tools: [.hand, .axe, .pickaxe], maxTier: 6)),
                                 .yield(.food, 0.15)],
                       source: .shop(price: 15000, level: 26)),
            AnimalSpec(id: .unicorn, emoji: "🦄",
                       effects: [.helper(HelperSpec(damage: 28, interval: 1.0, tools: [.hand, .axe, .pickaxe, .rod], maxTier: 8)),
                                 .yield(nil, 0.12), .xp(0.15)],
                       source: .shop(price: 60000, level: 40)),

            AnimalSpec(id: .mouse, emoji: "🐁",
                       effects: [.helper(HelperSpec(damage: 1, interval: 1.1, tools: [.hand, .axe], maxTier: 2)), .yield(.food, 0.05)],
                       source: .wild(.meadow, Cost(coins: 0, (.berries, 20), (.apples, 10)), weight: 1)),
            AnimalSpec(id: .goose, emoji: "🪿",
                       effects: [.helper(HelperSpec(damage: 2.5, interval: 1.1, tools: [.hand, .pickaxe], maxTier: 3)), .crit(0.02)],
                       source: .wild(.hills, Cost(coins: 0, (.carrots, 25), (.berries, 20)), weight: 1)),
            AnimalSpec(id: .duck, emoji: "🦆",
                       effects: [.helper(HelperSpec(damage: 3.5, interval: 1.1, tools: [.rod, .hand], maxTier: 4)), .produce(.feather, 40)],
                       source: .wild(.lake, Cost(coins: 0, (.fish, 25), (.carrots, 20)), weight: 1)),
            AnimalSpec(id: .frog, emoji: "🐸",
                       effects: [.respawn(0.12), .yield(.food, 0.12)],
                       source: .wild(.swamp, Cost(coins: 0, (.herbs, 30), (.mushrooms, 30)), weight: 1)),
            AnimalSpec(id: .butterfly, emoji: "🦋",
                       effects: [.xp(0.2), .sell(0.06)],
                       source: .wild(.desert, Cost(coins: 0, (.cactus, 30), (.coconut, 20)), weight: 1)),
            AnimalSpec(id: .swan, emoji: "🦢",
                       effects: [.crit(0.05), .backpack(40)],
                       source: .wild(.snow, Cost(coins: 0, (.fish, 80), (.ice, 30)), weight: 1)),
            AnimalSpec(id: .goldenGoose, emoji: "🪿",
                       effects: [.produce(.gold, 40), .yield(.gem, 0.12)],
                       source: .wild(.caves, Cost(coins: 0, (.crystal, 10), (.diamond, 10), (.coconut, 50)), weight: 0.4)),

            AnimalSpec(id: .duckHat, emoji: "🦆", effects: [.yield(nil, 0.08), .xp(0.1), .sell(0.1)], source: .premium)
        ]
        var dict: [AnimalID: AnimalSpec] = [:]
        for spec in list { dict[spec.id] = spec }
        return dict
    }()
}
