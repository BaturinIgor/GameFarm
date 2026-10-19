import UIKit

/// Группа ресурсов: для бонусов талантов и животных и для разделов склада.
enum ResourceCategory: String, CaseIterable, Identifiable {
    case wood, stone, ore, gem, food, farm, treasure

    var id: String { rawValue }

    var title: String { tr("cat.\(rawValue)") }
}

enum ResourceKind: String, CaseIterable, Identifiable {
    case wood, bamboo, stone, clay, coal, iron, gold, sulfur, obsidian, ice, diamond, crystal, ruby
    case berries, apples, mushrooms, carrots, herbs, fish, cactus, coconut, banana, pineapple, goldenApple
    case egg, milk, wool, honey, feather
    case shell, coral, pearl, cloud, stardust

    var id: String { rawValue }

    var name: String { tr("res.\(rawValue)") }

    /// nil - иконка рисуется кодом.
    var emoji: String? {
        switch self {
        case .wood: "🪵"
        case .bamboo: "🎋"
        case .stone: "🪨"
        case .clay: "🧱"
        case .coal, .iron, .gold, .sulfur, .obsidian, .crystal, .ruby, .pearl, .goldenApple: nil
        case .ice: "🧊"
        case .diamond: "💎"
        case .berries: "🫐"
        case .apples: "🍎"
        case .mushrooms: "🍄"
        case .carrots: "🥕"
        case .herbs: "🌿"
        case .fish: "🐟"
        case .cactus: "🌵"
        case .coconut: "🥥"
        case .banana: "🍌"
        case .pineapple: "🍍"
        case .egg: "🥚"
        case .milk: "🥛"
        case .wool: "🧶"
        case .honey: "🍯"
        case .feather: "🪶"
        case .shell: "🐚"
        case .coral: "🪸"
        case .cloud: "☁️"
        case .stardust: "🌟"
        }
    }

    var category: ResourceCategory {
        switch self {
        case .wood, .bamboo: .wood
        case .stone, .clay, .ice: .stone
        case .coal, .iron, .gold, .sulfur, .obsidian: .ore
        case .diamond, .crystal, .ruby: .gem
        case .berries, .apples, .mushrooms, .carrots, .herbs, .fish, .cactus, .coconut, .banana, .pineapple, .goldenApple: .food
        case .egg, .milk, .wool, .honey, .feather: .farm
        case .shell, .coral, .pearl, .cloud, .stardust: .treasure
        }
    }

    /// Базовая цена продажи в монетах.
    var price: Int {
        switch self {
        case .wood: 1
        case .bamboo: 3
        case .stone: 1
        case .clay: 3
        case .coal: 3
        case .iron: 6
        case .gold: 15
        case .sulfur: 20
        case .obsidian: 30
        case .ice: 8
        case .diamond: 60
        case .crystal: 120
        case .ruby: 150
        case .berries: 1
        case .apples: 2
        case .mushrooms: 2
        case .carrots: 2
        case .herbs: 3
        case .fish: 4
        case .cactus: 5
        case .coconut: 6
        case .banana: 8
        case .pineapple: 10
        case .goldenApple: 60
        case .egg: 4
        case .milk: 6
        case .wool: 8
        case .honey: 12
        case .feather: 5
        case .shell: 10
        case .coral: 25
        case .pearl: 90
        case .cloud: 40
        case .stardust: 220
        }
    }

    /// Основной цвет для нарисованных иконок.
    var oreColor: UIColor {
        switch self {
        case .coal: UIColor(red: 0.13, green: 0.13, blue: 0.16, alpha: 1)
        case .iron: UIColor(red: 0.86, green: 0.52, blue: 0.32, alpha: 1)
        case .gold: UIColor(red: 1.0, green: 0.82, blue: 0.18, alpha: 1)
        case .sulfur: UIColor(red: 0.95, green: 0.92, blue: 0.25, alpha: 1)
        case .obsidian: UIColor(red: 0.3, green: 0.18, blue: 0.45, alpha: 1)
        case .crystal: UIColor(red: 0.72, green: 0.45, blue: 1.0, alpha: 1)
        case .diamond: UIColor(red: 0.45, green: 0.9, blue: 1.0, alpha: 1)
        case .ruby: UIColor(red: 0.95, green: 0.15, blue: 0.3, alpha: 1)
        case .pearl: UIColor(red: 0.96, green: 0.94, blue: 0.98, alpha: 1)
        case .goldenApple: UIColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1)
        default: .gray
        }
    }

    static func ordered(in category: ResourceCategory) -> [ResourceKind] {
        allCases.filter { $0.category == category }
    }
}

struct ResourceAmount: Hashable, Identifiable {
    let kind: ResourceKind
    let amount: Int
    var id: ResourceKind { kind }
}

/// Стоимость в монетах и ресурсах.
struct Cost {
    var coins: Int = 0
    var items: [ResourceAmount] = []

    init(coins: Int = 0, _ items: (ResourceKind, Int)...) {
        self.coins = coins
        self.items = items.map { ResourceAmount(kind: $0.0, amount: $0.1) }
    }

    init(coins: Int, items: [ResourceAmount]) {
        self.coins = coins
        self.items = items
    }

    var isFree: Bool { coins == 0 && items.isEmpty }

    func scaled(_ factor: Double) -> Cost {
        Cost(
            coins: Int((Double(coins) * factor).rounded(.up)),
            items: items.map { ResourceAmount(kind: $0.kind, amount: max(1, Int((Double($0.amount) * factor).rounded(.up)))) }
        )
    }
}

enum Fmt {
    private static var formatters: [String: NumberFormatter] = [:]

    private static func formatter() -> NumberFormatter {
        let code = Lang.shared.code
        if let f = formatters[code] { return f }
        let f = NumberFormatter()
        f.locale = Lang.shared.locale
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        formatters[code] = f
        return f
    }

    /// Число с разделителями разрядов, большие числа сокращаются по правилам языка.
    static func n(_ value: Int) -> String {
        if abs(value) >= 100_000 {
            return value.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)).locale(Lang.shared.locale))
        }
        return grouped(value)
    }

    static func grouped(_ value: Int) -> String {
        formatter().string(from: NSNumber(value: value)) ?? String(value)
    }

    static func pct(_ v: Double) -> String {
        let p = v * 100
        if abs(p - p.rounded()) < 0.05 { return "\(Int(p.rounded()))%" }
        return decimal(p, digits: 1) + "%"
    }

    static func decimal(_ v: Double, digits: Int) -> String {
        v.formatted(.number.precision(.fractionLength(digits)).locale(Lang.shared.locale))
    }

    static func seconds(_ s: Double) -> String {
        if s < 60 { return tr("time.sec", Int(s.rounded())) }
        let m = Int(s / 60)
        if m < 60 { return tr("time.min", m) }
        let h = m / 60
        let rest = m % 60
        return rest == 0 ? tr("time.hour", h) : tr("time.hourMin", h, rest)
    }
}
