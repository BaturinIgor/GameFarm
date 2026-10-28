import UIKit

/// Обычная локация мира, платный сад, экспедиция по билету или карта ивента.
enum LocationKind {
    case world, garden, expedition, event
}

enum LocationID: String, CaseIterable, Identifiable {
    case meadow, hills, lake, swamp, desert, snow, caves, island, volcano, sky
    case garden
    case goldMine, treasureIsland, luckyMeadow
    case harvestFest, slimeNight, winterTale, beachParty

    var id: String { rawValue }
    var spec: LocationSpec { LocationSpec.table[self]! }
    var layout: LocationLayout { LocationLayout.get(self) }

    static var world: [LocationID] { allCases.filter { $0.spec.kind == .world } }
    static var expeditions: [LocationID] { allCases.filter { $0.spec.kind == .expedition } }
    static var events: [LocationID] { allCases.filter { $0.spec.kind == .event } }
}

/// Частицы в воздухе.
enum Weather {
    case petals, leaves, pollen, fireflies, sand, snow, motes, spray, embers, stars
}

struct LocationSpec {
    let id: LocationID
    let emoji: String
    /// Уровень, с которого можно открыть проход в локацию.
    let level: Int
    var kind: LocationKind = .world
    /// Клетка на карте мира: столбец и ряд (снизу вверх).
    var mapX = 0
    var mapY = 0
    /// Цвета для интерфейса и для запасной земли без спрайтов.
    let ground: UIColor
    let path: UIColor
    var water: UIColor = UIColor(red: 0.2, green: 0.55, blue: 0.85, alpha: 1)
    let wild: [AnimalID]
    var dark: Bool = false
    var weather: Weather = .petals
    /// Лёгкая цветовая тонировка всей сцены.
    var tint: UIColor? = nil
    var cloudShadows: Bool = true
    var critters: [String] = []
    var music: Music = .meadow
    var ambience: Ambience? = .birds
    var footstep: SFX = .footstepGrass
    var lava = false

    var name: String { tr("loc.\(id.rawValue)") }
    var blurb: String { tr("loc.\(id.rawValue).blurb") }

    /// Какие ресурсы здесь можно добыть.
    var resources: [ResourceKind] {
        var seen: [ResourceKind] = []
        for type in nodeTypes {
            for y in type.spec.yields where !seen.contains(y.kind) {
                seen.append(y.kind)
            }
        }
        return seen
    }

    var nodeTypes: [NodeType] { id.layout.nodeTypes }

    static func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor {
        UIColor(red: r / 255, green: g / 255, blue: b / 255, alpha: 1)
    }

    static let table: [LocationID: LocationSpec] = {
        let c = LocationSpec.color
        let list: [LocationSpec] = [
            LocationSpec(id: .meadow, emoji: "🌳", level: 1, mapX: 1, mapY: 0,
                         ground: c(51, 152, 75), path: c(228, 166, 114),
                         wild: [.mouse], weather: .petals, critters: ["🦋", "🐝"],
                         music: .meadow, ambience: .birds),
            LocationSpec(id: .hills, emoji: "⛰️", level: 4, mapX: 0, mapY: 0,
                         ground: c(124, 150, 60), path: c(228, 166, 114),
                         wild: [.goose, .mouse], weather: .leaves, critters: ["🦋"],
                         music: .hills, ambience: .wind),
            LocationSpec(id: .lake, emoji: "🏞️", level: 9, mapX: 2, mapY: 0,
                         ground: c(62, 137, 72), path: c(228, 166, 114),
                         wild: [.duck, .swan], weather: .pollen, critters: ["🦋", "🐞"],
                         music: .lake, ambience: .river),
            LocationSpec(id: .swamp, emoji: "🐸", level: 12, mapX: 2, mapY: 1,
                         ground: c(63, 136, 108), path: c(90, 66, 48), water: c(47, 90, 64),
                         wild: [.frog, .duck], weather: .fireflies,
                         tint: UIColor(red: 0.2, green: 0.35, blue: 0.25, alpha: 0.1), critters: ["🦟", "🐌"],
                         music: .swamp, ambience: .river),
            LocationSpec(id: .desert, emoji: "🏜️", level: 15, mapX: 1, mapY: 1,
                         ground: c(232, 180, 126), path: c(200, 140, 80),
                         wild: [.butterfly, .mouse], weather: .sand,
                         tint: UIColor(red: 1, green: 0.6, blue: 0.2, alpha: 0.05), critters: ["🦂"],
                         music: .desert, ambience: .wind, footstep: .footstepSand),
            LocationSpec(id: .snow, emoji: "🏔️", level: 22, mapX: 0, mapY: 1,
                         ground: c(238, 244, 252), path: c(188, 205, 224), water: c(200, 230, 248),
                         wild: [.swan, .goose], weather: .snow,
                         tint: UIColor(red: 0.4, green: 0.6, blue: 1, alpha: 0.05),
                         music: .snow, ambience: .wind, footstep: .footstepSnow),
            LocationSpec(id: .caves, emoji: "🔮", level: 30, mapX: 0, mapY: 2,
                         ground: c(58, 48, 82), path: c(76, 66, 104), water: c(22, 48, 94),
                         wild: [.mouse, .goldenGoose], dark: true, weather: .motes, cloudShadows: false,
                         music: .caves, ambience: nil, footstep: .footstepStone),
            LocationSpec(id: .island, emoji: "🏝️", level: 36, mapX: 2, mapY: 2,
                         ground: c(228, 166, 114), path: c(240, 200, 150), water: c(22, 180, 212),
                         wild: [.butterfly, .duck], weather: .spray,
                         tint: UIColor(red: 1, green: 0.9, blue: 0.5, alpha: 0.04), critters: ["🦋", "🐦"],
                         music: .island, ambience: .waves, footstep: .footstepSand),
            LocationSpec(id: .volcano, emoji: "🌋", level: 43, mapX: 1, mapY: 2,
                         ground: c(76, 58, 52), path: c(92, 74, 68), water: c(255, 122, 31),
                         wild: [.goldenGoose, .goose], weather: .embers,
                         tint: UIColor(red: 1, green: 0.25, blue: 0.1, alpha: 0.08),
                         music: .volcano, ambience: .fire, footstep: .footstepStone, lava: true),
            LocationSpec(id: .sky, emoji: "☁️", level: 50, mapX: 1, mapY: 3,
                         ground: c(216, 220, 255), path: c(244, 232, 248), water: c(95, 80, 200),
                         wild: [.goldenGoose, .swan], weather: .stars,
                         tint: UIColor(red: 1, green: 0.7, blue: 0.9, alpha: 0.05), critters: ["🦋", "🕊️"],
                         music: .sky, ambience: .wind),
            LocationSpec(id: .garden, emoji: "👑", level: 1, kind: .garden,
                         ground: c(51, 152, 75), path: c(200, 188, 174),
                         wild: [], weather: .petals, critters: ["🦋", "🐝", "🦋"],
                         music: .garden, ambience: .birds, footstep: .footstepStone),
            LocationSpec(id: .goldMine, emoji: "⛏️", level: 1, kind: .expedition,
                         ground: c(62, 48, 32), path: c(110, 88, 62), water: c(42, 74, 112),
                         wild: [], dark: true, weather: .motes, cloudShadows: false,
                         music: .expedition, ambience: nil, footstep: .footstepStone),
            LocationSpec(id: .treasureIsland, emoji: "🏴‍☠️", level: 1, kind: .expedition,
                         ground: c(228, 166, 114), path: c(240, 200, 150), water: c(22, 180, 212),
                         wild: [], weather: .spray, critters: ["🐦"],
                         music: .expedition, ambience: .waves, footstep: .footstepSand),
            LocationSpec(id: .luckyMeadow, emoji: "🍀", level: 1, kind: .expedition,
                         ground: c(51, 152, 75), path: c(228, 166, 114),
                         wild: [], weather: .pollen, critters: ["🦋", "🦋", "🐝"],
                         music: .expedition, ambience: .birds),
            // Карты ивентов
            LocationSpec(id: .harvestFest, emoji: "🎃", level: 1, kind: .event,
                         ground: c(133, 114, 40), path: c(154, 98, 56),
                         wild: [], weather: .leaves,
                         tint: UIColor(red: 1, green: 0.55, blue: 0.15, alpha: 0.06), critters: ["🦇", "🦋"],
                         music: .hills, ambience: .wind),
            LocationSpec(id: .slimeNight, emoji: "🟢", level: 1, kind: .event,
                         ground: c(30, 58, 40), path: c(60, 90, 66), water: c(58, 168, 58),
                         wild: [], dark: true, weather: .fireflies, cloudShadows: false,
                         music: .caves, ambience: nil, footstep: .footstepStone),
            LocationSpec(id: .winterTale, emoji: "🎁", level: 1, kind: .event,
                         ground: c(238, 244, 252), path: c(188, 205, 224), water: c(200, 230, 248),
                         wild: [], weather: .snow,
                         tint: UIColor(red: 0.4, green: 0.6, blue: 1, alpha: 0.05),
                         music: .snow, ambience: .wind, footstep: .footstepSnow),
            LocationSpec(id: .beachParty, emoji: "🏖️", level: 1, kind: .event,
                         ground: c(228, 166, 114), path: c(240, 200, 150), water: c(22, 180, 212),
                         wild: [], weather: .spray, critters: ["🦀", "🐦"],
                         music: .island, ambience: .waves, footstep: .footstepSand)
        ]
        var dict: [LocationID: LocationSpec] = [:]
        for spec in list { dict[spec.id] = spec }
        return dict
    }()
}
