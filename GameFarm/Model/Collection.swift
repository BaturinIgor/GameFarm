import UIKit

/// Созвездия: каждое собирается из пяти карт. Полное созвездие даёт вечный бонус и образ героя.
enum ConstellationID: String, CaseIterable, Identifiable, Codable {
    case harvest, forest, depths, sea, beasts, monsters, sky

    var id: String { rawValue }

    var name: String { tr("const.\(rawValue)") }

    var cards: [CardID] { CardID.allCases.filter { $0.constellation == self } }

    /// Награда за полное созвездие.
    var skin: Skin {
        switch self {
        case .harvest: .harvester
        case .forest: .ranger
        case .depths: .miner
        case .sea: .sailor
        case .beasts: .shepherd
        case .monsters: .hunter
        case .sky: .stargazer
        }
    }

    /// Бонус: 5% за полное созвездие и ещё 2% за каждую звезду самой слабой карты сверх первой.
    static func bonus(minStars: Int) -> Double {
        guard minStars > 0 else { return 0 }
        return 0.05 + 0.02 * Double(minStars - 1)
    }

    func bonusText(_ value: Double) -> String { tr("const.\(rawValue).bonus", Fmt.pct(value)) }

    /// Где звёзды на небе (0...1), рисуются линией по порядку карт.
    var shape: [(Double, Double)] {
        switch self {
        case .harvest: [(0.1, 0.7), (0.3, 0.35), (0.5, 0.55), (0.7, 0.25), (0.9, 0.6)]
        case .forest: [(0.5, 0.1), (0.3, 0.4), (0.7, 0.4), (0.2, 0.8), (0.8, 0.8)]
        case .depths: [(0.15, 0.2), (0.35, 0.75), (0.5, 0.3), (0.65, 0.75), (0.85, 0.2)]
        case .sea: [(0.1, 0.5), (0.3, 0.25), (0.5, 0.6), (0.7, 0.3), (0.9, 0.55)]
        case .beasts: [(0.2, 0.3), (0.45, 0.2), (0.6, 0.5), (0.4, 0.8), (0.85, 0.65)]
        case .monsters: [(0.5, 0.15), (0.2, 0.45), (0.35, 0.85), (0.65, 0.85), (0.8, 0.45)]
        case .sky: [(0.1, 0.8), (0.3, 0.5), (0.5, 0.15), (0.7, 0.5), (0.9, 0.8)]
        }
    }
}

/// Как выглядит карта: иконка ресурса, зверь или монстр.
enum CardArt {
    case resource(ResourceKind)
    case animal(AnimalID)
    case monster(MonsterKind)
}

enum CardID: String, CaseIterable, Identifiable, Codable {
    case wheat, carrot, pumpkin, sunflower, grapes
    case log, apple, mushroom, berry, honey
    case stone, coal, iron, gold, diamond
    case fish, shell, coral, pearl, coconut
    case cow, sheep, pig, chicken, horse
    case slimeGreen, slimeBlue, slimeRed, slimeIce, skeleton
    case cloud, feather, crystal, ruby, stardust

    var id: String { rawValue }

    var constellation: ConstellationID {
        switch self {
        case .wheat, .carrot, .pumpkin, .sunflower, .grapes: .harvest
        case .log, .apple, .mushroom, .berry, .honey: .forest
        case .stone, .coal, .iron, .gold, .diamond: .depths
        case .fish, .shell, .coral, .pearl, .coconut: .sea
        case .cow, .sheep, .pig, .chicken, .horse: .beasts
        case .slimeGreen, .slimeBlue, .slimeRed, .slimeIce, .skeleton: .monsters
        case .cloud, .feather, .crystal, .ruby, .stardust: .sky
        }
    }

    var art: CardArt {
        switch self {
        case .cow: .animal(.cow)
        case .sheep: .animal(.sheep)
        case .pig: .animal(.pig)
        case .chicken: .animal(.chicken)
        case .horse: .animal(.horse)
        case .slimeGreen: .monster(.slimeGreen)
        case .slimeBlue: .monster(.slimeBlue)
        case .slimeRed: .monster(.slimeRed)
        case .slimeIce: .monster(.slimeIce)
        case .skeleton: .monster(.skeleton)
        default: .resource(resource ?? .wood)
        }
    }

    /// Ресурс, при добыче которого может выпасть карта.
    var resource: ResourceKind? {
        switch self {
        case .wheat: .wheat
        case .carrot: .carrots
        case .pumpkin: .pumpkin
        case .sunflower: .sunflower
        case .grapes: .grapes
        case .log: .wood
        case .apple: .apples
        case .mushroom: .mushrooms
        case .berry: .berries
        case .honey: .honey
        case .stone: .stone
        case .coal: .coal
        case .iron: .iron
        case .gold: .gold
        case .diamond: .diamond
        case .fish: .fish
        case .shell: .shell
        case .coral: .coral
        case .pearl: .pearl
        case .coconut: .coconut
        case .cloud: .cloud
        case .feather: .feather
        case .crystal: .crystal
        case .ruby: .ruby
        case .stardust: .stardust
        default: nil
        }
    }

    var name: String {
        switch art {
        case .resource(let kind): kind.name
        case .animal(let id): id.spec.name
        case .monster(let kind): kind.name
        }
    }

    static func forResource(_ kind: ResourceKind) -> CardID? {
        allCases.first { $0.resource == kind }
    }

    static func forMonster(_ kind: MonsterKind) -> CardID? {
        switch kind {
        case .slimeGreen: .slimeGreen
        case .slimeBlue: .slimeBlue
        case .slimeRed: .slimeRed
        case .slimeIce: .slimeIce
        case .skeleton, .skeletonDark: .skeleton
        default: nil
        }
    }

    static func forAnimal(_ id: AnimalID) -> CardID? {
        switch id {
        case .cow: .cow
        case .sheep: .sheep
        case .pig: .pig
        case .chicken, .rooster: .chicken
        case .horse: .horse
        default: nil
        }
    }
}

enum Cards {
    /// Сколько карт нужно для звезды: 1, 3, 6, 10, 15.
    static let thresholds = [1, 3, 6, 10, 15]

    static func stars(count: Int) -> Int { thresholds.filter { count >= $0 }.count }

    static func next(count: Int) -> Int? { thresholds.first { count < $0 } }
}

// MARK: Пробуждение зверей

enum Awakening {
    static let maxLevel = 3

    /// Каждое пробуждение +25% к силе зверя.
    static func multiplier(_ level: Int) -> Double { 1 + 0.25 * Double(level) }

    static func cost(level next: Int) -> Cost {
        switch next {
        case 1: Cost(coins: 2500, (.slime, 20), (.bone, 10))
        case 2: Cost(coins: 9000, (.crystal, 15), (.bone, 40))
        default: Cost(coins: 30000, (.stardust, 8), (.ruby, 8))
        }
    }

    /// Цвет ауры: бронза, серебро, золото.
    static func colorHex(_ level: Int) -> UInt32 {
        switch level {
        case 1: 0xCD7F32
        case 2: 0xD8DEE8
        default: 0xFFD54A
        }
    }

    static func title(_ level: Int) -> String { tr("awaken.level.\(max(1, min(3, level)))") }
}

/// Редкая окраска зверя: 3% диких зверей бывают другого цвета.
enum Shiny {
    static let chance = 0.03
    static let bonus = 0.1
    /// Цвет перекраски: зверь становится сиреневым с переливом.
    static let tint = UIColor(red: 0.75, green: 0.45, blue: 1, alpha: 1)
}
