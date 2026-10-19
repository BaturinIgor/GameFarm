import UIKit

/// Группа ресурсов: для бонусов талантов и животных и для разделов склада.
enum ResourceCategory: String, CaseIterable, Identifiable {
    case wood, stone, ore, gem, food, farm, treasure

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wood: "Древесина"
        case .stone: "Камень"
        case .ore: "Руда"
        case .gem: "Самоцветы"
        case .food: "Еда"
        case .farm: "С фермы"
        case .treasure: "Диковинки"
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
        case .treasure: "диковинок"
        }
    }
}

enum ResourceKind: String, CaseIterable, Identifiable {
    case wood, bamboo, stone, clay, coal, iron, gold, sulfur, obsidian, ice, diamond, crystal, ruby
    case berries, apples, mushrooms, carrots, herbs, fish, cactus, coconut, banana, pineapple, goldenApple
    case egg, milk, wool, honey, feather
    case shell, coral, pearl, cloud, stardust

    var id: String { rawValue }

    var name: String {
        switch self {
        case .wood: "Древесина"
        case .bamboo: "Бамбук"
        case .stone: "Камень"
        case .clay: "Глина"
        case .coal: "Уголь"
        case .iron: "Железо"
        case .gold: "Золото"
        case .sulfur: "Сера"
        case .obsidian: "Обсидиан"
        case .ice: "Лёд"
        case .diamond: "Алмазы"
        case .crystal: "Кристаллы"
        case .ruby: "Рубины"
        case .berries: "Ягоды"
        case .apples: "Яблоки"
        case .mushrooms: "Грибы"
        case .carrots: "Морковь"
        case .herbs: "Травы"
        case .fish: "Рыба"
        case .cactus: "Кактусы"
        case .coconut: "Кокосы"
        case .banana: "Бананы"
        case .pineapple: "Ананасы"
        case .goldenApple: "Золотые яблоки"
        case .egg: "Яйца"
        case .milk: "Молоко"
        case .wool: "Шерсть"
        case .honey: "Мёд"
        case .feather: "Перья"
        case .shell: "Ракушки"
        case .coral: "Кораллы"
        case .pearl: "Жемчуг"
        case .cloud: "Облачная вата"
        case .stardust: "Звёздная пыль"
        }
    }

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
