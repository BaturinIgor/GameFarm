import SwiftUI

enum TalentBranch: String, CaseIterable, Identifiable {
    case mining, gathering, travel, beasts, farming, combat

    var id: String { rawValue }

    var title: String { tr("branch.\(rawValue)") }

    /// Пиксельная иконка ветки.
    var icon: String {
        switch self {
        case .mining: "tool_pickaxe"
        case .gathering: "basket"
        case .travel: "boots"
        case .beasts: "paw"
        case .farming: "watering_can"
        case .combat: "sword"
        }
    }

    var color: Color {
        switch self {
        case .mining: Color(red: 0.95, green: 0.45, blue: 0.25)
        case .gathering: Color(red: 0.3, green: 0.75, blue: 0.35)
        case .travel: Color(red: 0.3, green: 0.6, blue: 1.0)
        case .beasts: Color(red: 0.9, green: 0.4, blue: 0.75)
        case .farming: Color(red: 0.85, green: 0.65, blue: 0.15)
        case .combat: Color(red: 0.85, green: 0.25, blue: 0.3)
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
    // Огород
    case greenThumb, bigHarvest, seedSaver, rainmaker, composter, chef, quickCook, marketDay, goldenHarvest
    case deepRoots, seedTrader, harvestMoon
    // Бой
    case toughness, bladeMaster, stance, vampirism, evasion, alchemist, berserk, bossSlayer, lastStand
    case delver, regen, warlord
    // Суперталанты и ряды за ними
    case titan, keenEdge, mountainBreaker, motherlode
    case cornucopia, fortune, forager, enlightened
    case windwalker, haggler, pathfinder, hauler
    case beastLord, herd, packHunt, kinship
    case landlord, richSoil, gourmet, fairTrade
    case champion, fortress, executioner, bloodlust

    var id: String { rawValue }
    var spec: TalentSpec { TalentSpec.table[self]! }
}

struct TalentSpec {
    enum Unit { case percent, flat, flag }

    let id: TalentID
    let branch: TalentBranch
    let icon: String
    let maxRank: Int
    let tier: Int
    let column: Int
    let parents: [TalentID]
    let perRank: Double
    let unit: Unit
    /// Сколько очков стоит один ранг. У суперталантов больше одного.
    var cost: Int = 1

    var name: String { tr("talent.\(id.rawValue)") }

    /// Суперталант: дорогой, открывается, только когда родители прокачаны до максимума,
    /// и ведёт к следующему ряду ветки.
    var isSuper: Bool { cost > 1 }

    /// Уровень персонажа, с которого открывается ряд дерева.
    static let tierLevels = [1, 3, 6, 10, 15, 21, 28, 35, 42, 48, 55]

    static let superCost = 3

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
            TalentSpec(id: .power, branch: .mining, icon: "fist", maxRank: 8, tier: 0, column: 1,
                       parents: [], perRank: 0.12, unit: .percent),
            TalentSpec(id: .lumberjack, branch: .mining, icon: "tool_axe", maxRank: 3, tier: 1, column: 0,
                       parents: [.power], perRank: 0.2, unit: .percent),
            TalentSpec(id: .miner, branch: .mining, icon: "tool_pickaxe", maxRank: 3, tier: 1, column: 2,
                       parents: [.power], perRank: 0.2, unit: .percent),
            TalentSpec(id: .quickHands, branch: .mining, icon: "bolt", maxRank: 5, tier: 2, column: 1,
                       parents: [.power], perRank: 0.07, unit: .percent),
            TalentSpec(id: .crit, branch: .mining, icon: "target", maxRank: 4, tier: 3, column: 0,
                       parents: [.lumberjack], perRank: 0.05, unit: .percent),
            TalentSpec(id: .shatter, branch: .mining, icon: "shards", maxRank: 3, tier: 3, column: 2,
                       parents: [.miner], perRank: 0.04, unit: .percent),
            TalentSpec(id: .critPower, branch: .mining, icon: "flame", maxRank: 3, tier: 4, column: 0,
                       parents: [.crit], perRank: 0.3, unit: .percent),
            TalentSpec(id: .strongHands, branch: .mining, icon: "hammer", maxRank: 3, tier: 4, column: 2,
                       parents: [.shatter], perRank: 0.4, unit: .percent),
            TalentSpec(id: .quake, branch: .mining, icon: "quake", maxRank: 1, tier: 5, column: 1,
                       parents: [.quickHands], perRank: 1, unit: .flag),
            // Сбор
            TalentSpec(id: .bounty, branch: .gathering, icon: "basket", maxRank: 8, tier: 0, column: 1,
                       parents: [], perRank: 0.1, unit: .percent),
            TalentSpec(id: .regrowth, branch: .gathering, icon: "sprout", maxRank: 5, tier: 1, column: 0,
                       parents: [.bounty], perRank: 0.08, unit: .percent),
            TalentSpec(id: .scholar, branch: .gathering, icon: "book", maxRank: 5, tier: 1, column: 2,
                       parents: [.bounty], perRank: 0.1, unit: .percent),
            TalentSpec(id: .doubleDrop, branch: .gathering, icon: "dice", maxRank: 4, tier: 2, column: 1,
                       parents: [.bounty], perRank: 0.05, unit: .percent),
            TalentSpec(id: .farmer, branch: .gathering, icon: "wheat", maxRank: 3, tier: 3, column: 0,
                       parents: [.regrowth], perRank: 0.2, unit: .percent),
            TalentSpec(id: .trader, branch: .gathering, icon: "coins", maxRank: 5, tier: 3, column: 2,
                       parents: [.scholar], perRank: 0.08, unit: .percent),
            TalentSpec(id: .gardener, branch: .gathering, icon: "sunflower", maxRank: 3, tier: 4, column: 0,
                       parents: [.farmer], perRank: 0.06, unit: .percent),
            TalentSpec(id: .gemFinder, branch: .gathering, icon: "diamond", maxRank: 3, tier: 4, column: 2,
                       parents: [.trader], perRank: 0.015, unit: .percent),
            TalentSpec(id: .goldenTouch, branch: .gathering, icon: "goldenApple", maxRank: 1, tier: 5, column: 1,
                       parents: [.doubleDrop], perRank: 1, unit: .flag),
            // Странник
            TalentSpec(id: .swift, branch: .travel, icon: "boots", maxRank: 7, tier: 0, column: 1,
                       parents: [], perRank: 0.07, unit: .percent),
            TalentSpec(id: .bigPack, branch: .travel, icon: "bag", maxRank: 5, tier: 1, column: 0,
                       parents: [.swift], perRank: 15, unit: .flat),
            TalentSpec(id: .reach, branch: .travel, icon: "magnet", maxRank: 3, tier: 1, column: 2,
                       parents: [.swift], perRank: 0.12, unit: .percent),
            TalentSpec(id: .tamer, branch: .travel, icon: "lasso", maxRank: 3, tier: 2, column: 1,
                       parents: [.swift], perRank: 0.15, unit: .percent),
            TalentSpec(id: .beastBond, branch: .travel, icon: "heart", maxRank: 4, tier: 3, column: 0,
                       parents: [.bigPack], perRank: 0.12, unit: .percent),
            TalentSpec(id: .packLeader, branch: .travel, icon: "paw", maxRank: 4, tier: 3, column: 2,
                       parents: [.reach], perRank: 0.25, unit: .percent),
            TalentSpec(id: .thrift, branch: .travel, icon: "tag", maxRank: 3, tier: 4, column: 0,
                       parents: [.beastBond], perRank: 0.07, unit: .percent),
            TalentSpec(id: .nightShift, branch: .travel, icon: "moon", maxRank: 3, tier: 4, column: 2,
                       parents: [.packLeader], perRank: 0.2, unit: .percent),
            TalentSpec(id: .portal, branch: .travel, icon: "portal", maxRank: 1, tier: 5, column: 1,
                       parents: [.tamer], perRank: 1, unit: .flag),
            // Добыча, поздние ряды
            TalentSpec(id: .doubleStrike, branch: .mining, icon: "swords", maxRank: 4, tier: 6, column: 0,
                       parents: [.critPower], perRank: 0.05, unit: .percent),
            TalentSpec(id: .shockwave, branch: .mining, icon: "wave", maxRank: 3, tier: 6, column: 1,
                       parents: [.quake], perRank: 0.25, unit: .percent),
            TalentSpec(id: .oreHunter, branch: .mining, icon: "gold", maxRank: 4, tier: 6, column: 2,
                       parents: [.strongHands], perRank: 0.1, unit: .percent),
            TalentSpec(id: .execute, branch: .mining, icon: "skull", maxRank: 3, tier: 7, column: 0,
                       parents: [.doubleStrike], perRank: 0.06, unit: .percent),
            TalentSpec(id: .crusher, branch: .mining, icon: "tool_hammer", maxRank: 3, tier: 7, column: 1,
                       parents: [.shockwave], perRank: 0.15, unit: .percent),
            TalentSpec(id: .tireless, branch: .mining, icon: "hourglass", maxRank: 4, tier: 7, column: 2,
                       parents: [.oreHunter], perRank: 0.05, unit: .percent),
            TalentSpec(id: .toolMaster, branch: .mining, icon: "trophy", maxRank: 1, tier: 8, column: 1,
                       parents: [.crusher], perRank: 1, unit: .flag),
            // Сбор, поздние ряды
            TalentSpec(id: .finder, branch: .gathering, icon: "magnifier", maxRank: 4, tier: 6, column: 0,
                       parents: [.gardener], perRank: 0.04, unit: .percent),
            TalentSpec(id: .goldRush, branch: .gathering, icon: "chest_gold", maxRank: 3, tier: 6, column: 1,
                       parents: [.goldenTouch], perRank: 0.5, unit: .percent),
            TalentSpec(id: .jeweler, branch: .gathering, icon: "ruby", maxRank: 3, tier: 6, column: 2,
                       parents: [.gemFinder], perRank: 0.15, unit: .percent),
            TalentSpec(id: .fertile, branch: .gathering, icon: "berries", maxRank: 5, tier: 7, column: 0,
                       parents: [.finder], perRank: 0.06, unit: .percent),
            TalentSpec(id: .triple, branch: .gathering, icon: "clover", maxRank: 3, tier: 7, column: 1,
                       parents: [.goldRush], perRank: 0.03, unit: .percent),
            TalentSpec(id: .sage, branch: .gathering, icon: "owl", maxRank: 5, tier: 7, column: 2,
                       parents: [.jeweler], perRank: 0.06, unit: .percent),
            TalentSpec(id: .abundance, branch: .gathering, icon: "rainbow", maxRank: 1, tier: 8, column: 1,
                       parents: [.triple], perRank: 1, unit: .flag),
            // Странник, поздние ряды
            TalentSpec(id: .packMaster, branch: .travel, icon: "chest", maxRank: 4, tier: 6, column: 0,
                       parents: [.thrift], perRank: 0.1, unit: .percent),
            TalentSpec(id: .tailwind, branch: .travel, icon: "wind", maxRank: 4, tier: 6, column: 1,
                       parents: [.portal], perRank: 0.05, unit: .percent),
            TalentSpec(id: .depotReach, branch: .travel, icon: "map", maxRank: 3, tier: 6, column: 2,
                       parents: [.nightShift], perRank: 0.3, unit: .percent),
            TalentSpec(id: .bargain, branch: .travel, icon: "moneybag", maxRank: 3, tier: 7, column: 0,
                       parents: [.packMaster], perRank: 0.08, unit: .percent),
            TalentSpec(id: .tracker, branch: .travel, icon: "compass", maxRank: 3, tier: 7, column: 1,
                       parents: [.tailwind], perRank: 0.2, unit: .percent),
            TalentSpec(id: .storekeeper, branch: .travel, icon: "plan", maxRank: 3, tier: 7, column: 2,
                       parents: [.depotReach], perRank: 1, unit: .flat),
            TalentSpec(id: .strider, branch: .travel, icon: "wing", maxRank: 1, tier: 8, column: 1,
                       parents: [.tracker], perRank: 1, unit: .flag),
            // Звери
            TalentSpec(id: .animalFriend, branch: .beasts, icon: "heart_plus", maxRank: 8, tier: 0, column: 1,
                       parents: [], perRank: 0.05, unit: .percent),
            TalentSpec(id: .training, branch: .beasts, icon: "ball", maxRank: 5, tier: 1, column: 0,
                       parents: [.animalFriend], perRank: 0.08, unit: .percent),
            TalentSpec(id: .rancher, branch: .beasts, icon: "milk", maxRank: 5, tier: 1, column: 2,
                       parents: [.animalFriend], perRank: 0.08, unit: .percent),
            TalentSpec(id: .keenEye, branch: .beasts, icon: "eye", maxRank: 3, tier: 2, column: 1,
                       parents: [.animalFriend], perRank: 0.2, unit: .percent),
            TalentSpec(id: .packTier, branch: .beasts, icon: "paw", maxRank: 2, tier: 3, column: 0,
                       parents: [.training], perRank: 1, unit: .flat),
            TalentSpec(id: .pasture, branch: .beasts, icon: "pen", maxRank: 3, tier: 3, column: 2,
                       parents: [.rancher], perRank: 2, unit: .flat),
            TalentSpec(id: .starFood, branch: .beasts, icon: "star", maxRank: 4, tier: 4, column: 1,
                       parents: [.keenEye], perRank: 0.05, unit: .percent),
            TalentSpec(id: .beastLoot, branch: .beasts, icon: "bone", maxRank: 4, tier: 5, column: 0,
                       parents: [.packTier], perRank: 0.15, unit: .percent),
            TalentSpec(id: .catcher, branch: .beasts, icon: "net", maxRank: 3, tier: 5, column: 2,
                       parents: [.pasture], perRank: 0.1, unit: .percent),
            TalentSpec(id: .alpha, branch: .beasts, icon: "crown", maxRank: 5, tier: 6, column: 1,
                       parents: [.starFood], perRank: 0.1, unit: .percent),
            TalentSpec(id: .herdsman, branch: .beasts, icon: "wool", maxRank: 3, tier: 7, column: 0,
                       parents: [.beastLoot], perRank: 0.1, unit: .percent),
            TalentSpec(id: .starHunter, branch: .beasts, icon: "stardust", maxRank: 3, tier: 7, column: 2,
                       parents: [.catcher], perRank: 0.15, unit: .percent),
            TalentSpec(id: .soul, branch: .beasts, icon: "spark", maxRank: 1, tier: 8, column: 1,
                       parents: [.alpha], perRank: 1, unit: .flag)            ,
            // Огород
            TalentSpec(id: .greenThumb, branch: .farming, icon: "sprout", maxRank: 5, tier: 0, column: 1,
                       parents: [], perRank: 0.06, unit: .percent),
            TalentSpec(id: .bigHarvest, branch: .farming, icon: "pumpkin", maxRank: 3, tier: 1, column: 0,
                       parents: [.greenThumb], perRank: 0.12, unit: .percent),
            TalentSpec(id: .seedSaver, branch: .farming, icon: "seed_sunflower", maxRank: 5, tier: 1, column: 2,
                       parents: [.greenThumb], perRank: 0.08, unit: .percent),
            TalentSpec(id: .rainmaker, branch: .farming, icon: "watering_can", maxRank: 3, tier: 2, column: 1,
                       parents: [.greenThumb], perRank: 0.15, unit: .percent),
            TalentSpec(id: .composter, branch: .farming, icon: "compost", maxRank: 3, tier: 3, column: 0,
                       parents: [.bigHarvest], perRank: 0.12, unit: .percent),
            TalentSpec(id: .chef, branch: .farming, icon: "dish_stew", maxRank: 4, tier: 3, column: 2,
                       parents: [.seedSaver], perRank: 0.15, unit: .percent),
            TalentSpec(id: .quickCook, branch: .farming, icon: "stopwatch", maxRank: 3, tier: 4, column: 0,
                       parents: [.composter], perRank: 0.1, unit: .percent),
            TalentSpec(id: .marketDay, branch: .farming, icon: "moneybag", maxRank: 4, tier: 4, column: 2,
                       parents: [.chef], perRank: 0.1, unit: .percent),
            TalentSpec(id: .goldenHarvest, branch: .farming, icon: "goldenApple", maxRank: 1, tier: 5, column: 1,
                       parents: [.rainmaker], perRank: 1, unit: .flag),
            TalentSpec(id: .deepRoots, branch: .farming, icon: "fert_magic", maxRank: 2, tier: 6, column: 0,
                       parents: [.quickCook], perRank: 1, unit: .flat),
            TalentSpec(id: .seedTrader, branch: .farming, icon: "tag", maxRank: 3, tier: 6, column: 2,
                       parents: [.marketDay], perRank: 0.1, unit: .percent),
            TalentSpec(id: .harvestMoon, branch: .farming, icon: "moon", maxRank: 1, tier: 7, column: 1,
                       parents: [.goldenHarvest], perRank: 1, unit: .flag),
            // Бой
            TalentSpec(id: .toughness, branch: .combat, icon: "heart", maxRank: 5, tier: 0, column: 1,
                       parents: [], perRank: 0.08, unit: .percent),
            TalentSpec(id: .bladeMaster, branch: .combat, icon: "sword", maxRank: 5, tier: 1, column: 0,
                       parents: [.toughness], perRank: 0.07, unit: .percent),
            TalentSpec(id: .stance, branch: .combat, icon: "shield", maxRank: 4, tier: 1, column: 2,
                       parents: [.toughness], perRank: 0.03, unit: .percent),
            TalentSpec(id: .vampirism, branch: .combat, icon: "fang", maxRank: 3, tier: 2, column: 1,
                       parents: [.toughness], perRank: 0.02, unit: .percent),
            TalentSpec(id: .evasion, branch: .combat, icon: "wind", maxRank: 4, tier: 3, column: 0,
                       parents: [.bladeMaster], perRank: 0.02, unit: .percent),
            TalentSpec(id: .alchemist, branch: .combat, icon: "potion", maxRank: 3, tier: 3, column: 2,
                       parents: [.stance], perRank: 0.1, unit: .percent),
            TalentSpec(id: .berserk, branch: .combat, icon: "flame", maxRank: 3, tier: 4, column: 0,
                       parents: [.evasion], perRank: 0.12, unit: .percent),
            TalentSpec(id: .bossSlayer, branch: .combat, icon: "skull", maxRank: 4, tier: 4, column: 2,
                       parents: [.alchemist], perRank: 0.08, unit: .percent),
            TalentSpec(id: .lastStand, branch: .combat, icon: "heart_shield", maxRank: 1, tier: 5, column: 1,
                       parents: [.vampirism], perRank: 1, unit: .flag),
            TalentSpec(id: .delver, branch: .combat, icon: "key", maxRank: 3, tier: 6, column: 0,
                       parents: [.berserk], perRank: 0.1, unit: .percent),
            TalentSpec(id: .regen, branch: .combat, icon: "heart_plus", maxRank: 3, tier: 6, column: 2,
                       parents: [.bossSlayer], perRank: 0.005, unit: .percent),
            TalentSpec(id: .warlord, branch: .combat, icon: "crown", maxRank: 1, tier: 7, column: 1,
                       parents: [.lastStand], perRank: 1, unit: .flag),

            // Суперталанты: родители должны быть прокачаны до максимума
            TalentSpec(id: .titan, branch: .mining, icon: "super_titan", maxRank: 1, tier: 9, column: 1,
                       parents: [.execute, .toolMaster, .tireless], perRank: 1, unit: .flag, cost: superCost),
            TalentSpec(id: .keenEdge, branch: .mining, icon: "flame", maxRank: 3, tier: 10, column: 0,
                       parents: [.titan], perRank: 0.25, unit: .percent),
            TalentSpec(id: .mountainBreaker, branch: .mining, icon: "tool_hammer", maxRank: 3, tier: 10, column: 1,
                       parents: [.titan], perRank: 0.1, unit: .percent),
            TalentSpec(id: .motherlode, branch: .mining, icon: "gold", maxRank: 3, tier: 10, column: 2,
                       parents: [.titan], perRank: 0.12, unit: .percent),

            TalentSpec(id: .cornucopia, branch: .gathering, icon: "super_cornucopia", maxRank: 1, tier: 9, column: 1,
                       parents: [.fertile, .abundance, .sage], perRank: 1, unit: .flag, cost: superCost),
            TalentSpec(id: .fortune, branch: .gathering, icon: "clover", maxRank: 3, tier: 10, column: 0,
                       parents: [.cornucopia], perRank: 0.02, unit: .percent),
            TalentSpec(id: .forager, branch: .gathering, icon: "berries", maxRank: 3, tier: 10, column: 1,
                       parents: [.cornucopia], perRank: 0.12, unit: .percent),
            TalentSpec(id: .enlightened, branch: .gathering, icon: "book", maxRank: 3, tier: 10, column: 2,
                       parents: [.cornucopia], perRank: 0.08, unit: .percent),

            TalentSpec(id: .windwalker, branch: .travel, icon: "super_windwalker", maxRank: 1, tier: 9, column: 1,
                       parents: [.bargain, .strider, .storekeeper], perRank: 1, unit: .flag, cost: superCost),
            TalentSpec(id: .haggler, branch: .travel, icon: "coins", maxRank: 3, tier: 10, column: 0,
                       parents: [.windwalker], perRank: 0.06, unit: .percent),
            TalentSpec(id: .pathfinder, branch: .travel, icon: "compass", maxRank: 3, tier: 10, column: 1,
                       parents: [.windwalker], perRank: 0.12, unit: .percent),
            TalentSpec(id: .hauler, branch: .travel, icon: "bag", maxRank: 3, tier: 10, column: 2,
                       parents: [.windwalker], perRank: 0.08, unit: .percent),

            TalentSpec(id: .beastLord, branch: .beasts, icon: "super_beastLord", maxRank: 1, tier: 9, column: 1,
                       parents: [.herdsman, .soul, .starHunter], perRank: 1, unit: .flag, cost: superCost),
            TalentSpec(id: .herd, branch: .beasts, icon: "milk", maxRank: 3, tier: 10, column: 0,
                       parents: [.beastLord], perRank: 0.1, unit: .percent),
            TalentSpec(id: .packHunt, branch: .beasts, icon: "fang", maxRank: 3, tier: 10, column: 1,
                       parents: [.beastLord], perRank: 0.1, unit: .percent),
            TalentSpec(id: .kinship, branch: .beasts, icon: "heart", maxRank: 3, tier: 10, column: 2,
                       parents: [.beastLord], perRank: 0.05, unit: .percent),

            TalentSpec(id: .landlord, branch: .farming, icon: "super_landlord", maxRank: 1, tier: 8, column: 1,
                       parents: [.deepRoots, .harvestMoon, .seedTrader], perRank: 1, unit: .flag, cost: superCost),
            TalentSpec(id: .richSoil, branch: .farming, icon: "compost", maxRank: 3, tier: 9, column: 0,
                       parents: [.landlord], perRank: 0.12, unit: .percent),
            TalentSpec(id: .gourmet, branch: .farming, icon: "dish_stew", maxRank: 3, tier: 9, column: 1,
                       parents: [.landlord], perRank: 0.1, unit: .percent),
            TalentSpec(id: .fairTrade, branch: .farming, icon: "moneybag", maxRank: 3, tier: 9, column: 2,
                       parents: [.landlord], perRank: 0.1, unit: .percent),

            TalentSpec(id: .champion, branch: .combat, icon: "super_champion", maxRank: 1, tier: 8, column: 1,
                       parents: [.delver, .warlord, .regen], perRank: 1, unit: .flag, cost: superCost),
            TalentSpec(id: .fortress, branch: .combat, icon: "shield", maxRank: 3, tier: 9, column: 0,
                       parents: [.champion], perRank: 0.03, unit: .percent),
            TalentSpec(id: .executioner, branch: .combat, icon: "skull", maxRank: 3, tier: 9, column: 1,
                       parents: [.champion], perRank: 0.1, unit: .percent),
            TalentSpec(id: .bloodlust, branch: .combat, icon: "potion", maxRank: 3, tier: 9, column: 2,
                       parents: [.champion], perRank: 0.01, unit: .percent)
        ]
        var dict: [TalentID: TalentSpec] = [:]
        for spec in list { dict[spec.id] = spec }
        return dict
    }()
}
