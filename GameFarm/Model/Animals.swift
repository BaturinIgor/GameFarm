import Foundation

enum AnimalID: String, CaseIterable, Identifiable {
    // Лавка
    case dog, chicken, cat, cow, horse, sheep, bee, owl, pig, unicorn
    // Дикие
    case rabbit, squirrel, goat, hedgehog, duck, beaver, otter, camel, lizard, penguin, fox, polarBear, bat, dragon

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
            return "+\(Fmt.pct(v * m)) опыта"
        case .yield(let category, let v):
            if let category { return "+\(Fmt.pct(v * m)) к добыче \(category.genitive)" }
            return "+\(Fmt.pct(v * m)) ко всем ресурсам"
        case .yieldKind(let kind, let v):
            return "+\(Fmt.pct(v * m)) к добыче: \(kind.name.lowercased())"
        case .speed(let v):
            return "+\(Fmt.pct(v * m)) к скорости бега"
        case .respawn(let v):
            return "Ресурсы растут быстрее на \(Fmt.pct(v * m))"
        case .crit(let v):
            return "+\(Fmt.pct(v * m)) шанс крита"
        case .backpack(let v):
            return "+\(Int(Double(v) * m)) мест в рюкзаке"
        case .sell(let v):
            return "+\(Fmt.pct(v * m)) к цене продажи"
        case .produce(let kind, let interval):
            let icon = kind.emoji ?? ""
            return "Приносит 1 \(icon) \(kind.name.lowercased()) раз в \(Fmt.seconds(interval / m))"
        case .helper(let h):
            let tools = ToolKind.allCases.filter { h.tools.contains($0) }.map(\.emoji).joined(separator: " ")
            let dmg = String(format: "%.1f", h.damage * m).replacingOccurrences(of: ".", with: ",")
            return "Добывает сам: \(tools) до ур. \(h.maxTier), сила \(dmg)"
        }
    }
}

enum AnimalSource {
    case shop(price: Int, level: Int)
    case wild(LocationID, Cost, weight: Double)
}

struct AnimalSpec {
    let id: AnimalID
    let name: String
    let emoji: String
    let effects: [AnimalEffect]
    let source: AnimalSource

    static let maxStars = 5

    static func starMultiplier(_ stars: Int) -> Double {
        1 + 0.25 * Double(max(1, stars) - 1)
    }

    var isHelper: Bool {
        effects.contains { if case .helper = $0 { return true } else { return false } }
    }

    var isProducer: Bool {
        effects.contains { if case .produce = $0 { return true } else { return false } }
    }

    var role: String {
        if isHelper { return "Помощник" }
        if isProducer { return "Производитель" }
        return "Бонус"
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
            AnimalSpec(id: .dog, name: "Пёс", emoji: "🐕",
                       effects: [.helper(HelperSpec(damage: 1, interval: 1.1, tools: [.hand, .axe], maxTier: 2))],
                       source: .shop(price: 120, level: 2)),
            AnimalSpec(id: .chicken, name: "Курица", emoji: "🐔",
                       effects: [.produce(.egg, 25)],
                       source: .shop(price: 200, level: 3)),
            AnimalSpec(id: .cat, name: "Кот", emoji: "🐈",
                       effects: [.crit(0.06), .xp(0.05)],
                       source: .shop(price: 400, level: 5)),
            AnimalSpec(id: .cow, name: "Корова", emoji: "🐄",
                       effects: [.produce(.milk, 35)],
                       source: .shop(price: 700, level: 7)),
            AnimalSpec(id: .horse, name: "Лошадь", emoji: "🐎",
                       effects: [.speed(0.2)],
                       source: .shop(price: 1200, level: 10)),
            AnimalSpec(id: .sheep, name: "Овца", emoji: "🐑",
                       effects: [.produce(.wool, 40)],
                       source: .shop(price: 1600, level: 12)),
            AnimalSpec(id: .bee, name: "Пчела", emoji: "🐝",
                       effects: [.produce(.honey, 45), .yield(.food, 0.1)],
                       source: .shop(price: 2500, level: 15)),
            AnimalSpec(id: .owl, name: "Сова", emoji: "🦉",
                       effects: [.xp(0.2)],
                       source: .shop(price: 4000, level: 18)),
            AnimalSpec(id: .pig, name: "Свинья", emoji: "🐖",
                       effects: [.yield(.food, 0.25), .sell(0.1)],
                       source: .shop(price: 7000, level: 24)),
            AnimalSpec(id: .unicorn, name: "Единорог", emoji: "🦄",
                       effects: [.yield(nil, 0.15), .xp(0.15), .speed(0.1)],
                       source: .shop(price: 40000, level: 35)),

            AnimalSpec(id: .rabbit, name: "Кролик", emoji: "🐇",
                       effects: [.yield(.food, 0.2), .speed(0.05)],
                       source: .wild(.meadow, Cost(coins: 0, (.berries, 20), (.apples, 10)), weight: 1)),
            AnimalSpec(id: .squirrel, name: "Белка", emoji: "🐿️",
                       effects: [.yield(.wood, 0.15)],
                       source: .wild(.meadow, Cost(coins: 0, (.berries, 15), (.mushrooms, 10)), weight: 1)),
            AnimalSpec(id: .goat, name: "Козёл", emoji: "🐐",
                       effects: [.yield(.stone, 0.15), .yield(.ore, 0.1)],
                       source: .wild(.hills, Cost(coins: 0, (.carrots, 25), (.berries, 20)), weight: 1)),
            AnimalSpec(id: .hedgehog, name: "Ёж", emoji: "🦔",
                       effects: [.helper(HelperSpec(damage: 1.5, interval: 1.2, tools: [.hand, .pickaxe], maxTier: 2))],
                       source: .wild(.hills, Cost(coins: 0, (.mushrooms, 25), (.apples, 20)), weight: 1)),
            AnimalSpec(id: .duck, name: "Утка", emoji: "🦆",
                       effects: [.produce(.feather, 30), .yieldKind(.fish, 0.1)],
                       source: .wild(.lake, Cost(coins: 0, (.berries, 30), (.carrots, 20)), weight: 1)),
            AnimalSpec(id: .beaver, name: "Бобр", emoji: "🦫",
                       effects: [.helper(HelperSpec(damage: 3, interval: 1.0, tools: [.axe], maxTier: 4))],
                       source: .wild(.lake, Cost(coins: 0, (.apples, 30), (.carrots, 20)), weight: 1)),
            AnimalSpec(id: .otter, name: "Выдра", emoji: "🦦",
                       effects: [.yieldKind(.fish, 0.4), .respawn(0.05)],
                       source: .wild(.lake, Cost(coins: 0, (.fish, 25)), weight: 1)),
            AnimalSpec(id: .camel, name: "Верблюд", emoji: "🐪",
                       effects: [.backpack(40), .speed(0.05)],
                       source: .wild(.desert, Cost(coins: 0, (.cactus, 30), (.coconut, 20)), weight: 1)),
            AnimalSpec(id: .lizard, name: "Ящерица", emoji: "🦎",
                       effects: [.respawn(0.12)],
                       source: .wild(.desert, Cost(coins: 0, (.berries, 50), (.cactus, 20)), weight: 1)),
            AnimalSpec(id: .penguin, name: "Пингвин", emoji: "🐧",
                       effects: [.helper(HelperSpec(damage: 4, interval: 1.1, tools: [.rod, .hand], maxTier: 3))],
                       source: .wild(.snow, Cost(coins: 0, (.fish, 60)), weight: 1)),
            AnimalSpec(id: .fox, name: "Песец", emoji: "🦊",
                       effects: [.crit(0.1), .sell(0.05)],
                       source: .wild(.snow, Cost(coins: 0, (.carrots, 60), (.egg, 20)), weight: 1)),
            AnimalSpec(id: .polarBear, name: "Белый медведь", emoji: "🐻‍❄️",
                       effects: [.helper(HelperSpec(damage: 8, interval: 1.3, tools: [.axe, .pickaxe], maxTier: 5))],
                       source: .wild(.snow, Cost(coins: 0, (.fish, 80), (.honey, 30)), weight: 0.7)),
            AnimalSpec(id: .bat, name: "Летучая мышь", emoji: "🦇",
                       effects: [.xp(0.25)],
                       source: .wild(.caves, Cost(coins: 0, (.mushrooms, 100), (.berries, 60)), weight: 1)),
            AnimalSpec(id: .dragon, name: "Дракон", emoji: "🐉",
                       effects: [.helper(HelperSpec(damage: 15, interval: 1.0, tools: [.hand, .axe, .pickaxe, .rod], maxTier: 6)),
                                 .yield(.gem, 0.15)],
                       source: .wild(.caves, Cost(coins: 0, (.crystal, 10), (.diamond, 10), (.coconut, 50)), weight: 0.2))
        ]
        var dict: [AnimalID: AnimalSpec] = [:]
        for spec in list { dict[spec.id] = spec }
        return dict
    }()
}
