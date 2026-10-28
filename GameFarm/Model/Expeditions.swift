import Foundation

/// Идущая экспедиция: куда ушли, когда вернёмся и что успели добыть.
struct ExpeditionRun: Codable, Equatable {
    var location: String
    var endsAt: Date
    var returnTo: String
    var loot: [String: Int] = [:]
    var coins = 0

    var id: LocationID? { LocationID(rawValue: location) }
    var home: LocationID { LocationID(rawValue: returnTo) ?? .meadow }

    var items: [ResourceAmount] {
        ResourceKind.allCases.compactMap { kind in
            guard let n = loot[kind.rawValue], n > 0 else { return nil }
            return ResourceAmount(kind: kind, amount: n)
        }
    }
}

/// Итог экспедиции для окна после возвращения.
struct ExpeditionReport: Equatable {
    let location: LocationID
    let items: [ResourceAmount]
    let coins: Int
}

enum Expedition {
    /// Базовая длительность вылазки.
    static let duration: TimeInterval = 4 * 60

    /// Сколько билетов стоит вылазка: чем ценнее место, тем дороже.
    static func cost(_ id: LocationID) -> Int {
        switch id {
        case .treasureIsland: return 2
        case .luckyMeadow: return 3
        default: return 1
        }
    }

    /// Дорогие вылазки длятся дольше: на каждый билет сверху ещё минута.
    static func duration(_ id: LocationID) -> TimeInterval {
        duration + Double(cost(id) - 1) * 60
    }
    /// Бесплатный билет раз в сутки.
    static let freeTicketEvery: TimeInterval = 20 * 3600
    static let maxTickets = 9
    static let ticketPack = 5

    /// Иконка экспедиции в списке.
    static func icon(_ id: LocationID) -> String {
        switch id {
        case .goldMine: return "gold"
        case .treasureIsland: return "chest_gold"
        case .luckyMeadow: return "goldenApple"
        default: return "compass"
        }
    }

    /// Чем особенна каждая экспедиция.
    static func perk(_ id: LocationID) -> String {
        tr("exp.\(id.rawValue).perk")
    }

    /// Во сколько раз больше добычи в экспедиции.
    static func yieldBonus(_ id: LocationID) -> Double {
        switch id {
        case .goldMine: return 1.5
        case .treasureIsland: return 2
        case .luckyMeadow: return 3
        default: return 1
        }
    }

    /// Ресурсы восстанавливаются быстрее.
    static let respawnMult = 0.35
}

enum RoyalGarden {
    /// Королевский сундук открывается раз в сутки.
    static let chestEvery: TimeInterval = 22 * 3600
    /// Белая капибара в саду даёт бонус ко всей добыче.
    static let capybaraYield = 0.1
}
