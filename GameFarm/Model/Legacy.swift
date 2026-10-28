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

    var id: String { rawValue }

    var name: String { tr("legacy.\(rawValue)") }

    var emoji: String {
        switch self {
        case .harvest: "🧺"
        case .wisdom: "📚"
        case .merchant: "💰"
        case .pack: "🎒"
        case .boots: "👟"
        case .growth: "🌱"
        case .talent: "🌟"
        case .tools: "🛠️"
        case .capital: "🪙"
        }
    }

    var maxRank: Int {
        switch self {
        case .tools: 3
        case .talent: 5
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
        }
    }

    /// Цена следующего ранга в искрах.
    func cost(rank: Int) -> Int {
        switch self {
        case .tools: 12 * (rank + 1)
        case .talent: 8 + 6 * rank
        default: 3 + 2 * rank
        }
    }

    /// Текст бонуса для заданного числа рангов.
    func effect(_ ranks: Int) -> String {
        let v = perRank * Double(ranks)
        switch self {
        case .harvest, .wisdom, .merchant, .boots, .growth:
            return tr("legacy.\(rawValue).effect", Fmt.pct(v))
        case .pack, .talent, .tools:
            return tr("legacy.\(rawValue).effect", Int(v))
        case .capital:
            return tr("legacy.\(rawValue).effect", Fmt.n(Int(v)))
        }
    }
}
