import UIKit

/// Разделы мастерской: инструменты добычи, защита и оружие.
enum GearTab: String, CaseIterable, Identifiable {
    case gathering, defense, weapons

    var id: String { rawValue }
    var title: String { tr("gear.tab.\(rawValue)") }

    var tools: [ToolKind] {
        switch self {
        case .gathering: [.axe, .pickaxe, .rod]
        case .defense: [.helmet, .armor, .boots]
        case .weapons: [.sword]
        }
    }
}

/// Бонусы ступеней: на 3, 5, 7, 9 и 10 ступени инструмент получает особое свойство.
enum ToolPerkKind: Equatable {
    case yield(ResourceCategory, Double)
    case fish(Double)
    case honey(Double)
    case goldenApple(Double)
    case cleave(Double)
    case gem(Double)
    case ruby(Double)
    case stardust(Double)
    case coinChest(Double)
    case doubleCatch(Double)
    case pearl(Double)
    case giantFish(Double)
    case crit(Double)
    case lifesteal(Double)
    case swordCleave(Double)
    case bossDamage(Double)
    case stun(Double)
    case hp(Double)
    case combatRegen(Double)
    case thorns(Double)
    case secondWind
    case defense(Double)
    case poisonImmune
    case slowImmune
    case critImmune
    case speed(Double)
    case dodge(Double)
}

struct ToolPerk: Identifiable {
    let tool: ToolKind
    let tier: Int
    let kind: ToolPerkKind

    var id: String { "\(tool.rawValue)_\(tier)" }

    var text: String {
        switch kind {
        case .yield(let cat, let v): tr("perk.yield", cat.title, Fmt.pct(v))
        case .fish(let v): tr("perk.fish", Fmt.pct(v))
        case .honey(let v): tr("perk.honey", Fmt.pct(v))
        case .goldenApple(let v): tr("perk.goldenApple", Fmt.pct(v))
        case .cleave(let v): tr("perk.cleave", Fmt.pct(v))
        case .gem(let v): tr("perk.gem", Fmt.pct(v))
        case .ruby(let v): tr("perk.ruby", Fmt.pct(v))
        case .stardust(let v): tr("perk.stardust", Fmt.pct(v))
        case .coinChest(let v): tr("perk.coinChest", Fmt.pct(v))
        case .doubleCatch(let v): tr("perk.doubleCatch", Fmt.pct(v))
        case .pearl(let v): tr("perk.pearl", Fmt.pct(v))
        case .giantFish(let v): tr("perk.giantFish", Fmt.pct(v))
        case .crit(let v): tr("perk.crit", Fmt.pct(v))
        case .lifesteal(let v): tr("perk.lifesteal", Fmt.pct(v))
        case .swordCleave(let v): tr("perk.swordCleave", Fmt.pct(v))
        case .bossDamage(let v): tr("perk.bossDamage", Fmt.pct(v))
        case .stun(let v): tr("perk.stun", Fmt.pct(v))
        case .hp(let v): tr("perk.hp", Fmt.pct(v))
        case .combatRegen(let v): tr("perk.combatRegen", Fmt.pct(v))
        case .thorns(let v): tr("perk.thorns", Fmt.pct(v))
        case .secondWind: tr("perk.secondWind")
        case .defense(let v): tr("perk.defense", Fmt.pct(v))
        case .poisonImmune: tr("perk.poisonImmune")
        case .slowImmune: tr("perk.slowImmune")
        case .critImmune: tr("perk.critImmune")
        case .speed(let v): tr("perk.speed", Fmt.pct(v))
        case .dodge(let v): tr("perk.dodge", Fmt.pct(v))
        }
    }

    static func list(_ tool: ToolKind) -> [ToolPerk] {
        let table: [(Int, ToolPerkKind)]
        switch tool {
        case .axe: table = [(3, .yield(.wood, 0.1)), (5, .honey(0.03)), (7, .cleave(0.1)), (9, .goldenApple(0.01)), (10, .yield(.wood, 0.2))]
        case .pickaxe: table = [(3, .yield(.stone, 0.1)), (5, .gem(0.02)), (7, .cleave(0.1)), (9, .ruby(0.01)), (10, .stardust(0.005))]
        case .rod: table = [(3, .fish(0.1)), (5, .coinChest(0.02)), (7, .doubleCatch(0.05)), (9, .pearl(0.01)), (10, .giantFish(0.001))]
        case .sword: table = [(3, .crit(0.05)), (5, .lifesteal(0.03)), (7, .swordCleave(0.4)), (9, .bossDamage(0.15)), (10, .stun(0.05))]
        case .armor: table = [(3, .hp(0.05)), (5, .combatRegen(0.01)), (7, .thorns(0.1)), (9, .hp(0.1)), (10, .secondWind)]
        case .helmet: table = [(3, .defense(0.02)), (5, .poisonImmune), (7, .slowImmune), (9, .defense(0.05)), (10, .critImmune)]
        case .boots: table = [(3, .speed(0.05)), (5, .dodge(0.03)), (7, .speed(0.05)), (9, .dodge(0.03)), (10, .speed(0.1))]
        case .hand: table = []
        }
        return table.map { ToolPerk(tool: tool, tier: $0.0, kind: $0.1) }
    }
}

/// Бонусы снаряжения, собранные со всех ступеней.
struct GearPerks {
    var honey = 0.0
    var goldenApple = 0.0
    var chopCleave = 0.0
    var mineCleave = 0.0
    var ruby = 0.0
    var stardust = 0.0
    var coinChest = 0.0
    var doubleCatch = 0.0
    var pearl = 0.0
    var giantFish = 0.0
    var lifesteal = 0.0
    var swordCleave = 0.0
    var bossDamage = 0.0
    var stun = 0.0
    var hpBonus = 0.0
    var combatRegen = 0.0
    var thorns = 0.0
    var secondWind = false
    var defense = 0.0
    var poisonImmune = false
    var slowImmune = false
    var critImmune = false
    var dodge = 0.0
    var speed = 0.0

    /// Применяет бонусы ступеней к характеристикам.
    static func collect(tiers: (ToolKind) -> Int, into s: inout Stats) -> GearPerks {
        var g = GearPerks()
        for tool in ToolKind.upgradable {
            let tier = tiers(tool)
            for perk in ToolPerk.list(tool) where tier >= perk.tier {
                switch perk.kind {
                case .yield(let cat, let v):
                    s.yieldCategory[cat, default: 0] += v
                    if cat == .stone { s.yieldCategory[.ore, default: 0] += v }
                case .fish(let v): s.yieldKind[.fish, default: 0] += v
                case .honey(let v): g.honey += v
                case .goldenApple(let v): g.goldenApple += v
                case .cleave(let v): if tool == .axe { g.chopCleave += v } else { g.mineCleave += v }
                case .gem(let v): s.gemChance += v
                case .ruby(let v): g.ruby += v
                case .stardust(let v): g.stardust += v
                case .coinChest(let v): g.coinChest += v
                case .doubleCatch(let v): g.doubleCatch += v
                case .pearl(let v): g.pearl += v
                case .giantFish(let v): g.giantFish += v
                case .crit(let v): s.critChance += v
                case .lifesteal(let v): g.lifesteal += v
                case .swordCleave(let v): g.swordCleave = max(g.swordCleave, v)
                case .bossDamage(let v): g.bossDamage += v
                case .stun(let v): g.stun += v
                case .hp(let v): g.hpBonus += v
                case .combatRegen(let v): g.combatRegen += v
                case .thorns(let v): g.thorns += v
                case .secondWind: g.secondWind = true
                case .defense(let v): g.defense += v
                case .poisonImmune: g.poisonImmune = true
                case .slowImmune: g.slowImmune = true
                case .critImmune: g.critImmune = true
                case .speed(let v): g.speed += v
                case .dodge(let v): g.dodge += v
                }
            }
        }
        return g
    }
}

// MARK: Оружие

/// Особое оружие: падает с боссов подземелий, у каждого своё свойство.
enum WeaponID: String, CaseIterable, Identifiable, Codable {
    case forged, slimeBlade, boneSaber, orcCleaver, frostBrand, flameSword, royalSword

    var id: String { rawValue }
    var name: String { tr("weapon.\(rawValue)") }
    var effectText: String { tr("weapon.\(rawValue).effect") }
    var source: String { tr("weapon.\(rawValue).source") }

    /// Иконка: кованый меч рисуется как обычный меч своей ступени.
    var color: UIColor {
        switch self {
        case .forged: .white
        case .slimeBlade: UIColor(red: 0.45, green: 0.95, blue: 0.4, alpha: 1)
        case .boneSaber: UIColor(red: 0.95, green: 0.92, blue: 0.85, alpha: 1)
        case .orcCleaver: UIColor(red: 0.6, green: 0.75, blue: 0.3, alpha: 1)
        case .frostBrand: UIColor(red: 0.55, green: 0.85, blue: 1, alpha: 1)
        case .flameSword: UIColor(red: 1, green: 0.5, blue: 0.15, alpha: 1)
        case .royalSword: UIColor(red: 1, green: 0.82, blue: 0.2, alpha: 1)
        }
    }

    /// Во сколько раз сильнее кованого меча той же ступени.
    var mult: Double {
        switch self {
        case .forged: 1
        case .royalSword: 1.15
        default: 1.1
        }
    }

    /// С какой ступени оружие попадает в руки.
    var startTier: Int {
        switch self {
        case .forged: 1
        case .slimeBlade: 3
        case .boneSaber: 4
        case .orcCleaver: 5
        case .frostBrand: 6
        case .flameSword: 7
        case .royalSword: 4
        }
    }

    static func upgradeCost(to tier: Int) -> Cost {
        let t = Double(tier)
        let coins = Int(300 * pow(t, 2.4))
        if tier >= 8 { return Cost(coins: coins, (.essence, Int(8 * t)), (.stardust, tier - 6)) }
        if tier >= 5 { return Cost(coins: coins, (.essence, Int(5 * t)), (.gold, 4 * tier)) }
        return Cost(coins: coins, (.essence, 3 * tier), (.iron, 10 * tier))
    }
}
