import UIKit

/// Группа ресурсов: для бонусов талантов и животных и для разделов склада.
enum ResourceCategory: String, CaseIterable, Identifiable {
    case wood, stone, ore, gem, food, farm

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wood: "Древесина"
        case .stone: "Камень"
        case .ore: "Руда"
        case .gem: "Самоцветы"
        case .food: "Еда"
        case .farm: "С фермы"
        }
    }

    /// "+15% к добыче дерева"
    var genitive: String {
        switch self {
        case .wood: "дерева"
        case .stone: "камня"
        case .ore: "руды"
        case .gem: "самоцветов"
        case .food: "еды"
        case .farm: "продуктов фермы"
        }
    }
}

enum ResourceKind: String, CaseIterable, Identifiable {
    case wood, bamboo, stone, coal, iron, gold, ice, diamond, crystal
    case berries, apples, mushrooms, carrots, fish, cactus, coconut
    case egg, milk, wool, honey, feather

    var id: String { rawValue }

    var name: String {
        switch self {
        case .wood: "Древесина"
        case .bamboo: "Бамбук"
        case .stone: "Камень"
        case .coal: "Уголь"
        case .iron: "Железо"
        case .gold: "Золото"
        case .ice: "Лёд"
        case .diamond: "Алмазы"
        case .crystal: "Кристаллы"
        case .berries: "Ягоды"
        case .apples: "Яблоки"
        case .mushrooms: "Грибы"
        case .carrots: "Морковь"
        case .fish: "Рыба"
        case .cactus: "Кактусы"
        case .coconut: "Кокосы"
        case .egg: "Яйца"
        case .milk: "Молоко"
        case .wool: "Шерсть"
        case .honey: "Мёд"
        case .feather: "Перья"
        }
    }

    /// nil - иконка рисуется кодом (руды и кристаллы).
    var emoji: String? {
        switch self {
        case .wood: "🪵"
        case .bamboo: "🎋"
        case .stone: "🪨"
        case .coal, .iron, .gold, .crystal: nil
        case .ice: "🧊"
        case .diamond: "💎"
        case .berries: "🫐"
        case .apples: "🍎"
        case .mushrooms: "🍄"
        case .carrots: "🥕"
        case .fish: "🐟"
        case .cactus: "🌵"
        case .coconut: "🥥"
        case .egg: "🥚"
        case .milk: "🥛"
        case .wool: "🧶"
        case .honey: "🍯"
        case .feather: "🪶"
        }
    }

    var category: ResourceCategory {
        switch self {
        case .wood, .bamboo: .wood
        case .stone, .ice: .stone
        case .coal, .iron, .gold: .ore
        case .diamond, .crystal: .gem
        case .berries, .apples, .mushrooms, .carrots, .fish, .cactus, .coconut: .food
        case .egg, .milk, .wool, .honey, .feather: .farm
        }
    }

    /// Базовая цена продажи в монетах.
    var price: Int {
        switch self {
        case .wood: 1
        case .bamboo: 3
        case .stone: 1
        case .coal: 3
        case .iron: 6
        case .gold: 15
        case .ice: 8
        case .diamond: 60
        case .crystal: 120
        case .berries: 1
        case .apples: 2
        case .mushrooms: 2
        case .carrots: 2
        case .fish: 4
        case .cactus: 5
        case .coconut: 6
        case .egg: 4
        case .milk: 6
        case .wool: 8
        case .honey: 12
        case .feather: 5
        }
    }

    /// Цвет вкраплений для нарисованных руд.
    var oreColor: UIColor {
        switch self {
        case .coal: UIColor(red: 0.13, green: 0.13, blue: 0.16, alpha: 1)
        case .iron: UIColor(red: 0.86, green: 0.52, blue: 0.32, alpha: 1)
        case .gold: UIColor(red: 1.0, green: 0.82, blue: 0.18, alpha: 1)
        case .crystal: UIColor(red: 0.72, green: 0.45, blue: 1.0, alpha: 1)
        case .diamond: UIColor(red: 0.45, green: 0.9, blue: 1.0, alpha: 1)
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
    /// 1234567 -> "1 234 567", большие числа сокращаются.
    static func n(_ value: Int) -> String {
        if value >= 10_000_000 {
            return short(Double(value) / 1_000_000) + " млн"
        }
        if value >= 100_000 {
            return short(Double(value) / 1_000) + " тыс"
        }
        return grouped(value)
    }

    static func grouped(_ value: Int) -> String {
        let digits = String(abs(value))
        var out = ""
        for (i, ch) in digits.reversed().enumerated() {
            if i > 0 && i % 3 == 0 { out.append("\u{00A0}") }
            out.append(ch)
        }
        return (value < 0 ? "-" : "") + String(out.reversed())
    }

    private static func short(_ v: Double) -> String {
        let s = v >= 100 ? String(format: "%.0f", v) : String(format: "%.1f", v)
        return s.replacingOccurrences(of: ".", with: ",")
    }

    static func pct(_ v: Double) -> String {
        let p = v * 100
        if abs(p - p.rounded()) < 0.05 { return "\(Int(p.rounded()))%" }
        return String(format: "%.1f%%", p).replacingOccurrences(of: ".", with: ",")
    }

    static func seconds(_ s: Double) -> String {
        if s < 60 { return "\(Int(s.rounded())) с" }
        let m = Int(s / 60)
        if m < 60 { return "\(m) мин" }
        let h = m / 60
        let rest = m % 60
        return rest == 0 ? "\(h) ч" : "\(h) ч \(rest) мин"
    }
}
