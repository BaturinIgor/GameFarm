import UIKit

enum LocationID: String, CaseIterable, Identifiable {
    case meadow, hills, lake, desert, snow, caves

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

struct LocationSpec {
    let id: LocationID
    let name: String
    let emoji: String
    let blurb: String
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
                id: .meadow, name: "Лесная поляна", emoji: "🌳",
                blurb: "Дубы, ягоды, грибы и первые камни. Здесь всё начинается.",
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
                seed: 11
            ),
            LocationSpec(
                id: .hills, name: "Каменные холмы", emoji: "⛰️",
                blurb: "Ели, валуны, уголь и железо. Нужна кирка покрепче.",
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
                seed: 23
            ),
            LocationSpec(
                id: .lake, name: "Тихое озеро", emoji: "🏞️",
                blurb: "Рыбалка, бамбук и яблони у воды.",
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
                seed: 37
            ),
            LocationSpec(
                id: .desert, name: "Знойная пустыня", emoji: "🏜️",
                blurb: "Пальмы, кактусы, оазис и золотые жилы.",
                level: 15, cost: Cost(coins: 2000, (.wood, 400), (.iron, 80), (.fish, 60), (.bamboo, 60)),
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
                seed: 41
            ),
            LocationSpec(
                id: .snow, name: "Снежные вершины", emoji: "🏔️",
                blurb: "Снежные ели, лёд, подлёдная рыбалка и алмазы.",
                level: 22, cost: Cost(coins: 6000, (.iron, 200), (.gold, 60), (.coconut, 50), (.cactus, 50)),
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
                seed: 53
            ),
            LocationSpec(
                id: .caves, name: "Кристальные пещеры", emoji: "🔮",
                blurb: "Темно, светятся грибы, а в стенах растут кристаллы.",
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
                seed: 67
            )
        ]
        var dict: [LocationID: LocationSpec] = [:]
        for spec in list { dict[spec.id] = spec }
        return dict
    }()
}
