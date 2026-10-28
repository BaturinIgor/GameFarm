import UIKit

/// Монстры: слаймы, скелеты и орки. Живут в дальних частях локаций и в подземельях.
enum MonsterKind: String, CaseIterable, Identifiable, Codable {
    case slimeGreen, slimeBlue, slimePurple, slimeRed, slimeIce, slimeGold, skeleton, skeletonDark
    case orc, orcRogue, orcShaman, orcWarrior, skelSoldier, skelMage, skelRogue, skelKnight

    var id: String { rawValue }

    var name: String { tr("monster.\(rawValue)") }

    var sprite: String {
        switch self {
        case .slimeGreen: "mo_slime_green"
        case .slimeBlue: "mo_slime_blue"
        case .slimePurple: "mo_slime_purple"
        case .slimeRed: "mo_slime_red"
        case .slimeIce: "mo_slime_ice"
        case .slimeGold: "mo_slime_gold"
        case .skeleton: "mo_skeleton"
        case .skeletonDark: "mo_skeleton_dark"
        case .orc: "mo_orc"
        case .orcRogue: "mo_orc_rogue"
        case .orcShaman: "mo_orc_shaman"
        case .orcWarrior: "mo_orc_warrior"
        case .skelSoldier: "mo_skel_soldier"
        case .skelMage: "mo_skel_mage"
        case .skelRogue: "mo_skel_rogue"
        case .skelKnight: "mo_skel_knight"
        }
    }

    var isSlime: Bool {
        switch self {
        case .slimeGreen, .slimeBlue, .slimePurple, .slimeRed, .slimeIce, .slimeGold: true
        default: false
        }
    }

    var isOrc: Bool { self == .orc || self == .orcRogue || self == .orcShaman || self == .orcWarrior }

    var emoji: String { isSlime ? "🟢" : (isOrc ? "👹" : "💀") }

    /// Трофей, который с него падает.
    var loot: ResourceKind { isSlime ? .slime : (isOrc ? .tusk : .bone) }

    /// Как нарезан лист: клетка, колонки и ряды анимаций.
    var sheet: MonsterSheet {
        if isSlime {
            return MonsterSheet(cell: 64, cols: 8, idle: (0, 0..<4), move: (1, 0..<8), hurt: (2, 1..<4), death: (2, 4..<8), bar: 40)
        }
        switch self {
        case .skeleton, .skeletonDark:
            return MonsterSheet(cell: 32, cols: 6, idle: (1, 0..<6), move: (4, 0..<6), hurt: (8, 0..<4), death: (6, 0..<4), bar: 56)
        default:
            let deaths: [MonsterKind: Int] = [.orc: 6, .orcRogue: 6, .orcShaman: 7, .orcWarrior: 9,
                                              .skelSoldier: 12, .skelMage: 6, .skelRogue: 6, .skelKnight: 8]
            return MonsterSheet(cell: 64, cols: 12, idle: (0, 0..<4), move: (1, 0..<6), hurt: nil,
                                death: (2, 0..<(deaths[self] ?? 6)), bar: 50)
        }
    }

    /// Насколько крепкий, сильный и быстрый.
    var toughness: Double {
        switch self {
        case .skeleton, .skeletonDark: 1.35
        case .orc: 1.5
        case .orcRogue: 1.1
        case .orcShaman: 1.0
        case .orcWarrior: 2.0
        case .skelSoldier: 1.3
        case .skelMage: 0.9
        case .skelRogue: 1.0
        case .skelKnight: 1.9
        case .slimeGold: 1.6
        default: 1
        }
    }

    var strength: Double {
        switch self {
        case .skeleton, .skeletonDark: 1.3
        case .orc: 1.25
        case .orcRogue: 1.5
        case .orcShaman: 1.1
        case .orcWarrior: 1.4
        case .skelSoldier: 1.2
        case .skelMage: 1.6
        case .skelRogue: 1.4
        case .skelKnight: 1.35
        default: 1
        }
    }

    var speed: Double {
        switch self {
        case .skeleton, .skeletonDark: 78
        case .orc: 72
        case .orcRogue, .skelRogue: 95
        case .orcShaman: 60
        case .orcWarrior, .skelKnight: 62
        case .skelSoldier: 76
        case .skelMage: 66
        default: 60
        }
    }
}

/// Нарезка листа анимаций монстра.
struct MonsterSheet {
    let cell: CGFloat
    let cols: Int
    let idle: (row: Int, frames: Range<Int>)
    let move: (row: Int, frames: Range<Int>)
    let hurt: (row: Int, frames: Range<Int>)?
    let death: (row: Int, frames: Range<Int>)
    /// Высота полоски здоровья над точкой опоры.
    let bar: CGFloat
}

/// Особые свойства монстров: делают бой разнообразнее. Видны значками над монстром.
enum MonsterTrait: String, CaseIterable, Codable {
    case crit, dodge, regen, slow, poison, shield, enrage, vampire, thorns, swift

    var name: String { tr("trait.\(rawValue)") }
    var info: String { tr("trait.\(rawValue).info") }

    /// Иконка ic_<имя>.
    var icon: String {
        switch self {
        case .crit: "bolt"
        case .dodge: "eye"
        case .regen: "heart_plus"
        case .slow: "hourglass"
        case .poison: "slime"
        case .shield: "shield"
        case .enrage: "skull"
        case .vampire: "heart"
        case .thorns: "sword"
        case .swift: "boots"
        }
    }

    /// Сколько свойств у монстра такого уровня (обычные монстры в мире).
    static func roll(level: Int) -> [MonsterTrait] {
        let chance = level >= 30 ? 0.45 : (level >= 18 ? 0.3 : (level >= 10 ? 0.15 : 0))
        guard Double.random(in: 0..<1) < chance else { return [] }
        return [allCases.randomElement()!]
    }

    static func pick(_ n: Int) -> [MonsterTrait] { Array(allCases.shuffled().prefix(n)) }
}

/// Монстры каждой локации и их уровень.
enum Bestiary {
    static func monsters(in location: LocationID) -> [(MonsterKind, Int)] {
        switch location {
        case .meadow: [(.slimeGreen, 3)]
        case .hills: [(.slimeGreen, 3), (.orc, 1)]
        case .lake: [(.slimeBlue, 4)]
        case .swamp: [(.slimePurple, 3), (.skeleton, 2)]
        case .desert: [(.skeleton, 3), (.skelRogue, 2)]
        case .snow: [(.slimeIce, 4), (.orcWarrior, 1)]
        case .caves: [(.skeletonDark, 3), (.slimePurple, 2), (.skelMage, 1)]
        case .island: [(.slimeBlue, 3), (.slimeGold, 1), (.orcRogue, 1)]
        case .volcano: [(.slimeRed, 4), (.skeletonDark, 2), (.orcShaman, 1)]
        case .sky: [(.slimePurple, 3), (.slimeGold, 2), (.skelKnight, 1)]
        default: []
        }
    }

    static func level(in location: LocationID) -> Int {
        max(2, location.spec.level + 2)
    }

    /// Где водится монстр.
    static func home(of kind: MonsterKind) -> [LocationID] {
        LocationID.world.filter { id in monsters(in: id).contains { $0.0 == kind } }
    }
}

/// Характеристики монстра на заданном уровне.
struct MonsterStats {
    let hp: Double
    let damage: Double
    let speed: Double
    let xp: Int
    let coins: Int

    init(kind: MonsterKind, level: Int, boss: Bool = false) {
        let l = Double(level)
        hp = 26 * pow(1.12, l) * kind.toughness * (boss ? 10 : 1)
        damage = 4 * pow(1.09, l) * kind.strength * (boss ? 1.6 : 1)
        speed = kind.speed * (boss ? 0.9 : 1)
        xp = Int((8 + l * 2.5 * kind.toughness) * (boss ? 10 : 1))
        coins = Int((4 + l * 1.5) * (kind == .slimeGold ? 6 : 1) * (boss ? 15 : 1))
    }
}

// MARK: Охота

/// Заказ стражника: убить столько-то монстров.
struct HuntContract: Codable, Equatable, Identifiable {
    var id = UUID()
    let monster: MonsterKind
    let target: Int
    var progress = 0
    let coins: Int
    let xp: Int
    let ticket: Bool

    var done: Bool { progress >= target }
}

enum Hero {
    /// Максимум здоровья: растёт с уровнем, бронёй и шлемом.
    static func maxHP(level: Int, armor: Int, helmet: Int = 1) -> Double {
        100 + Double(level - 1) * 8 + Double(armor - 1) * 45 + Double(helmet - 1) * 20
    }

    /// Шлем снижает входящий урон.
    static func defense(helmet: Int) -> Double { min(0.36, 0.04 * Double(helmet - 1)) }

    /// Сапоги: шанс увернуться и скорость.
    static func dodge(boots: Int) -> Double { 0.015 * Double(boots - 1) }
    static func speed(boots: Int) -> Double { 0.03 * Double(boots - 1) }

    /// Урон оружием за удар.
    static func swordDamage(level: Int, sword: Int) -> Double {
        7 * ToolTier.power(sword) * (1 + 0.02 * Double(level - 1))
    }
}
