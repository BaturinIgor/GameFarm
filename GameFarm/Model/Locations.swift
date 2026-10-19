import UIKit

enum LocationID: String, CaseIterable, Identifiable {
    case meadow, hills, lake, swamp, desert, snow, caves, island, volcano, sky

    var id: String { rawValue }
    var spec: LocationSpec { LocationSpec.table[self]! }
}

/// Группа одинаковых точек ресурсов. Координаты центра в долях размера мира.
struct Cluster {
    let node: NodeType
    let count: Int
    let x: CGFloat
    let y: CGFloat
    let radius: CGFloat
    /// Точки ставятся в воду указанного пруда (рыбалка).
    var pond: Int? = nil
}

struct Pond {
    let x: CGFloat
    let y: CGFloat
    let radius: CGFloat
    /// Замёрзший пруд: по нему можно ходить.
    var frozen: Bool = false
}

/// Частицы в воздухе.
enum Weather {
    case petals, leaves, pollen, fireflies, sand, snow, motes, spray, embers, stars
}

struct LocationSpec {
    let id: LocationID
    let emoji: String
    let level: Int
    let cost: Cost
    let size: CGSize
    let ground: UIColor
    let patches: [UIColor]
    let speck: UIColor
    let path: UIColor
    let decor: [String]
    let decorCount: Int
    let border: [String]
    let clusters: [Cluster]
    let ponds: [Pond]
    let wild: [AnimalID]
    var dark: Bool = false
    let seed: UInt64
    var water: UIColor = UIColor(red: 0.2, green: 0.55, blue: 0.85, alpha: 1)
    var waterLight: UIColor = UIColor(red: 0.28, green: 0.66, blue: 0.94, alpha: 1)
    var shore: UIColor? = nil
    var weather: Weather = .petals
    /// Лёгкая цветовая тонировка всей сцены.
    var tint: UIColor? = nil
    var cloudShadows: Bool = true
    var critters: [String] = []

    var name: String { tr("loc.\(id.rawValue)") }
    var blurb: String { tr("loc.\(id.rawValue).blurb") }

    var basePoint: CGPoint { CGPoint(x: size.width / 2, y: 190) }

    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x * size.width, y: y * size.height)
    }

    /// Какие ресурсы здесь можно добыть.
    var resources: [ResourceKind] {
        var seen: [ResourceKind] = []
        for cluster in clusters {
            for y in cluster.node.spec.yields where !seen.contains(y.kind) {
                seen.append(y.kind)
            }
        }
        return seen
    }

    var nodeTypes: [NodeType] {
        var seen: [NodeType] = []
        for cluster in clusters where !seen.contains(cluster.node) {
            seen.append(cluster.node)
        }
        return seen
    }

    static func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor {
        UIColor(red: r / 255, green: g / 255, blue: b / 255, alpha: 1)
    }

    static let table: [LocationID: LocationSpec] = {
        let c = LocationSpec.color
        let list: [LocationSpec] = [
            LocationSpec(
                id: .meadow, emoji: "🌳",
                level: 1, cost: Cost(),
                size: CGSize(width: 1400, height: 1900),
                ground: c(126, 196, 96),
                patches: [c(110, 182, 84), c(142, 206, 106), c(100, 170, 80), c(150, 210, 120)],
                speck: c(84, 150, 66), path: c(196, 170, 118),
                decor: ["🌼", "🌸", "🌱", "🌿", "🌷"], decorCount: 130,
                border: ["🌳", "🌲", "🌳"],
                clusters: [
                    Cluster(node: .tree, count: 10, x: 0.2, y: 0.36, radius: 230),
                    Cluster(node: .tree, count: 9, x: 0.8, y: 0.56, radius: 220),
                    Cluster(node: .tree, count: 9, x: 0.3, y: 0.8, radius: 230),
                    Cluster(node: .appleTree, count: 4, x: 0.68, y: 0.26, radius: 150),
                    Cluster(node: .bush, count: 7, x: 0.5, y: 0.46, radius: 170),
                    Cluster(node: .bush, count: 5, x: 0.84, y: 0.86, radius: 140),
                    Cluster(node: .mushroom, count: 6, x: 0.14, y: 0.6, radius: 130),
                    Cluster(node: .rock, count: 7, x: 0.74, y: 0.74, radius: 170),
                    Cluster(node: .rock, count: 4, x: 0.42, y: 0.63, radius: 110)
                ],
                ponds: [Pond(x: 0.55, y: 0.9, radius: 100)],
                wild: [.rabbit, .squirrel],
                seed: 11,
                weather: .petals,
                critters: ["🦋", "🐝"]
            ),
            LocationSpec(
                id: .hills, emoji: "⛰️",
                level: 4, cost: Cost(coins: 0, (.wood, 60), (.stone, 40), (.berries, 20)),
                size: CGSize(width: 1500, height: 2000),
                ground: c(150, 170, 104),
                patches: [c(136, 156, 96), c(166, 176, 120), c(128, 140, 100), c(170, 162, 128)],
                speck: c(110, 120, 90), path: c(186, 168, 130),
                decor: ["🌾", "🌱", "🍂", "🌿"], decorCount: 110,
                border: ["🪨", "🌲", "⛰️"],
                clusters: [
                    Cluster(node: .pine, count: 9, x: 0.2, y: 0.3, radius: 220),
                    Cluster(node: .pine, count: 8, x: 0.8, y: 0.82, radius: 210),
                    Cluster(node: .tree, count: 5, x: 0.52, y: 0.93, radius: 180),
                    Cluster(node: .rock, count: 8, x: 0.76, y: 0.3, radius: 190),
                    Cluster(node: .boulder, count: 6, x: 0.36, y: 0.56, radius: 200),
                    Cluster(node: .coalOre, count: 6, x: 0.66, y: 0.56, radius: 170),
                    Cluster(node: .ironOre, count: 6, x: 0.2, y: 0.76, radius: 170),
                    Cluster(node: .carrot, count: 6, x: 0.5, y: 0.25, radius: 130),
                    Cluster(node: .carrot, count: 4, x: 0.88, y: 0.5, radius: 100),
                    Cluster(node: .mushroom, count: 4, x: 0.5, y: 0.75, radius: 110)
                ],
                ponds: [],
                wild: [.goat, .hedgehog],
                seed: 23,
                weather: .leaves,
                critters: ["🦋"]
            ),
            LocationSpec(
                id: .lake, emoji: "🏞️",
                level: 9, cost: Cost(coins: 300, (.wood, 200), (.stone, 150), (.coal, 40), (.carrots, 40)),
                size: CGSize(width: 1600, height: 2100),
                ground: c(108, 186, 120),
                patches: [c(96, 172, 110), c(124, 198, 132), c(90, 160, 104), c(140, 204, 140)],
                speck: c(70, 140, 90), path: c(200, 184, 140),
                decor: ["🌸", "🌱", "🌿", "🌺", "🪻"], decorCount: 120,
                border: ["🌳", "🌿", "🌲"],
                clusters: [
                    Cluster(node: .fishSpot, count: 4, x: 0.3, y: 0.45, radius: 0, pond: 0),
                    Cluster(node: .fishSpot, count: 5, x: 0.72, y: 0.7, radius: 0, pond: 1),
                    Cluster(node: .fishSpot, count: 3, x: 0.25, y: 0.86, radius: 0, pond: 2),
                    Cluster(node: .bamboo, count: 8, x: 0.76, y: 0.34, radius: 180),
                    Cluster(node: .bamboo, count: 5, x: 0.52, y: 0.93, radius: 150),
                    Cluster(node: .appleTree, count: 5, x: 0.5, y: 0.24, radius: 160),
                    Cluster(node: .tree, count: 5, x: 0.9, y: 0.9, radius: 140),
                    Cluster(node: .pine, count: 4, x: 0.08, y: 0.66, radius: 120),
                    Cluster(node: .mushroom, count: 5, x: 0.55, y: 0.5, radius: 110),
                    Cluster(node: .rock, count: 4, x: 0.13, y: 0.22, radius: 130),
                    Cluster(node: .coalOre, count: 4, x: 0.88, y: 0.16, radius: 120),
                    Cluster(node: .ironOre, count: 3, x: 0.48, y: 0.66, radius: 100)
                ],
                ponds: [Pond(x: 0.3, y: 0.45, radius: 190), Pond(x: 0.72, y: 0.7, radius: 210), Pond(x: 0.25, y: 0.86, radius: 120)],
                wild: [.duck, .beaver, .otter],
                seed: 37,
                weather: .pollen,
                critters: ["🦋", "🐞"]
            ),
            LocationSpec(
                id: .swamp, emoji: "🐸",
                level: 12, cost: Cost(coins: 800, (.wood, 300), (.iron, 40), (.fish, 40), (.bamboo, 30)),
                size: CGSize(width: 1600, height: 2100),
                ground: c(92, 124, 76),
                patches: [c(80, 112, 68), c(104, 134, 84), c(70, 100, 66), c(116, 140, 90)],
                speck: c(60, 90, 56), path: c(140, 128, 92),
                decor: ["🌿", "🍂", "🪷", "🌱", "🍄"], decorCount: 120,
                border: ["🌳", "🌿", "🪵"],
                clusters: [
                    Cluster(node: .swampFish, count: 4, x: 0.28, y: 0.5, radius: 0, pond: 0),
                    Cluster(node: .swampFish, count: 4, x: 0.74, y: 0.78, radius: 0, pond: 1),
                    Cluster(node: .willow, count: 8, x: 0.76, y: 0.36, radius: 200),
                    Cluster(node: .willow, count: 5, x: 0.15, y: 0.82, radius: 150),
                    Cluster(node: .herbPatch, count: 7, x: 0.5, y: 0.3, radius: 170),
                    Cluster(node: .herbPatch, count: 5, x: 0.52, y: 0.66, radius: 140),
                    Cluster(node: .clayPit, count: 6, x: 0.2, y: 0.24, radius: 150),
                    Cluster(node: .bamboo, count: 5, x: 0.88, y: 0.58, radius: 110),
                    Cluster(node: .mushroom, count: 6, x: 0.45, y: 0.92, radius: 150),
                    Cluster(node: .ironOre, count: 4, x: 0.9, y: 0.92, radius: 100),
                    Cluster(node: .coalOre, count: 3, x: 0.08, y: 0.6, radius: 80)
                ],
                ponds: [Pond(x: 0.28, y: 0.5, radius: 170), Pond(x: 0.74, y: 0.78, radius: 160)],
                wild: [.frog, .turtle, .crocodile],
                seed: 89,
                water: c(70, 110, 84), waterLight: c(90, 132, 96),
                weather: .fireflies,
                tint: UIColor(red: 0.2, green: 0.35, blue: 0.25, alpha: 0.12),
                critters: ["🦟", "🐌"]
            ),
            LocationSpec(
                id: .desert, emoji: "🏜️",
                level: 15, cost: Cost(coins: 2000, (.wood, 400), (.iron, 80), (.fish, 60), (.herbs, 40)),
                size: CGSize(width: 1600, height: 2200),
                ground: c(232, 204, 140),
                patches: [c(222, 192, 126), c(240, 214, 156), c(214, 182, 120), c(244, 222, 168)],
                speck: c(200, 168, 110), path: c(210, 176, 120),
                decor: ["🌾", "🦴", "🐚", "🌵"], decorCount: 60,
                border: ["🌵", "🪨", "🏜️"],
                clusters: [
                    Cluster(node: .oasisFish, count: 5, x: 0.5, y: 0.6, radius: 0, pond: 0),
                    Cluster(node: .palm, count: 8, x: 0.5, y: 0.6, radius: 290),
                    Cluster(node: .palm, count: 4, x: 0.85, y: 0.95, radius: 120),
                    Cluster(node: .cactus, count: 8, x: 0.2, y: 0.3, radius: 220),
                    Cluster(node: .cactus, count: 7, x: 0.8, y: 0.85, radius: 200),
                    Cluster(node: .boulder, count: 6, x: 0.8, y: 0.3, radius: 200),
                    Cluster(node: .goldOre, count: 6, x: 0.2, y: 0.82, radius: 180),
                    Cluster(node: .ironOre, count: 4, x: 0.84, y: 0.56, radius: 130),
                    Cluster(node: .rock, count: 4, x: 0.5, y: 0.25, radius: 140),
                    Cluster(node: .coalOre, count: 3, x: 0.14, y: 0.56, radius: 110)
                ],
                ponds: [Pond(x: 0.5, y: 0.6, radius: 150)],
                wild: [.camel, .lizard],
                seed: 41,
                weather: .sand,
                tint: UIColor(red: 1, green: 0.6, blue: 0.2, alpha: 0.07),
                critters: ["🦂"]
            ),
            LocationSpec(
                id: .snow, emoji: "🏔️",
                level: 22, cost: Cost(coins: 6000, (.iron, 200), (.gold, 60), (.coconut, 50), (.clay, 80)),
                size: CGSize(width: 1600, height: 2200),
                ground: c(232, 240, 248),
                patches: [c(220, 230, 244), c(240, 246, 252), c(210, 222, 238), c(246, 250, 255)],
                speck: c(196, 210, 230), path: c(200, 210, 226),
                decor: ["❄️", "🌨️", "🪵"], decorCount: 60,
                border: ["🌲", "🏔️", "❄️"],
                clusters: [
                    Cluster(node: .iceHole, count: 5, x: 0.65, y: 0.4, radius: 0, pond: 0),
                    Cluster(node: .snowPine, count: 9, x: 0.2, y: 0.36, radius: 230),
                    Cluster(node: .snowPine, count: 8, x: 0.8, y: 0.86, radius: 220),
                    Cluster(node: .iceBlock, count: 7, x: 0.26, y: 0.7, radius: 180),
                    Cluster(node: .diamondOre, count: 5, x: 0.56, y: 0.8, radius: 170),
                    Cluster(node: .ironOre, count: 4, x: 0.86, y: 0.15, radius: 130),
                    Cluster(node: .goldOre, count: 3, x: 0.1, y: 0.93, radius: 110),
                    Cluster(node: .boulder, count: 3, x: 0.46, y: 0.6, radius: 110)
                ],
                ponds: [Pond(x: 0.65, y: 0.4, radius: 210, frozen: true)],
                wild: [.penguin, .fox, .polarBear],
                seed: 53,
                weather: .snow,
                tint: UIColor(red: 0.4, green: 0.6, blue: 1, alpha: 0.06)
            ),
            LocationSpec(
                id: .caves, emoji: "🔮",
                level: 30, cost: Cost(coins: 15000, (.gold, 200), (.ice, 150), (.diamond, 15)),
                size: CGSize(width: 1500, height: 2100),
                ground: c(70, 64, 92),
                patches: [c(60, 56, 82), c(84, 76, 108), c(54, 50, 74), c(92, 80, 120)],
                speck: c(110, 100, 140), path: c(96, 88, 118),
                decor: ["✨", "🕸️", "🦴"], decorCount: 70,
                border: ["🪨", "🪨", "🌑"],
                clusters: [
                    Cluster(node: .crystalOre, count: 6, x: 0.25, y: 0.42, radius: 200),
                    Cluster(node: .crystalOre, count: 6, x: 0.75, y: 0.76, radius: 200),
                    Cluster(node: .diamondOre, count: 6, x: 0.7, y: 0.36, radius: 170),
                    Cluster(node: .goldOre, count: 5, x: 0.3, y: 0.8, radius: 160),
                    Cluster(node: .glowShroom, count: 7, x: 0.5, y: 0.56, radius: 160),
                    Cluster(node: .glowShroom, count: 4, x: 0.86, y: 0.16, radius: 100),
                    Cluster(node: .glowTree, count: 4, x: 0.15, y: 0.16, radius: 120),
                    Cluster(node: .coalOre, count: 4, x: 0.86, y: 0.52, radius: 120),
                    Cluster(node: .boulder, count: 4, x: 0.5, y: 0.93, radius: 140)
                ],
                ponds: [],
                wild: [.bat, .dragon],
                dark: true,
                seed: 67,
                weather: .motes,
                cloudShadows: false
            ),
            LocationSpec(
                id: .island, emoji: "🏝️",
                level: 36, cost: Cost(coins: 25000, (.crystal, 40), (.diamond, 40), (.cactus, 150), (.coconut, 150)),
                size: CGSize(width: 1700, height: 2200),
                ground: c(240, 220, 160),
                patches: [c(232, 210, 150), c(246, 230, 176), c(150, 205, 110), c(130, 190, 100)],
                speck: c(214, 190, 130), path: c(250, 236, 196),
                decor: ["🐚", "🌺", "🌴", "🦀"], decorCount: 70,
                border: ["🌊", "🌊", "🌴"],
                clusters: [
                    Cluster(node: .oyster, count: 5, x: 0.25, y: 0.55, radius: 0, pond: 0),
                    Cluster(node: .oyster, count: 4, x: 0.78, y: 0.82, radius: 0, pond: 1),
                    Cluster(node: .coral, count: 6, x: 0.8, y: 0.4, radius: 180),
                    Cluster(node: .bananaPalm, count: 8, x: 0.5, y: 0.66, radius: 230),
                    Cluster(node: .palm, count: 5, x: 0.15, y: 0.18, radius: 130),
                    Cluster(node: .pineapple, count: 7, x: 0.55, y: 0.3, radius: 170),
                    Cluster(node: .shells, count: 8, x: 0.3, y: 0.86, radius: 200),
                    Cluster(node: .shells, count: 5, x: 0.9, y: 0.2, radius: 110),
                    Cluster(node: .crystalOre, count: 3, x: 0.1, y: 0.4, radius: 90)
                ],
                ponds: [Pond(x: 0.25, y: 0.55, radius: 200), Pond(x: 0.78, y: 0.82, radius: 170)],
                wild: [.parrot, .monkey, .crab],
                seed: 97,
                water: c(40, 190, 210), waterLight: c(90, 220, 230), shore: c(250, 240, 200),
                weather: .spray,
                tint: UIColor(red: 1, green: 0.9, blue: 0.5, alpha: 0.05),
                critters: ["🦋", "🐦"]
            ),
            LocationSpec(
                id: .volcano, emoji: "🌋",
                level: 43, cost: Cost(coins: 50000, (.crystal, 60), (.coral, 40), (.pearl, 10), (.banana, 100)),
                size: CGSize(width: 1600, height: 2200),
                ground: c(74, 60, 58),
                patches: [c(62, 50, 50), c(88, 70, 64), c(54, 44, 44), c(100, 76, 66)],
                speck: c(120, 90, 80), path: c(110, 86, 74),
                decor: ["🔥", "🪨", "🦴"], decorCount: 50,
                border: ["🌋", "🪨", "🔥"],
                clusters: [
                    Cluster(node: .lavaFish, count: 4, x: 0.3, y: 0.62, radius: 0, pond: 0),
                    Cluster(node: .lavaFish, count: 3, x: 0.75, y: 0.3, radius: 0, pond: 1),
                    Cluster(node: .obsidianOre, count: 7, x: 0.75, y: 0.62, radius: 200),
                    Cluster(node: .rubyOre, count: 5, x: 0.25, y: 0.88, radius: 160),
                    Cluster(node: .sulfurVent, count: 6, x: 0.25, y: 0.3, radius: 170),
                    Cluster(node: .ashTree, count: 6, x: 0.6, y: 0.9, radius: 170),
                    Cluster(node: .fireFlower, count: 7, x: 0.5, y: 0.45, radius: 160),
                    Cluster(node: .goldOre, count: 4, x: 0.9, y: 0.9, radius: 90)
                ],
                ponds: [Pond(x: 0.3, y: 0.62, radius: 150), Pond(x: 0.75, y: 0.3, radius: 130)],
                wild: [.phoenix, .lavasaur],
                seed: 103,
                water: c(240, 90, 20), waterLight: c(255, 180, 40), shore: c(40, 30, 30),
                weather: .embers,
                tint: UIColor(red: 1, green: 0.25, blue: 0.1, alpha: 0.1),
                cloudShadows: true
            ),
            LocationSpec(
                id: .sky, emoji: "☁️",
                level: 50, cost: Cost(coins: 100000, (.obsidian, 100), (.ruby, 20), (.sulfur, 100), (.pineapple, 200)),
                size: CGSize(width: 1600, height: 2200),
                ground: c(196, 214, 250),
                patches: [c(184, 204, 246), c(214, 226, 252), c(226, 210, 250), c(200, 232, 240)],
                speck: c(240, 244, 255), path: c(250, 240, 210),
                decor: ["✨", "⭐", "🌸"], decorCount: 80,
                border: ["☁️", "☁️", "🌈"],
                clusters: [
                    Cluster(node: .starPond, count: 5, x: 0.5, y: 0.55, radius: 0, pond: 0),
                    Cluster(node: .skyTree, count: 7, x: 0.2, y: 0.35, radius: 200),
                    Cluster(node: .goldenTree, count: 5, x: 0.8, y: 0.3, radius: 170),
                    Cluster(node: .cloudBush, count: 8, x: 0.78, y: 0.75, radius: 200),
                    Cluster(node: .starRock, count: 6, x: 0.22, y: 0.8, radius: 180),
                    Cluster(node: .crystalOre, count: 4, x: 0.5, y: 0.92, radius: 130),
                    Cluster(node: .cloudBush, count: 4, x: 0.5, y: 0.24, radius: 110)
                ],
                ponds: [Pond(x: 0.5, y: 0.55, radius: 170)],
                wild: [.eagle, .swan, .dove],
                seed: 131,
                water: c(50, 40, 120), waterLight: c(90, 80, 170), shore: c(250, 240, 210),
                weather: .stars,
                tint: UIColor(red: 1, green: 0.7, blue: 0.9, alpha: 0.06),
                cloudShadows: true,
                critters: ["🦋", "🕊️"]
            )
        ]
        var dict: [LocationID: LocationSpec] = [:]
        for spec in list { dict[spec.id] = spec }
        return dict
    }()
}
