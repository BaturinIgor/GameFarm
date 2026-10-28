import Foundation

/// Монстры: слаймы разных цветов и скелеты. Живут в дальних частях обычных локаций.
enum MonsterKind: String, CaseIterable, Identifiable, Codable {
    case slimeGreen, slimeBlue, slimePurple, slimeRed, slimeIce, slimeGold, skeleton, skeletonDark

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
        }
    }

    var isSlime: Bool { self != .skeleton && self != .skeletonDark }

    var emoji: String { isSlime ? "🟢" : "💀" }

    /// Трофей, который с него падает.
    var loot: ResourceKind { isSlime ? .slime : .bone }
}

/// Монстры каждой локации и их уровень.
enum Bestiary {
    static func monsters(in location: LocationID) -> [(MonsterKind, Int)] {
        switch location {
        case .meadow: [(.slimeGreen, 3)]
        case .hills: [(.slimeGreen, 4)]
        case .lake: [(.slimeBlue, 4)]
        case .swamp: [(.slimePurple, 3), (.skeleton, 2)]
        case .desert: [(.skeleton, 4)]
        case .snow: [(.slimeIce, 5)]
        case .caves: [(.skeletonDark, 3), (.slimePurple, 2)]
        case .island: [(.slimeBlue, 3), (.slimeGold, 1)]
        case .volcano: [(.slimeRed, 4), (.skeletonDark, 2)]
        case .sky: [(.slimePurple, 3), (.slimeGold, 2)]
        default: []
        }
    }

    static func level(in location: LocationID) -> Int {
        max(2, location.spec.level + 2)
    }

    /// Где водится монстр (первая открытая подходящая локация).
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

    init(kind: MonsterKind, level: Int) {
        let l = Double(level)
        let tough = kind.isSlime ? 1.0 : 1.35
        hp = 26 * pow(1.12, l) * tough * (kind == .slimeGold ? 1.6 : 1)
        damage = 4 * pow(1.09, l) * (kind.isSlime ? 1 : 1.3)
        speed = kind.isSlime ? 60 : 78
        xp = Int(8 + l * 2.5 * tough)
        coins = Int((4 + l * 1.5) * (kind == .slimeGold ? 6 : 1))
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
    /// Максимум здоровья: растёт с уровнем и ступенью брони.
    static func maxHP(level: Int, armor: Int) -> Double {
        100 + Double(level - 1) * 8 + Double(armor - 1) * 45
    }

    /// Урон мечом за удар.
    static func swordDamage(level: Int, sword: Int) -> Double {
        7 * ToolTier.power(sword) * (1 + 0.02 * Double(level - 1))
    }
}
