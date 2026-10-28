import Foundation

/// Встроенные покупки. Все разовые (non-consumable), поэтому их можно восстановить без сервера.
enum ProductID: String, CaseIterable, Identifiable {
    case starter = "com.personal.gamefarm.starter"
    case pro = "com.personal.gamefarm.pro"
    case skins = "com.personal.gamefarm.skins"
    case garden = "com.personal.gamefarm.garden"
    case tickets = "com.personal.gamefarm.tickets5"

    var id: String { rawValue }

    /// Расходуемая покупка: её можно купить снова.
    var consumable: Bool { self == .tickets }

    var key: String {
        switch self {
        case .starter: "starter"
        case .pro: "pro"
        case .skins: "skins"
        case .garden: "garden"
        case .tickets: "tickets"
        }
    }

    var title: String { tr("product.\(key)") }

    var emoji: String {
        switch self {
        case .starter: "🎁"
        case .pro: "👑"
        case .skins: "🎭"
        case .garden: "🏰"
        case .tickets: "🎟️"
        }
    }

    /// Цена до загрузки из App Store (и в тестовой сборке).
    var fallbackPrice: String {
        switch self {
        case .starter: "$1.99"
        case .pro: "$4.99"
        case .skins: "$2.99"
        case .garden: "$3.99"
        case .tickets: "$0.99"
        }
    }
}

enum Premium {
    static let starterCoins = 2500
    static let starterBackpack = 30
    static let starterLevel = 5
    static let starterSecondLevel = 15
    static let starterWindow: TimeInterval = 48 * 3600
    static let proOfflineHours = 24.0
    static let luckDuration: TimeInterval = 10 * 60
    static let luckCooldown: TimeInterval = 10 * 60
}

enum SkinUnlock {
    case free
    case level(Int)
    case product(ProductID)
    case constellation(ConstellationID)
}

/// Образы персонажа. Только внешний вид, на силу не влияют.
enum Skin: String, CaseIterable, Identifiable {
    case farmer, farmerWoman, farmerMan, builder, cowboy, detective, elf, rockstar
    case robot, genie
    case wizard, ninja, vampire, astronaut, princess, prince, superhero, merperson, fairy, zombie
    case knight
    case harvester, ranger, miner, sailor, shepherd, hunter, stargazer

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .farmer: "🧑‍🌾"
        case .farmerWoman: "👩‍🌾"
        case .farmerMan: "👨‍🌾"
        case .builder: "👷"
        case .cowboy: "🤠"
        case .detective: "🕵️"
        case .elf: "🧝"
        case .rockstar: "🧑‍🎤"
        case .robot: "🤖"
        case .genie: "🧞"
        case .wizard: "🧙"
        case .ninja: "🥷"
        case .vampire: "🧛"
        case .astronaut: "🧑‍🚀"
        case .princess: "👸"
        case .prince: "🤴"
        case .superhero: "🦸"
        case .merperson: "🧜"
        case .fairy: "🧚"
        case .zombie: "🧟"
        case .knight: "⚔️"
        case .harvester: "🌾"
        case .ranger: "🏹"
        case .miner: "⛏️"
        case .sailor: "⚓"
        case .shepherd: "🐑"
        case .hunter: "🗡️"
        case .stargazer: "🔭"
        }
    }

    var name: String { tr("skin.\(rawValue)") }

    var unlock: SkinUnlock {
        switch self {
        case .farmer, .farmerWoman, .farmerMan: .free
        case .builder: .level(10)
        case .cowboy: .level(20)
        case .detective: .level(30)
        case .elf: .level(40)
        case .rockstar: .level(50)
        case .robot: .product(.starter)
        case .genie: .product(.pro)
        case .knight: .product(.garden)
        case .harvester: .constellation(.harvest)
        case .ranger: .constellation(.forest)
        case .miner: .constellation(.depths)
        case .sailor: .constellation(.sea)
        case .shepherd: .constellation(.beasts)
        case .hunter: .constellation(.monsters)
        case .stargazer: .constellation(.sky)
        default: .product(.skins)
        }
    }

    static var collection: [Skin] { allCases.filter { if case .product(.skins) = $0.unlock { return true } else { return false } } }
}
