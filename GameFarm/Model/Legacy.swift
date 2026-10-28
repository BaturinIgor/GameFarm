import Foundation

/// Перерождение: игрок начинает заново и получает искры, а за искры покупает вечные бонусы наследия.
enum Rebirth {
    /// С этого уровня перерождение даёт искры.
    static let minLevel = 15

    /// Искры за текущий забег: растут с уровнем, плюс немного за достижения и открытые проходы.
    static func sparks(level: Int, achievements: Int, gates: Int) -> Int {
        guard level >= minLevel else { return 0 }
        let base = pow(Double(level - 10), 1.5) / 2
        return Int(base.rounded(.down)) + achievements / 2 + gates
    }
}

/// Вечные бонусы наследия. Сохраняются при перерождении.
enum LegacyPerk: String, CaseIterable, Identifiable {
    case harvest, wisdom, merchant, pack, boots, growth, talent, tools, capital
    case fighter, vigor, luck, gardener, chef, companions

    var id: String { rawValue }

    var name: String { tr("legacy.\(rawValue)") }

    /// Пиксельная иконка бонуса.
    var icon: String {
        switch self {
        case .harvest: "basket"
        case .wisdom: "book"
        case .merchant: "coins"
        case .pack: "bag"
        case .boots: "boots"
        case .growth: "hourglass"
        case .talent: "star"
        case .tools: "hammer"
        case .capital: "chest_gold"
        case .fighter: "sword"
        case .vigor: "heart"
        case .luck: "clover"
        case .gardener: "sprout"
        case .chef: "dish_stew"
        case .companions: "paw"
        }
    }

    var maxRank: Int {
        switch self {
        case .tools, .companions: 3
        case .talent, .chef: 5
        default: 10
        }
    }

    /// Прибавка за один ранг.
    var perRank: Double {
        switch self {
        case .harvest: 0.05
        case .wisdom: 0.06
        case .merchant: 0.05
        case .pack: 4
        case .boots: 0.03
        case .growth: 0.05
        case .talent: 1
        case .tools: 1
        case .capital: 300
        case .fighter: 0.05
        case .vigor: 0.05
        case .luck: 0.01
        case .gardener: 0.04
        case .chef: 0.1
        case .companions: 1
        }
    }

    /// Цена следующего ранга в искрах.
    func cost(rank: Int) -> Int {
        switch self {
        case .tools: 12 * (rank + 1)
        case .companions: 10 + 10 * rank
        case .talent: 8 + 6 * rank
        default: 3 + 2 * rank
        }
    }

    /// Текст бонуса для заданного числа рангов.
    func effect(_ ranks: Int) -> String {
        let v = perRank * Double(ranks)
        switch self {
        case .harvest, .wisdom, .merchant, .boots, .growth, .fighter, .vigor, .luck, .gardener, .chef:
            return tr("legacy.\(rawValue).effect", Fmt.pct(v))
        case .pack, .talent, .tools, .companions:
            return tr("legacy.\(rawValue).effect", Int(v))
        case .capital:
            return tr("legacy.\(rawValue).effect", Fmt.n(Int(v)))
        }
    }
}
