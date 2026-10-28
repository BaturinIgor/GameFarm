import UIKit

/// Подземелья: в каждом 10 этажей с волнами монстров, на 5 и 10 этаже - босс.
enum DungeonID: String, CaseIterable, Identifiable, Codable {
    case slimeCaves, boneCrypt, orcCamp, frostHollow, fireDepths

    var id: String { rawValue }
    var name: String { tr("dungeon.\(rawValue)") }
    var blurb: String { tr("dungeon.\(rawValue).blurb") }
    var bossName: String { tr("dungeon.\(rawValue).boss") }

    /// Карта подземелья.
    var location: LocationID {
        switch self {
        case .slimeCaves: .dSlime
        case .boneCrypt: .dCrypt
        case .orcCamp: .dOrc
        case .frostHollow: .dFrost
        case .fireDepths: .dFire
        }
    }

    /// С какого уровня героя открыто.
    var level: Int {
        switch self {
        case .slimeCaves: 8
        case .boneCrypt: 15
        case .orcCamp: 22
        case .frostHollow: 30
        case .fireDepths: 40
        }
    }

    /// Уровень монстров на первом этаже.
    var baseLevel: Int {
        switch self {
        case .slimeCaves: 6
        case .boneCrypt: 13
        case .orcCamp: 20
        case .frostHollow: 28
        case .fireDepths: 37
        }
    }

    var mobs: [MonsterKind] {
        switch self {
        case .slimeCaves: [.slimeGreen, .slimeBlue, .slimePurple]
        case .boneCrypt: [.skeleton, .skelSoldier, .skelRogue, .skelMage]
        case .orcCamp: [.orc, .orcRogue, .orcShaman]
        case .frostHollow: [.slimeIce, .skeletonDark, .skelKnight]
        case .fireDepths: [.slimeRed, .orcWarrior, .skelMage, .skeletonDark]
        }
    }

    var boss: MonsterKind {
        switch self {
        case .slimeCaves: .slimeGold
        case .boneCrypt: .skelKnight
        case .orcCamp: .orcWarrior
        case .frostHollow: .slimeIce
        case .fireDepths: .slimeRed
        }
    }

    /// Окраска босса.
    var bossTint: UIColor? {
        switch self {
        case .slimeCaves: nil
        case .boneCrypt: UIColor(red: 0.55, green: 0.4, blue: 0.9, alpha: 1)
        case .orcCamp: UIColor(red: 0.9, green: 0.3, blue: 0.2, alpha: 1)
        case .frostHollow: UIColor(red: 0.4, green: 0.7, blue: 1, alpha: 1)
        case .fireDepths: UIColor(red: 1, green: 0.35, blue: 0.05, alpha: 1)
        }
    }

    /// Оружие босса.
    var weapon: WeaponID {
        switch self {
        case .slimeCaves: .slimeBlade
        case .boneCrypt: .boneSaber
        case .orcCamp: .orcCleaver
        case .frostHollow: .frostBrand
        case .fireDepths: .flameSword
        }
    }

    var colors: (UInt32, UInt32) {
        switch self {
        case .slimeCaves: (0x6FD15A, 0x1F5A3A)
        case .boneCrypt: (0xB8B0C8, 0x3A3450)
        case .orcCamp: (0xC89A5A, 0x5A3A1E)
        case .frostHollow: (0xA8DCFF, 0x2A4A8A)
        case .fireDepths: (0xFF9A4A, 0x7A1A0E)
        }
    }
}

/// Подземелья, которые появятся позже: только анонс.
enum ComingDungeon: String, CaseIterable, Identifiable {
    case sunkenTemple, starMaze
    var id: String { rawValue }
    var name: String { tr("dungeon.soon.\(rawValue)") }
    var blurb: String { tr("dungeon.soon.\(rawValue).blurb") }
}

/// Идущий забег по подземелью (не сохраняется: если игру закрыть, забег прерывается).
struct DungeonRun: Equatable {
    let dungeon: DungeonID
    let floor: Int
    var wave = 0
    var waves: Int
    var cleared = false
    var chestOpened = false
    var kills = 0
    var coins = 0
    var essence = 0
}

/// Итог забега для окна после выхода.
struct DungeonReport: Equatable {
    let dungeon: DungeonID
    let floor: Int
    let won: Bool
    let firstClear: Bool
    let coins: Int
    let essence: Int
    let weapon: WeaponID?
    let potions: Int
    var maps = 0
}

enum Dungeon {
    static let floors = 10

    static func isBossFloor(_ floor: Int) -> Bool { floor == 5 || floor == 10 }

    static func waves(floor: Int) -> Int { floor <= 3 ? 2 : (floor <= 7 ? 3 : 4) }

    static func monstersPerWave(floor: Int) -> Int { min(7, 3 + floor / 2) }

    static func monsterLevel(_ id: DungeonID, floor: Int) -> Int {
        id.baseLevel + Int((Double(floor - 1) * 1.5).rounded())
    }

    /// Сколько особых свойств у обычного монстра на этаже.
    static func traits(floor: Int) -> Int {
        let r = Double.random(in: 0..<1)
        switch floor {
        case 1...3: return r < 0.15 ? 1 : 0
        case 4...6: return r < 0.5 ? 1 : 0
        default: return r < 0.3 ? 2 : 1
        }
    }

    static func bossTraits(floor: Int) -> Int { floor >= 10 ? 3 : 2 }

    /// Награда за этаж: монеты и эссенция. Первое прохождение - втрое больше и зелья.
    static func coins(_ id: DungeonID, floor: Int, first: Bool) -> Int {
        let base = Double(60 + id.baseLevel * 12) * (1 + Double(floor) * 0.35) * (isBossFloor(floor) ? 2 : 1)
        return Int(base * (first ? 3 : 1))
    }

    static func essence(_ id: DungeonID, floor: Int, first: Bool) -> Int {
        let tier = DungeonID.allCases.firstIndex(of: id) ?? 0
        let base = 1 + tier + floor / 3 + (isBossFloor(floor) ? 3 + tier : 0)
        return base * (first ? 3 : 1)
    }

    /// Шанс, что босс отдаст оружие (на 10 этаже при первом прохождении - всегда).
    static func weaponChance(floor: Int, first: Bool) -> Double {
        if floor == 10 && first { return 1 }
        if floor == 10 { return 0.2 }
        return floor == 5 ? 0.15 : 0
    }
}

/// Босс на арене для полоски сверху экрана.
struct BossInfo: Equatable {
    let name: String
    let fraction: Double
}

/// Зелье лечения: восстанавливает 40% здоровья. Продаёт стражник, падает в подземельях.
enum Potion {
    static let heal = 0.4
    static let cooldown: TimeInterval = 4
    static func price(level: Int) -> Int { 40 + level * 6 }
}
