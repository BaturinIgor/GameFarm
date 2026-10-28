import UIKit

enum ToolKind: String, CaseIterable, Identifiable {
    case hand, axe, pickaxe, rod, sword, armor

    var id: String { rawValue }

    /// Инструменты добычи.
    static let gathering: [ToolKind] = [.axe, .pickaxe, .rod]
    static let upgradable: [ToolKind] = [.axe, .pickaxe, .rod, .sword, .armor]

    var emoji: String {
        switch self {
        case .hand: "✋"
        case .axe: "🪓"
        case .pickaxe: "⛏️"
        case .rod: "🎣"
        case .sword: "🗡️"
        case .armor: "🛡️"
        }
    }

    var title: String { tr("tool.\(rawValue)") }

    var purpose: String { tr("tool.\(rawValue).purpose") }
}

enum ToolTier {
    static let maxTier = 8

    /// Сила удара инструмента по ступеням.
    static func power(_ tier: Int) -> Double {
        let table: [Double] = [1, 1.8, 3, 4.6, 6.8, 10, 14.5, 21, 30]
        return table[max(0, min(table.count - 1, tier - 1))]
    }

    static func name(_ tool: ToolKind, tier: Int) -> String {
        tr("tool.\(tool.rawValue).\(max(1, min(maxTier, tier)))")
    }

    static func color(_ tier: Int) -> UIColor {
        switch tier {
        case 1: UIColor(red: 0.62, green: 0.42, blue: 0.24, alpha: 1)
        case 2: UIColor(red: 0.55, green: 0.57, blue: 0.6, alpha: 1)
        case 3: UIColor(red: 0.75, green: 0.78, blue: 0.84, alpha: 1)
        case 4: UIColor(red: 0.98, green: 0.78, blue: 0.2, alpha: 1)
        case 5: UIColor(red: 0.4, green: 0.88, blue: 1.0, alpha: 1)
        case 6: UIColor(red: 0.72, green: 0.45, blue: 1.0, alpha: 1)
        case 7: UIColor(red: 0.42, green: 0.24, blue: 0.6, alpha: 1)
        default: UIColor(red: 1.0, green: 0.93, blue: 0.55, alpha: 1)
        }
    }

    static func requiredLevel(_ tool: ToolKind, tier: Int) -> Int {
        let index = max(0, min(7, tier - 1))
        switch tool {
        case .rod: return [1, 11, 16, 24, 32, 40, 45, 52][index]
        default: return [1, 3, 7, 13, 20, 28, 43, 50][index]
        }
    }

    static func cost(_ tool: ToolKind, tier: Int) -> Cost {
        switch (tool, tier) {
        case (.axe, 2): Cost(coins: 40, (.wood, 40), (.stone, 20))
        case (.axe, 3): Cost(coins: 250, (.wood, 150), (.stone, 60), (.coal, 20))
        case (.axe, 4): Cost(coins: 1000, (.wood, 300), (.iron, 50), (.bamboo, 40))
        case (.axe, 5): Cost(coins: 4000, (.wood, 600), (.gold, 30), (.cactus, 40))
        case (.axe, 6): Cost(coins: 12000, (.wood, 1200), (.diamond, 8), (.ice, 60))
        case (.axe, 7): Cost(coins: 30000, (.wood, 2000), (.sulfur, 40), (.pearl, 10))
        case (.axe, 8): Cost(coins: 80000, (.wood, 4000), (.obsidian, 60), (.ruby, 10))
        case (.pickaxe, 2): Cost(coins: 40, (.wood, 25), (.stone, 40))
        case (.pickaxe, 3): Cost(coins: 250, (.stone, 150), (.coal, 30))
        case (.pickaxe, 4): Cost(coins: 1000, (.stone, 300), (.iron, 60), (.coal, 60))
        case (.pickaxe, 5): Cost(coins: 4000, (.iron, 150), (.gold, 40))
        case (.pickaxe, 6): Cost(coins: 12000, (.gold, 120), (.diamond, 12), (.ice, 80))
        case (.pickaxe, 7): Cost(coins: 30000, (.crystal, 30), (.sulfur, 60), (.coral, 30))
        case (.pickaxe, 8): Cost(coins: 80000, (.obsidian, 80), (.ruby, 20))
        case (.rod, 2): Cost(coins: 500, (.wood, 100), (.bamboo, 40), (.fish, 30))
        case (.rod, 3): Cost(coins: 1500, (.bamboo, 120), (.iron, 40), (.fish, 80))
        case (.rod, 4): Cost(coins: 5000, (.gold, 30), (.ice, 40), (.fish, 150))
        case (.rod, 5): Cost(coins: 12000, (.diamond, 6), (.fish, 300))
        case (.rod, 6): Cost(coins: 25000, (.crystal, 15), (.fish, 500))
        case (.rod, 7): Cost(coins: 40000, (.sulfur, 40), (.pearl, 20), (.fish, 800))
        case (.rod, 8): Cost(coins: 90000, (.ruby, 15), (.pearl, 40), (.fish, 1500))
        case (.sword, 2): Cost(coins: 60, (.wood, 30), (.slime, 8))
        case (.sword, 3): Cost(coins: 300, (.iron, 20), (.slime, 30))
        case (.sword, 4): Cost(coins: 1200, (.iron, 60), (.bone, 30))
        case (.sword, 5): Cost(coins: 4000, (.gold, 30), (.bone, 60))
        case (.sword, 6): Cost(coins: 12000, (.diamond, 6), (.slime, 150))
        case (.sword, 7): Cost(coins: 30000, (.obsidian, 30), (.bone, 200))
        case (.sword, 8): Cost(coins: 80000, (.ruby, 10), (.bone, 400))
        case (.armor, 2): Cost(coins: 80, (.wool, 6), (.slime, 8))
        case (.armor, 3): Cost(coins: 400, (.iron, 25), (.slime, 30))
        case (.armor, 4): Cost(coins: 1500, (.iron, 80), (.bone, 30))
        case (.armor, 5): Cost(coins: 5000, (.gold, 40), (.bone, 80))
        case (.armor, 6): Cost(coins: 14000, (.diamond, 8), (.slime, 200))
        case (.armor, 7): Cost(coins: 32000, (.obsidian, 40), (.bone, 250))
        case (.armor, 8): Cost(coins: 85000, (.ruby, 12), (.bone, 500))
        default: Cost()
        }
    }
}

/// Что именно можно добыть на точке.
struct NodeYield {
    let kind: ResourceKind
    let min: Int
    let max: Int
    var chance: Double = 1
}

enum NodeType: String, CaseIterable {
    case tree, pine, palm, snowPine, glowTree
    case bush, appleTree, mushroom, carrot, cactus, bamboo, glowShroom
    case rock, boulder, coalOre, ironOre, goldOre, iceBlock, diamondOre, crystalOre
    case fishSpot, oasisFish, iceHole
    // Болото
    case willow, herbPatch, clayPit, swampFish
    // Остров
    case bananaPalm, pineapple, shells, oyster, coral
    // Вулкан
    case ashTree, fireFlower, sulfurVent, obsidianOre, rubyOre, lavaFish
    // Небесные острова
    case cloudBush, goldenTree, skyTree, starRock, starPond
    // Королевский сад и экспедиции
    case beehive, grapeVine, treasureChest
    // Ивенты
    case pumpkinPatch, giftBox, sandCastle, slimeCrystal

    var spec: NodeSpec { NodeSpec.table[self]! }
}

struct NodeSpec {
    let type: NodeType
    let tool: ToolKind
    let tier: Int
    let hp: Double
    let xp: Int
    let respawn: Double
    let yields: [NodeYield]
    /// Радиус для столкновений и дальности добычи.
    let radius: CGFloat
    /// Персонаж не может пройти сквозь точку.
    let blocking: Bool
    /// Точка остаётся препятствием и после добычи (яблоня без яблок).
    var keepsBody: Bool = false
    /// Высота полоски прочности над точкой.
    let barHeight: CGFloat
    let chip: UIColor

    var mainResource: ResourceKind { yields[0].kind }
    var name: String { tr("node.\(type.rawValue)") }

    static let table: [NodeType: NodeSpec] = {
        let brown = UIColor(red: 0.55, green: 0.36, blue: 0.2, alpha: 1)
        let green = UIColor(red: 0.3, green: 0.68, blue: 0.3, alpha: 1)
        let gray = UIColor(white: 0.6, alpha: 1)
        let water = UIColor(red: 0.55, green: 0.8, blue: 1, alpha: 1)
        let list: [NodeSpec] = [
            NodeSpec(type: .tree, tool: .axe, tier: 1, hp: 3, xp: 3, respawn: 8,
                     yields: [NodeYield(kind: .wood, min: 2, max: 3)], radius: 18, blocking: true, barHeight: 70, chip: brown),
            NodeSpec(type: .pine, tool: .axe, tier: 2, hp: 6, xp: 6, respawn: 11,
                     yields: [NodeYield(kind: .wood, min: 4, max: 5)], radius: 16, blocking: true, barHeight: 74, chip: brown),
            NodeSpec(type: .palm, tool: .axe, tier: 3, hp: 10, xp: 9, respawn: 14,
                     yields: [NodeYield(kind: .wood, min: 5, max: 6), NodeYield(kind: .coconut, min: 1, max: 2, chance: 0.7)],
                     radius: 16, blocking: true, barHeight: 76, chip: brown),
            NodeSpec(type: .snowPine, tool: .axe, tier: 4, hp: 17, xp: 14, respawn: 16,
                     yields: [NodeYield(kind: .wood, min: 8, max: 10)], radius: 18, blocking: true, barHeight: 78, chip: .white),
            NodeSpec(type: .glowTree, tool: .axe, tier: 5, hp: 26, xp: 22, respawn: 22,
                     yields: [NodeYield(kind: .wood, min: 12, max: 15), NodeYield(kind: .crystal, min: 1, max: 1, chance: 0.15)],
                     radius: 20, blocking: true, barHeight: 80, chip: UIColor(red: 0.75, green: 0.55, blue: 1, alpha: 1)),
            NodeSpec(type: .bush, tool: .hand, tier: 1, hp: 2, xp: 1, respawn: 7,
                     yields: [NodeYield(kind: .berries, min: 2, max: 3)], radius: 14, blocking: false, barHeight: 40,
                     chip: UIColor(red: 0.35, green: 0.4, blue: 0.85, alpha: 1)),
            NodeSpec(type: .appleTree, tool: .hand, tier: 1, hp: 3, xp: 2, respawn: 10,
                     yields: [NodeYield(kind: .apples, min: 2, max: 3)], radius: 18, blocking: true, keepsBody: true, barHeight: 70,
                     chip: UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1)),
            NodeSpec(type: .mushroom, tool: .hand, tier: 1, hp: 1, xp: 2, respawn: 8,
                     yields: [NodeYield(kind: .mushrooms, min: 1, max: 2)], radius: 10, blocking: false, barHeight: 34,
                     chip: UIColor(red: 0.85, green: 0.25, blue: 0.2, alpha: 1)),
            NodeSpec(type: .carrot, tool: .hand, tier: 1, hp: 2, xp: 3, respawn: 9,
                     yields: [NodeYield(kind: .carrots, min: 2, max: 3)], radius: 11, blocking: false, barHeight: 36,
                     chip: UIColor(red: 1, green: 0.55, blue: 0.1, alpha: 1)),
            NodeSpec(type: .cactus, tool: .axe, tier: 2, hp: 5, xp: 7, respawn: 12,
                     yields: [NodeYield(kind: .cactus, min: 2, max: 3)], radius: 14, blocking: true, barHeight: 56, chip: green),
            NodeSpec(type: .bamboo, tool: .axe, tier: 2, hp: 5, xp: 5, respawn: 10,
                     yields: [NodeYield(kind: .bamboo, min: 3, max: 4)], radius: 14, blocking: true, barHeight: 62, chip: green),
            NodeSpec(type: .glowShroom, tool: .hand, tier: 1, hp: 4, xp: 10, respawn: 14,
                     yields: [NodeYield(kind: .mushrooms, min: 4, max: 6)], radius: 12, blocking: false, barHeight: 40,
                     chip: UIColor(red: 0.4, green: 0.95, blue: 1, alpha: 1)),
            NodeSpec(type: .rock, tool: .pickaxe, tier: 1, hp: 4, xp: 3, respawn: 9,
                     yields: [NodeYield(kind: .stone, min: 2, max: 3)], radius: 16, blocking: true, barHeight: 44, chip: gray),
            NodeSpec(type: .boulder, tool: .pickaxe, tier: 2, hp: 8, xp: 6, respawn: 13,
                     yields: [NodeYield(kind: .stone, min: 5, max: 7), NodeYield(kind: .coal, min: 1, max: 1, chance: 0.3)],
                     radius: 24, blocking: true, barHeight: 60, chip: gray),
            NodeSpec(type: .coalOre, tool: .pickaxe, tier: 2, hp: 7, xp: 6, respawn: 13,
                     yields: [NodeYield(kind: .coal, min: 2, max: 3), NodeYield(kind: .stone, min: 1, max: 1, chance: 0.5)],
                     radius: 20, blocking: true, barHeight: 52, chip: UIColor(white: 0.2, alpha: 1)),
            NodeSpec(type: .ironOre, tool: .pickaxe, tier: 3, hp: 11, xp: 10, respawn: 16,
                     yields: [NodeYield(kind: .iron, min: 2, max: 3), NodeYield(kind: .stone, min: 1, max: 1, chance: 0.5)],
                     radius: 20, blocking: true, barHeight: 52, chip: ResourceKind.iron.oreColor),
            NodeSpec(type: .goldOre, tool: .pickaxe, tier: 4, hp: 18, xp: 16, respawn: 22,
                     yields: [NodeYield(kind: .gold, min: 2, max: 3)], radius: 20, blocking: true, barHeight: 52,
                     chip: ResourceKind.gold.oreColor),
            NodeSpec(type: .iceBlock, tool: .pickaxe, tier: 4, hp: 15, xp: 14, respawn: 16,
                     yields: [NodeYield(kind: .ice, min: 3, max: 4)], radius: 18, blocking: true, barHeight: 52, chip: water),
            NodeSpec(type: .diamondOre, tool: .pickaxe, tier: 5, hp: 30, xp: 30, respawn: 35,
                     yields: [NodeYield(kind: .diamond, min: 1, max: 2), NodeYield(kind: .stone, min: 2, max: 2, chance: 0.5)],
                     radius: 20, blocking: true, barHeight: 56, chip: ResourceKind.diamond.oreColor),
            NodeSpec(type: .crystalOre, tool: .pickaxe, tier: 6, hp: 46, xp: 45, respawn: 45,
                     yields: [NodeYield(kind: .crystal, min: 1, max: 2)], radius: 22, blocking: true, barHeight: 64,
                     chip: ResourceKind.crystal.oreColor),
            NodeSpec(type: .fishSpot, tool: .rod, tier: 1, hp: 4, xp: 4, respawn: 10,
                     yields: [NodeYield(kind: .fish, min: 1, max: 2)], radius: 14, blocking: false, barHeight: 34, chip: water),
            NodeSpec(type: .oasisFish, tool: .rod, tier: 2, hp: 7, xp: 8, respawn: 13,
                     yields: [NodeYield(kind: .fish, min: 2, max: 3)], radius: 14, blocking: false, barHeight: 34, chip: water),
            NodeSpec(type: .iceHole, tool: .rod, tier: 3, hp: 12, xp: 14, respawn: 16,
                     yields: [NodeYield(kind: .fish, min: 4, max: 5)], radius: 16, blocking: false, barHeight: 34, chip: water),
            // Болото
            NodeSpec(type: .willow, tool: .axe, tier: 3, hp: 9, xp: 9, respawn: 13,
                     yields: [NodeYield(kind: .wood, min: 5, max: 6), NodeYield(kind: .herbs, min: 1, max: 2, chance: 0.5)],
                     radius: 18, blocking: true, barHeight: 76, chip: UIColor(red: 0.4, green: 0.55, blue: 0.3, alpha: 1)),
            NodeSpec(type: .herbPatch, tool: .hand, tier: 1, hp: 3, xp: 5, respawn: 9,
                     yields: [NodeYield(kind: .herbs, min: 2, max: 3)], radius: 12, blocking: false, barHeight: 40, chip: green),
            NodeSpec(type: .clayPit, tool: .pickaxe, tier: 2, hp: 7, xp: 7, respawn: 12,
                     yields: [NodeYield(kind: .clay, min: 3, max: 4)], radius: 18, blocking: false, barHeight: 40,
                     chip: UIColor(red: 0.75, green: 0.45, blue: 0.3, alpha: 1)),
            NodeSpec(type: .swampFish, tool: .rod, tier: 2, hp: 7, xp: 8, respawn: 12,
                     yields: [NodeYield(kind: .fish, min: 2, max: 3), NodeYield(kind: .herbs, min: 1, max: 1, chance: 0.3)],
                     radius: 14, blocking: false, barHeight: 34, chip: water),
            // Остров
            NodeSpec(type: .bananaPalm, tool: .axe, tier: 6, hp: 40, xp: 34, respawn: 20,
                     yields: [NodeYield(kind: .wood, min: 16, max: 20), NodeYield(kind: .banana, min: 2, max: 4)],
                     radius: 18, blocking: true, barHeight: 80, chip: UIColor(red: 1, green: 0.88, blue: 0.3, alpha: 1)),
            NodeSpec(type: .pineapple, tool: .hand, tier: 1, hp: 10, xp: 26, respawn: 16,
                     yields: [NodeYield(kind: .pineapple, min: 2, max: 3)], radius: 14, blocking: false, barHeight: 44,
                     chip: UIColor(red: 1, green: 0.75, blue: 0.2, alpha: 1)),
            NodeSpec(type: .shells, tool: .hand, tier: 1, hp: 6, xp: 20, respawn: 14,
                     yields: [NodeYield(kind: .shell, min: 2, max: 3), NodeYield(kind: .pearl, min: 1, max: 1, chance: 0.05)],
                     radius: 12, blocking: false, barHeight: 34, chip: UIColor(red: 1, green: 0.85, blue: 0.8, alpha: 1)),
            NodeSpec(type: .oyster, tool: .rod, tier: 5, hp: 30, xp: 40, respawn: 24,
                     yields: [NodeYield(kind: .fish, min: 6, max: 8), NodeYield(kind: .pearl, min: 1, max: 1, chance: 0.45)],
                     radius: 14, blocking: false, barHeight: 34, chip: water),
            NodeSpec(type: .coral, tool: .pickaxe, tier: 6, hp: 50, xp: 44, respawn: 28,
                     yields: [NodeYield(kind: .coral, min: 2, max: 3)], radius: 18, blocking: true, barHeight: 56,
                     chip: UIColor(red: 1, green: 0.45, blue: 0.5, alpha: 1)),
            // Вулкан
            NodeSpec(type: .ashTree, tool: .axe, tier: 7, hp: 70, xp: 55, respawn: 26,
                     yields: [NodeYield(kind: .wood, min: 24, max: 30), NodeYield(kind: .sulfur, min: 1, max: 2, chance: 0.4)],
                     radius: 20, blocking: true, barHeight: 80, chip: UIColor(white: 0.35, alpha: 1)),
            NodeSpec(type: .fireFlower, tool: .hand, tier: 1, hp: 14, xp: 38, respawn: 18,
                     yields: [NodeYield(kind: .herbs, min: 6, max: 8), NodeYield(kind: .sulfur, min: 1, max: 1, chance: 0.25)],
                     radius: 12, blocking: false, barHeight: 40, chip: UIColor(red: 1, green: 0.45, blue: 0.15, alpha: 1)),
            NodeSpec(type: .sulfurVent, tool: .pickaxe, tier: 6, hp: 55, xp: 48, respawn: 26,
                     yields: [NodeYield(kind: .sulfur, min: 2, max: 3)], radius: 20, blocking: true, barHeight: 56,
                     chip: ResourceKind.sulfur.oreColor),
            NodeSpec(type: .obsidianOre, tool: .pickaxe, tier: 7, hp: 90, xp: 64, respawn: 32,
                     yields: [NodeYield(kind: .obsidian, min: 2, max: 3)], radius: 20, blocking: true, barHeight: 58,
                     chip: ResourceKind.obsidian.oreColor),
            NodeSpec(type: .rubyOre, tool: .pickaxe, tier: 7, hp: 110, xp: 80, respawn: 45,
                     yields: [NodeYield(kind: .ruby, min: 1, max: 1), NodeYield(kind: .obsidian, min: 1, max: 1, chance: 0.4)],
                     radius: 20, blocking: true, barHeight: 58, chip: ResourceKind.ruby.oreColor),
            NodeSpec(type: .lavaFish, tool: .rod, tier: 7, hp: 80, xp: 60, respawn: 26,
                     yields: [NodeYield(kind: .fish, min: 12, max: 15), NodeYield(kind: .ruby, min: 1, max: 1, chance: 0.12)],
                     radius: 14, blocking: false, barHeight: 34, chip: UIColor(red: 1, green: 0.5, blue: 0.1, alpha: 1)),
            // Небесные острова
            NodeSpec(type: .cloudBush, tool: .hand, tier: 1, hp: 12, xp: 50, respawn: 20,
                     yields: [NodeYield(kind: .cloud, min: 2, max: 3)], radius: 16, blocking: false, barHeight: 50, chip: .white),
            NodeSpec(type: .goldenTree, tool: .hand, tier: 1, hp: 16, xp: 60, respawn: 30,
                     yields: [NodeYield(kind: .goldenApple, min: 1, max: 2)], radius: 20, blocking: true, keepsBody: true, barHeight: 80,
                     chip: ResourceKind.goldenApple.oreColor),
            NodeSpec(type: .skyTree, tool: .axe, tier: 8, hp: 140, xp: 90, respawn: 30,
                     yields: [NodeYield(kind: .wood, min: 40, max: 50), NodeYield(kind: .cloud, min: 1, max: 2, chance: 0.5)],
                     radius: 20, blocking: true, barHeight: 84, chip: UIColor(red: 0.7, green: 0.85, blue: 1, alpha: 1)),
            NodeSpec(type: .starRock, tool: .pickaxe, tier: 8, hp: 160, xp: 110, respawn: 50,
                     yields: [NodeYield(kind: .stardust, min: 1, max: 2), NodeYield(kind: .crystal, min: 1, max: 1, chance: 0.4)],
                     radius: 20, blocking: true, barHeight: 60, chip: UIColor(red: 1, green: 0.95, blue: 0.6, alpha: 1)),
            NodeSpec(type: .starPond, tool: .rod, tier: 8, hp: 120, xp: 85, respawn: 30,
                     yields: [NodeYield(kind: .fish, min: 18, max: 22), NodeYield(kind: .stardust, min: 1, max: 1, chance: 0.2)],
                     radius: 14, blocking: false, barHeight: 34, chip: UIColor(red: 0.6, green: 0.6, blue: 1, alpha: 1)),
            // Королевский сад и экспедиции
            NodeSpec(type: .beehive, tool: .hand, tier: 1, hp: 6, xp: 14, respawn: 30,
                     yields: [NodeYield(kind: .honey, min: 1, max: 2)], radius: 14, blocking: true, keepsBody: true, barHeight: 48,
                     chip: UIColor(red: 1, green: 0.75, blue: 0.2, alpha: 1)),
            NodeSpec(type: .grapeVine, tool: .hand, tier: 1, hp: 6, xp: 10, respawn: 25,
                     yields: [NodeYield(kind: .berries, min: 5, max: 7)], radius: 22, blocking: false, barHeight: 70,
                     chip: UIColor(red: 0.55, green: 0.3, blue: 0.75, alpha: 1)),
            NodeSpec(type: .treasureChest, tool: .hand, tier: 1, hp: 8, xp: 30, respawn: 600,
                     yields: [NodeYield(kind: .gold, min: 3, max: 6), NodeYield(kind: .pearl, min: 1, max: 1, chance: 0.35),
                              NodeYield(kind: .diamond, min: 1, max: 1, chance: 0.25), NodeYield(kind: .shell, min: 2, max: 3, chance: 0.5)],
                     radius: 16, blocking: false, barHeight: 40, chip: UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)),
            // Ивенты
            NodeSpec(type: .pumpkinPatch, tool: .hand, tier: 1, hp: 5, xp: 10, respawn: 14,
                     yields: [NodeYield(kind: .wheat, min: 2, max: 3), NodeYield(kind: .pumpkin, min: 1, max: 1, chance: 0.12)],
                     radius: 16, blocking: false, barHeight: 44, chip: UIColor(red: 1, green: 0.55, blue: 0.1, alpha: 1)),
            NodeSpec(type: .giftBox, tool: .hand, tier: 1, hp: 5, xp: 10, respawn: 16,
                     yields: [NodeYield(kind: .apples, min: 2, max: 3), NodeYield(kind: .gold, min: 1, max: 1, chance: 0.2)],
                     radius: 14, blocking: false, barHeight: 40, chip: UIColor(red: 0.9, green: 0.25, blue: 0.3, alpha: 1)),
            NodeSpec(type: .sandCastle, tool: .hand, tier: 1, hp: 5, xp: 10, respawn: 14,
                     yields: [NodeYield(kind: .shell, min: 1, max: 2), NodeYield(kind: .pearl, min: 1, max: 1, chance: 0.06)],
                     radius: 16, blocking: false, barHeight: 46, chip: UIColor(red: 0.95, green: 0.8, blue: 0.55, alpha: 1)),
            NodeSpec(type: .slimeCrystal, tool: .pickaxe, tier: 1, hp: 6, xp: 12, respawn: 16,
                     yields: [NodeYield(kind: .slime, min: 2, max: 3), NodeYield(kind: .crystal, min: 1, max: 1, chance: 0.05)],
                     radius: 18, blocking: true, barHeight: 58, chip: UIColor(red: 0.45, green: 0.95, blue: 0.4, alpha: 1))
        ]
        var dict: [NodeType: NodeSpec] = [:]
        for spec in list { dict[spec.type] = spec }
        return dict
    }()
}
