import UIKit

/// Ивенты: каждую неделю новый праздник со своей картой, очками и пропуском наград.
enum EventID: String, CaseIterable, Identifiable, Codable {
    case harvestFest, slimeNight, winterTale, beachParty

    var id: String { rawValue }

    var name: String { tr("event.\(rawValue)") }
    var blurb: String { tr("event.\(rawValue).blurb") }

    var emoji: String {
        switch self {
        case .harvestFest: "🎃"
        case .slimeNight: "🟢"
        case .winterTale: "🎁"
        case .beachParty: "🏖️"
        }
    }

    /// Пиксельная иконка ивента.
    var icon: String {
        switch self {
        case .harvestFest: "pumpkin"
        case .slimeNight: "slime"
        case .winterTale: "chest_gold"
        case .beachParty: "shell"
        }
    }

    /// Карта ивента.
    var location: LocationID {
        switch self {
        case .harvestFest: .harvestFest
        case .slimeNight: .slimeNight
        case .winterTale: .winterTale
        case .beachParty: .beachParty
        }
    }

    /// Особая точка добычи на карте ивента.
    var node: NodeType {
        switch self {
        case .harvestFest: .pumpkinPatch
        case .slimeNight: .slimeCrystal
        case .winterTale: .giftBox
        case .beachParty: .sandCastle
        }
    }

    /// Спрайт-превью особой точки.
    var preview: String {
        switch self {
        case .harvestFest: "crop_pumpkin_3"
        case .slimeNight: "crystal_slime"
        case .winterTale: "gift_red"
        case .beachParty: "sandcastle"
        }
    }

    /// Семена и блюдо в наградах пропуска.
    var crop: CropID {
        switch self {
        case .harvestFest: .pumpkin
        case .slimeNight: .grapes
        case .winterTale: .cabbage
        case .beachParty: .strawberry
        }
    }

    var dish: DishID {
        switch self {
        case .harvestFest: .pumpkinSoup
        case .slimeNight: .popcorn
        case .winterTale: .stew
        case .beachParty: .juice
        }
    }

    var decor: DecorID {
        switch self {
        case .harvestFest: .jackLantern
        case .slimeNight: .slimeLamp
        case .winterTale: .snowman
        case .beachParty: .sandcastle
        }
    }

    var skin: Skin {
        switch self {
        case .harvestFest: .autumn
        case .slimeNight: .slimeKing
        case .winterTale: .frost
        case .beachParty: .surfer
        }
    }

    /// Цвета баннера: верх и низ.
    var colors: (UInt32, UInt32) {
        switch self {
        case .harvestFest: (0xFFB04A, 0xB8531A)
        case .slimeNight: (0x8BE36A, 0x2E6B3A)
        case .winterTale: (0x9FD8FF, 0x3F72C8)
        case .beachParty: (0xFFE08A, 0x2FA8C8)
        }
    }
}

/// Один проход ивента: какой праздник и когда.
struct EventRun: Equatable, Identifiable {
    let event: EventID
    let index: Int
    let start: Date
    let end: Date

    var id: Int { index }
    /// Ключ прогресса: очки и награды сбрасываются с каждым новым проходом.
    var key: String { "\(event.rawValue)-\(index)" }

    func active(at date: Date = Date()) -> Bool { date >= start && date < end }
}

enum Events {
    /// С какого уровня открыты ивенты.
    static let minLevel = 5
    static let duration: TimeInterval = 7 * 86_400
    /// Отсчёт недель: понедельник, 26 октября 2026 (UTC).
    static let epoch = Date(timeIntervalSince1970: 1_792_972_800)

    static func run(index: Int) -> EventRun {
        let n = EventID.allCases.count
        let event = EventID.allCases[((index % n) + n) % n]
        let start = epoch.addingTimeInterval(Double(index) * duration)
        return EventRun(event: event, index: index, start: start, end: start.addingTimeInterval(duration))
    }

    static func index(at date: Date) -> Int {
        Int((date.timeIntervalSince(epoch) / duration).rounded(.down))
    }

    static var current: EventRun { run(index: index(at: Date())) }

    /// Ближайшие ивенты после текущего.
    static func upcoming(_ count: Int = 3) -> [EventRun] {
        let now = index(at: Date())
        return (1...count).map { run(index: now + $0) }
    }

    // MARK: Очки

    /// Очки за добычу на карте ивента: особая точка даёт больше.
    static func points(for type: NodeType) -> Int {
        switch type {
        case .pumpkinPatch, .giftBox, .sandCastle, .slimeCrystal: 3
        default: 1
        }
    }

    static func points(for monster: MonsterKind) -> Int { monster == .slimeGold ? 15 : 5 }

    /// Монстры на картах ивентов.
    static func monsters(_ event: EventID) -> [(MonsterKind, Int)] {
        switch event {
        case .harvestFest: [(.slimeGreen, 3), (.skeleton, 2)]
        case .slimeNight: [(.slimeGreen, 4), (.slimeBlue, 2), (.slimePurple, 2), (.slimeGold, 1)]
        case .winterTale: [(.slimeIce, 4)]
        case .beachParty: [(.slimeBlue, 3), (.slimeGold, 1)]
        }
    }

    /// Уровень монстров на карте ивента растёт вместе с героем.
    static func monsterLevel(playerLevel: Int) -> Int { max(2, playerLevel / 2 + 1) }

    // MARK: Пропуск

    static let tiers = 20
    /// После последней ступени каждые столько очков дают бонусный сундук.
    static let bonusEvery = 150

    /// Сколько очков нужно на ступень (с единицы).
    static func cost(tier: Int) -> Int { 40 + 5 * tier }

    /// Сколько всего очков нужно, чтобы открыть ступень.
    static func threshold(tier: Int) -> Int {
        guard tier > 0 else { return 0 }
        return (1...tier).reduce(0) { $0 + cost(tier: $1) }
    }

    static var total: Int { threshold(tier: tiers) }

    /// Сколько ступеней открыто при таких очках.
    static func tier(points: Int) -> Int {
        var t = 0
        while t < tiers && points >= threshold(tier: t + 1) { t += 1 }
        return t
    }

    enum Reward: Equatable {
        case coins(Int)
        case tickets(Int)
        case seeds(Int)
        case dish(Int)
        case cards(Int)
        case sparks(Int)
        case decor
        case skin
    }

    static func free(tier: Int) -> Reward {
        switch tier {
        case 1: .coins(200)
        case 2: .seeds(4)
        case 3: .cards(1)
        case 4: .coins(350)
        case 5: .tickets(1)
        case 6: .dish(1)
        case 7: .coins(500)
        case 8: .cards(1)
        case 9: .seeds(6)
        case 10: .decor
        case 11: .coins(700)
        case 12: .dish(2)
        case 13: .tickets(1)
        case 14: .cards(2)
        case 15: .sparks(1)
        case 16: .coins(1000)
        case 17: .tickets(2)
        case 18: .dish(2)
        case 19: .cards(2)
        default: .coins(2000)
        }
    }

    static func vip(tier: Int) -> Reward {
        switch tier {
        case 1: .coins(500)
        case 2: .tickets(1)
        case 3: .cards(2)
        case 4: .dish(2)
        case 5: .sparks(1)
        case 6: .coins(900)
        case 7: .tickets(2)
        case 8: .seeds(10)
        case 9: .cards(2)
        case 10: .sparks(2)
        case 11: .coins(1500)
        case 12: .dish(3)
        case 13: .tickets(2)
        case 14: .cards(3)
        case 15: .sparks(2)
        case 16: .coins(2500)
        case 17: .tickets(3)
        case 18: .cards(3)
        case 19: .sparks(3)
        default: .skin
        }
    }

    /// Монеты в наградах растут с уровнем.
    static func coins(_ base: Int, level: Int) -> Int {
        Int((Double(base) * (1 + Double(level) * 0.12)).rounded())
    }

    /// Бонусный сундук после всех ступеней.
    static func bonusCoins(level: Int) -> Int { coins(600, level: level) }
}
