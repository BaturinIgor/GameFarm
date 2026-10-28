import Foundation

enum GameRules {
    static let maxLevel = 60
    static let maxActiveAnimals = 5
    static let baseSpeed = 165.0
    static let baseReach: Double = 46

    static func xpToNext(_ level: Int) -> Int {
        Int((20 * pow(Double(level), 1.6)).rounded())
    }

    /// Очки талантов, полученные к уровню: по одному за уровень и бонусное каждые 10 уровней.
    static func talentPoints(at level: Int) -> Int {
        level + level / 10
    }

    static func capacity(at level: Int) -> Int {
        30 + 5 * level
    }

    static func levelCoinReward(_ level: Int) -> Int {
        25 * level
    }

    static func respecCost(_ level: Int) -> Int {
        50 * level
    }

    static func tameXP(_ level: Int) -> Int {
        10 + 2 * level
    }

    static func unlockXP(_ location: LocationID) -> Int {
        location.spec.level * 15
    }
}

struct UnlockLine: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
}

extension GameRules {
    /// Что даёт достижение уровня.
    static func rewards(at level: Int) -> [UnlockLine] {
        rewards(from: level - 1, to: level)
    }

    /// Награды за все уровни сразу, если игрок прыгнул через несколько.
    static func rewards(from: Int, to: Int) -> [UnlockLine] {
        var lines: [UnlockLine] = []
        let points = talentPoints(at: to) - talentPoints(at: from)
        let coins = to > from ? ((from + 1)...to).map(levelCoinReward).reduce(0, +) : 0
        lines.append(UnlockLine(icon: "🌟", text: tr("reward.talentPoints", points)))
        lines.append(UnlockLine(icon: "🪙", text: tr("reward.coins", Fmt.n(coins))))
        lines.append(UnlockLine(icon: "🎒", text: tr("reward.backpack")))
        lines.append(UnlockLine(icon: "💪", text: tr("reward.power")))
        return lines
    }

    /// Что открывается ровно на этом уровне.
    static func unlocks(at level: Int) -> [UnlockLine] {
        var lines: [UnlockLine] = []
        for id in LocationID.world where id.spec.level == level && level > 1 {
            lines.append(UnlockLine(icon: id.spec.emoji, text: tr("unlock.location", id.spec.name)))
        }
        for tool in ToolKind.upgradable {
            for tier in 2...ToolTier.maxTier where ToolTier.requiredLevel(tool, tier: tier) == level {
                lines.append(UnlockLine(icon: tool.emoji, text: tr("unlock.tool", ToolTier.name(tool, tier: tier))))
            }
        }
        for id in AnimalID.allCases {
            if case .shop(_, let need) = id.spec.source, need == level {
                lines.append(UnlockLine(icon: id.spec.emoji, text: tr("unlock.animal", id.spec.name)))
            }
        }
        if level > 1 && Garden.beds(at: level) > Garden.beds(at: level - 1) {
            lines.append(UnlockLine(icon: "🌱", text: tr("unlock.bed")))
        }
        for crop in CropID.allCases where crop.spec.level == level && level > 1 {
            lines.append(UnlockLine(icon: crop.spec.produce.emoji ?? "🌱", text: tr("unlock.seed", crop.name)))
        }
        if let tier = TalentSpec.tierLevels.firstIndex(of: level), tier > 0 {
            lines.append(UnlockLine(icon: "🌳", text: tr("unlock.talentRow", tier + 1)))
        }
        return lines
    }
}

struct Producer {
    let animal: AnimalID
    let kind: ResourceKind
    let interval: Double
}

struct Helper {
    let animal: AnimalID
    let spec: HelperSpec
    let damage: Double
}

/// Итоговые характеристики с учётом уровня, талантов, инструментов и животных.
struct Stats {
    var damageMult = 1.0
    var woodBonus = 0.0
    var stoneBonus = 0.0
    var highTierBonus = 0.0
    var handMult = 1.0
    var hitInterval = 0.55
    var critChance = 0.0
    var critMult = 2.0
    var shatterChance = 0.0
    var doubleStrikeChance = 0.0
    var executeThreshold = 0.0
    var quake = false
    var quakePower = 0.4
    var quakeRadius: Double = 110
    var toolBonus = 0
    var yieldAll = 0.0
    var yieldCategory: [ResourceCategory: Double] = [:]
    var yieldKind: [ResourceKind: Double] = [:]
    var doubleChance = 0.0
    var tripleChance = 0.0
    var finderChance = 0.0
    var respawnMult = 1.0
    var regrowChance = 0.0
    var xpMult = 1.0
    var sellMult = 1.0
    var sellCategory: [ResourceCategory: Double] = [:]
    var goldenTouch = false
    var goldMult = 1.0
    var gemChance = 0.0
    var speed = GameRules.baseSpeed
    var capacity = 35
    var reach: Double = GameRules.baseReach
    var depositRadius: Double = 92
    var tameMult = 1.0
    var shopMult = 1.0
    var spawnMult = 1.0
    var storekeeperXP = 0
    var helperMult = 1.0
    var helperSpeed = 1.0
    var helperRange: Double = 260
    var helperTierBonus = 0
    var helperYield = 1.0
    var producerMult = 1.0
    var doubleProductChance = 0.0
    var offlineHours = 6.0
    var starStep = 0.25
    var doubleStarChance = 0.0
    var discount = 1.0
    var autoDeposit = false
    var animalMult = 1.0
    var producers: [Producer] = []
    var helpers: [Helper] = []

    func yieldMultiplier(for kind: ResourceKind) -> Double {
        1 + yieldAll + (yieldCategory[kind.category] ?? 0) + (yieldKind[kind] ?? 0)
    }

    func starMultiplier(_ stars: Int) -> Double {
        AnimalSpec.starMultiplier(stars, step: starStep)
    }
}

struct Encounter: Equatable {
    let animal: AnimalID
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let icon: String
    let text: String
}

struct Treasure: Equatable {
    let coins: Int
    let items: [ResourceAmount]
}

struct LevelUpInfo: Equatable {
    let from: Int
    let to: Int
}

struct OfflineReport: Equatable {
    let duration: Double
    let items: [ResourceAmount]
    var doubled = false
}
