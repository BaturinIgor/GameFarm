import SwiftUI

enum TalentBranch: String, CaseIterable, Identifiable {
    case mining, gathering, travel, beasts

    var id: String { rawValue }

    var title: String { tr("branch.\(rawValue)") }

    var emoji: String {
        switch self {
        case .mining: "⚒️"
        case .gathering: "🧺"
        case .travel: "🧭"
        case .beasts: "🐾"
        }
    }

    var color: Color {
        switch self {
        case .mining: Color(red: 0.95, green: 0.45, blue: 0.25)
        case .gathering: Color(red: 0.3, green: 0.75, blue: 0.35)
        case .travel: Color(red: 0.3, green: 0.6, blue: 1.0)
        case .beasts: Color(red: 0.9, green: 0.4, blue: 0.75)
        }
    }

    var talents: [TalentID] { TalentID.allCases.filter { $0.spec.branch == self } }
}

enum TalentID: String, CaseIterable, Identifiable {
    case power, lumberjack, miner, quickHands, crit, shatter, critPower, strongHands, quake
    case bounty, regrowth, scholar, doubleDrop, farmer, trader, gardener, gemFinder, goldenTouch
    case swift, bigPack, reach, tamer, beastBond, packLeader, thrift, nightShift, portal
    case doubleStrike, shockwave, oreHunter, execute, crusher, tireless, toolMaster
    case finder, goldRush, jeweler, fertile, triple, sage, abundance
    case packMaster, tailwind, depotReach, bargain, tracker, storekeeper, strider
    case animalFriend, training, rancher, keenEye, packTier, pasture, starFood
    case beastLoot, catcher, alpha, herdsman, starHunter, soul

    var id: String { rawValue }
    var spec: TalentSpec { TalentSpec.table[self]! }
}

struct TalentSpec {
    enum Unit { case percent, flat, flag }

    let id: TalentID
    let branch: TalentBranch
    let emoji: String
    let maxRank: Int
    let tier: Int
    let column: Int
    let parents: [TalentID]
    let perRank: Double
    let unit: Unit

    var name: String { tr("talent.\(id.rawValue)") }

    /// Уровень персонажа, с которого открывается ряд дерева.
    static let tierLevels = [1, 3, 6, 10, 15, 22, 30, 40, 50]

    var requiredLevel: Int { Self.tierLevels[tier] }

    func effect(at rank: Int) -> String {
        let value = perRank * Double(rank)
        let key = "talent.\(id.rawValue).text"
        switch unit {
        case .flag: return tr(key)
        case .percent: return tr(key, Fmt.pct(value))
        case .flat: return tr(key, Int(value))
        }
    }

    static let table: [TalentID: TalentSpec] = {
        let list: [TalentSpec] = [
            // Добыча
            TalentSpec(id: .power, branch: .mining, emoji: "💪", maxRank: 5, tier: 0, column: 1,
                       parents: [], perRank: 0.12, unit: .percent),
            TalentSpec(id: .lumberjack, branch: .mining, emoji: "🪓", maxRank: 3, tier: 1, column: 0,
                       parents: [.power], perRank: 0.2, unit: .percent),
            TalentSpec(id: .miner, branch: .mining, emoji: "⛏️", maxRank: 3, tier: 1, column: 2,
                       parents: [.power], perRank: 0.2, unit: .percent),
            TalentSpec(id: .quickHands, branch: .mining, emoji: "⚡", maxRank: 5, tier: 2, column: 1,
                       parents: [.power], perRank: 0.07, unit: .percent),
            TalentSpec(id: .crit, branch: .mining, emoji: "🎯", maxRank: 4, tier: 3, column: 0,
                       parents: [.lumberjack], perRank: 0.05, unit: .percent),
            TalentSpec(id: .shatter, branch: .mining, emoji: "💥", maxRank: 3, tier: 3, column: 2,
                       parents: [.miner], perRank: 0.04, unit: .percent),
            TalentSpec(id: .critPower, branch: .mining, emoji: "🔥", maxRank: 3, tier: 4, column: 0,
                       parents: [.crit], perRank: 0.3, unit: .percent),
            TalentSpec(id: .strongHands, branch: .mining, emoji: "✊", maxRank: 3, tier: 4, column: 2,
                       parents: [.shatter], perRank: 0.4, unit: .percent),
            TalentSpec(id: .quake, branch: .mining, emoji: "🌋", maxRank: 1, tier: 5, column: 1,
                       parents: [.quickHands], perRank: 1, unit: .flag),
            // Сбор
            TalentSpec(id: .bounty, branch: .gathering, emoji: "🧺", maxRank: 5, tier: 0, column: 1,
                       parents: [], perRank: 0.1, unit: .percent),
            TalentSpec(id: .regrowth, branch: .gathering, emoji: "🌱", maxRank: 5, tier: 1, column: 0,
                       parents: [.bounty], perRank: 0.08, unit: .percent),
            TalentSpec(id: .scholar, branch: .gathering, emoji: "📚", maxRank: 5, tier: 1, column: 2,
                       parents: [.bounty], perRank: 0.1, unit: .percent),
            TalentSpec(id: .doubleDrop, branch: .gathering, emoji: "🎲", maxRank: 4, tier: 2, column: 1,
                       parents: [.bounty], perRank: 0.05, unit: .percent),
            TalentSpec(id: .farmer, branch: .gathering, emoji: "🌾", maxRank: 3, tier: 3, column: 0,
                       parents: [.regrowth], perRank: 0.2, unit: .percent),
            TalentSpec(id: .trader, branch: .gathering, emoji: "💰", maxRank: 5, tier: 3, column: 2,
                       parents: [.scholar], perRank: 0.08, unit: .percent),
            TalentSpec(id: .gardener, branch: .gathering, emoji: "🪴", maxRank: 3, tier: 4, column: 0,
                       parents: [.farmer], perRank: 0.06, unit: .percent),
            TalentSpec(id: .gemFinder, branch: .gathering, emoji: "💎", maxRank: 3, tier: 4, column: 2,
                       parents: [.trader], perRank: 0.015, unit: .percent),
            TalentSpec(id: .goldenTouch, branch: .gathering, emoji: "👑", maxRank: 1, tier: 5, column: 1,
                       parents: [.doubleDrop], perRank: 1, unit: .flag),
            // Странник
            TalentSpec(id: .swift, branch: .travel, emoji: "👟", maxRank: 5, tier: 0, column: 1,
                       parents: [], perRank: 0.07, unit: .percent),
            TalentSpec(id: .bigPack, branch: .travel, emoji: "🎒", maxRank: 5, tier: 1, column: 0,
                       parents: [.swift], perRank: 15, unit: .flat),
            TalentSpec(id: .reach, branch: .travel, emoji: "🤲", maxRank: 3, tier: 1, column: 2,
                       parents: [.swift], perRank: 0.12, unit: .percent),
            TalentSpec(id: .tamer, branch: .travel, emoji: "🪢", maxRank: 3, tier: 2, column: 1,
                       parents: [.swift], perRank: 0.15, unit: .percent),
            TalentSpec(id: .beastBond, branch: .travel, emoji: "❤️", maxRank: 4, tier: 3, column: 0,
                       parents: [.bigPack], perRank: 0.12, unit: .percent),
            TalentSpec(id: .packLeader, branch: .travel, emoji: "🐺", maxRank: 4, tier: 3, column: 2,
                       parents: [.reach], perRank: 0.25, unit: .percent),
            TalentSpec(id: .thrift, branch: .travel, emoji: "🏷️", maxRank: 3, tier: 4, column: 0,
                       parents: [.beastBond], perRank: 0.07, unit: .percent),
            TalentSpec(id: .nightShift, branch: .travel, emoji: "🌙", maxRank: 3, tier: 4, column: 2,
                       parents: [.packLeader], perRank: 0.2, unit: .percent),
            TalentSpec(id: .portal, branch: .travel, emoji: "🌀", maxRank: 1, tier: 5, column: 1,
                       parents: [.tamer], perRank: 1, unit: .flag),
            // Добыча, поздние ряды
            TalentSpec(id: .doubleStrike, branch: .mining, emoji: "⚔️", maxRank: 4, tier: 6, column: 0,
                       parents: [.critPower], perRank: 0.05, unit: .percent),
            TalentSpec(id: .shockwave, branch: .mining, emoji: "🌊", maxRank: 3, tier: 6, column: 1,
                       parents: [.quake], perRank: 0.25, unit: .percent),
            TalentSpec(id: .oreHunter, branch: .mining, emoji: "🪙", maxRank: 4, tier: 6, column: 2,
                       parents: [.strongHands], perRank: 0.1, unit: .percent),
            TalentSpec(id: .execute, branch: .mining, emoji: "🗡️", maxRank: 3, tier: 7, column: 0,
                       parents: [.doubleStrike], perRank: 0.06, unit: .percent),
            TalentSpec(id: .crusher, branch: .mining, emoji: "🔨", maxRank: 3, tier: 7, column: 1,
                       parents: [.shockwave], perRank: 0.15, unit: .percent),
            TalentSpec(id: .tireless, branch: .mining, emoji: "🔋", maxRank: 4, tier: 7, column: 2,
                       parents: [.oreHunter], perRank: 0.05, unit: .percent),
            TalentSpec(id: .toolMaster, branch: .mining, emoji: "🏆", maxRank: 1, tier: 8, column: 1,
                       parents: [.crusher], perRank: 1, unit: .flag),
            // Сбор, поздние ряды
            TalentSpec(id: .finder, branch: .gathering, emoji: "🔍", maxRank: 4, tier: 6, column: 0,
                       parents: [.gardener], perRank: 0.04, unit: .percent),
            TalentSpec(id: .goldRush, branch: .gathering, emoji: "🤑", maxRank: 3, tier: 6, column: 1,
                       parents: [.goldenTouch], perRank: 0.5, unit: .percent),
            TalentSpec(id: .jeweler, branch: .gathering, emoji: "💍", maxRank: 3, tier: 6, column: 2,
                       parents: [.gemFinder], perRank: 0.15, unit: .percent),
            TalentSpec(id: .fertile, branch: .gathering, emoji: "🌻", maxRank: 5, tier: 7, column: 0,
                       parents: [.finder], perRank: 0.06, unit: .percent),
            TalentSpec(id: .triple, branch: .gathering, emoji: "🎰", maxRank: 3, tier: 7, column: 1,
                       parents: [.goldRush], perRank: 0.03, unit: .percent),
            TalentSpec(id: .sage, branch: .gathering, emoji: "🦉", maxRank: 5, tier: 7, column: 2,
                       parents: [.jeweler], perRank: 0.06, unit: .percent),
            TalentSpec(id: .abundance, branch: .gathering, emoji: "🌈", maxRank: 1, tier: 8, column: 1,
                       parents: [.triple], perRank: 1, unit: .flag),
            // Странник, поздние ряды
            TalentSpec(id: .packMaster, branch: .travel, emoji: "🧳", maxRank: 4, tier: 6, column: 0,
                       parents: [.thrift], perRank: 0.1, unit: .percent),
            TalentSpec(id: .tailwind, branch: .travel, emoji: "🍃", maxRank: 4, tier: 6, column: 1,
                       parents: [.portal], perRank: 0.05, unit: .percent),
            TalentSpec(id: .depotReach, branch: .travel, emoji: "📦", maxRank: 3, tier: 6, column: 2,
                       parents: [.nightShift], perRank: 0.3, unit: .percent),
            TalentSpec(id: .bargain, branch: .travel, emoji: "🤝", maxRank: 3, tier: 7, column: 0,
                       parents: [.packMaster], perRank: 0.08, unit: .percent),
            TalentSpec(id: .tracker, branch: .travel, emoji: "🧭", maxRank: 3, tier: 7, column: 1,
                       parents: [.tailwind], perRank: 0.2, unit: .percent),
            TalentSpec(id: .storekeeper, branch: .travel, emoji: "📋", maxRank: 3, tier: 7, column: 2,
                       parents: [.depotReach], perRank: 1, unit: .flat),
            TalentSpec(id: .strider, branch: .travel, emoji: "🚀", maxRank: 1, tier: 8, column: 1,
                       parents: [.tracker], perRank: 1, unit: .flag),
            // Звери
            TalentSpec(id: .animalFriend, branch: .beasts, emoji: "🤗", maxRank: 5, tier: 0, column: 1,
                       parents: [], perRank: 0.05, unit: .percent),
            TalentSpec(id: .training, branch: .beasts, emoji: "🎾", maxRank: 5, tier: 1, column: 0,
                       parents: [.animalFriend], perRank: 0.08, unit: .percent),
            TalentSpec(id: .rancher, branch: .beasts, emoji: "🧑‍🌾", maxRank: 5, tier: 1, column: 2,
                       parents: [.animalFriend], perRank: 0.08, unit: .percent),
            TalentSpec(id: .keenEye, branch: .beasts, emoji: "👀", maxRank: 3, tier: 2, column: 1,
                       parents: [.animalFriend], perRank: 0.2, unit: .percent),
            TalentSpec(id: .packTier, branch: .beasts, emoji: "🐺", maxRank: 2, tier: 3, column: 0,
                       parents: [.training], perRank: 1, unit: .flat),
            TalentSpec(id: .pasture, branch: .beasts, emoji: "🏡", maxRank: 3, tier: 3, column: 2,
                       parents: [.rancher], perRank: 2, unit: .flat),
            TalentSpec(id: .starFood, branch: .beasts, emoji: "⭐", maxRank: 4, tier: 4, column: 1,
                       parents: [.keenEye], perRank: 0.05, unit: .percent),
            TalentSpec(id: .beastLoot, branch: .beasts, emoji: "🦴", maxRank: 4, tier: 5, column: 0,
                       parents: [.packTier], perRank: 0.15, unit: .percent),
            TalentSpec(id: .catcher, branch: .beasts, emoji: "🪤", maxRank: 3, tier: 5, column: 2,
                       parents: [.pasture], perRank: 0.1, unit: .percent),
            TalentSpec(id: .alpha, branch: .beasts, emoji: "🦁", maxRank: 5, tier: 6, column: 1,
                       parents: [.starFood], perRank: 0.1, unit: .percent),
            TalentSpec(id: .herdsman, branch: .beasts, emoji: "🐑", maxRank: 3, tier: 7, column: 0,
                       parents: [.beastLoot], perRank: 0.1, unit: .percent),
            TalentSpec(id: .starHunter, branch: .beasts, emoji: "🌠", maxRank: 3, tier: 7, column: 2,
                       parents: [.catcher], perRank: 0.15, unit: .percent),
            TalentSpec(id: .soul, branch: .beasts, emoji: "💞", maxRank: 1, tier: 8, column: 1,
                       parents: [.alpha], perRank: 1, unit: .flag)
        ]
        var dict: [TalentID: TalentSpec] = [:]
        for spec in list { dict[spec.id] = spec }
        return dict
    }()
}
