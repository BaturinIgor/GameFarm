import Foundation

/// Культура для грядки: семена покупаются в лавке, растут по реальному времени (и пока игры нет).
enum CropID: String, CaseIterable, Identifiable, Codable {
    case wheat, carrot, tomato, potato, strawberry, corn, cabbage, eggplant, pumpkin, sunflower, chili, grapes

    var id: String { rawValue }

    var spec: CropSpec { CropSpec.table[self]! }

    var name: String { spec.produce.name }

    /// Пиксельные спрайты: crop_<имя>_0...3 и иконка семян ic_seed_<имя>.
    var sprite: String { "crop_\(rawValue)" }
    var seedIcon: String { "seed_\(rawValue)" }
}

struct CropSpec {
    let level: Int
    let seedPrice: Int
    /// Время роста в секундах.
    let growTime: Double
    let yield: Int
    let produce: ResourceKind
    let xp: Int

    static let table: [CropID: CropSpec] = [
        .wheat: CropSpec(level: 1, seedPrice: 4, growTime: 60, yield: 3, produce: .wheat, xp: 4),
        .carrot: CropSpec(level: 2, seedPrice: 6, growTime: 120, yield: 8, produce: .carrots, xp: 6),
        .tomato: CropSpec(level: 4, seedPrice: 10, growTime: 180, yield: 4, produce: .tomato, xp: 8),
        .potato: CropSpec(level: 6, seedPrice: 14, growTime: 300, yield: 5, produce: .potato, xp: 12),
        .strawberry: CropSpec(level: 8, seedPrice: 20, growTime: 480, yield: 6, produce: .strawberry, xp: 18),
        .corn: CropSpec(level: 11, seedPrice: 30, growTime: 720, yield: 4, produce: .corn, xp: 26),
        .cabbage: CropSpec(level: 14, seedPrice: 40, growTime: 900, yield: 3, produce: .cabbage, xp: 32),
        .eggplant: CropSpec(level: 17, seedPrice: 55, growTime: 1200, yield: 4, produce: .eggplant, xp: 42),
        .pumpkin: CropSpec(level: 20, seedPrice: 70, growTime: 1800, yield: 2, produce: .pumpkin, xp: 60),
        .sunflower: CropSpec(level: 24, seedPrice: 90, growTime: 2700, yield: 3, produce: .sunflower, xp: 85),
        .chili: CropSpec(level: 28, seedPrice: 120, growTime: 3600, yield: 5, produce: .chili, xp: 110),
        .grapes: CropSpec(level: 33, seedPrice: 160, growTime: 5400, yield: 4, produce: .grapes, xp: 160)
    ]
}

/// Одна грядка: что посажено, когда и полита ли.
struct Bed: Codable, Equatable {
    var crop: CropID?
    var plantedAt: Date?
    /// Сколько секунд роста сэкономил полив.
    var boost: Double = 0
    var watered = false

    var isEmpty: Bool { crop == nil }

    var readyAt: Date? {
        guard let crop, let plantedAt else { return nil }
        return plantedAt.addingTimeInterval(max(0, crop.spec.growTime - boost))
    }

    /// Доля роста от 0 до 1.
    func progress(at now: Date) -> Double {
        guard let crop, let plantedAt else { return 0 }
        let total = max(1, crop.spec.growTime - boost)
        return min(1, max(0, now.timeIntervalSince(plantedAt) / total))
    }

    func isRipe(at now: Date) -> Bool { crop != nil && progress(at: now) >= 1 }

    /// Стадия спрайта: 0 росток ... 3 спелое.
    func stage(at now: Date) -> Int {
        let p = progress(at: now)
        if p >= 1 { return 3 }
        return min(2, Int(p * 3))
    }
}

enum Garden {
    static let maxBeds = 12
    /// Полив сокращает оставшееся время роста.
    static let waterBoost = 0.3

    /// Грядки открываются с уровнем: 4 сразу и ещё по одной каждые 4 уровня.
    static func beds(at level: Int) -> Int {
        min(maxBeds, 4 + level / 4)
    }

    /// Уровень, на котором откроется грядка с номером index (с нуля).
    static func levelFor(bed index: Int) -> Int {
        max(1, (index - 3) * 4)
    }
}

// MARK: Лавка

/// Обмен дня в лавке: отдать ресурсы и получить монеты, билет или семена.
struct TradeDeal: Identifiable, Equatable {
    enum Reward: Equatable {
        case coins(Int)
        case ticket
        case seeds(CropID, Int)
    }

    let id: Int
    let give: [ResourceAmount]
    let coinsPrice: Int
    let reward: Reward
}

/// Товар бродячего торговца.
struct WandererOffer: Identifiable, Equatable {
    enum Goods: Equatable {
        case ticket
        case seeds(CropID, Int)
        case resource(ResourceKind, Int)
    }

    let id: Int
    let goods: Goods
    let price: Int
}

/// Бродячий торговец: появляется в одной из локаций ненадолго.
struct WandererVisit: Equatable {
    let location: LocationID
    let until: Date
    var offers: [WandererOffer]
    var bought: Set<Int> = []
}

/// Детерминированный генератор, чтобы обмены дня были одинаковыми весь день.
struct DayRandom {
    private var state: UInt64

    init(seed: Int) {
        state = UInt64(truncatingIfNeeded: seed) &* 0x9E3779B97F4A7C15 &+ 0x2545F4914F6CDD1D
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    mutating func int(_ range: ClosedRange<Int>) -> Int {
        range.lowerBound + Int(next() % UInt64(range.upperBound - range.lowerBound + 1))
    }

    mutating func pick<T>(_ items: [T]) -> T {
        items[Int(next() % UInt64(items.count))]
    }
}
