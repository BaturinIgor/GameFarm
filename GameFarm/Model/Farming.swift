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
    /// Сколько секунд роста сэкономили полив и удобрения.
    var boost: Double = 0
    var watered = false
    /// Множитель времени роста на момент посадки (оранжерея ускоряет). Нет в старых сохранениях.
    var speed: Double?
    /// Удобрена ли и сколько урожая сверху.
    var fertilized: Bool?
    var extra: Int?

    var isEmpty: Bool { crop == nil }

    /// Полное время роста с учётом оранжереи и полива.
    var growTime: Double {
        guard let crop else { return 0 }
        return max(0, crop.spec.growTime * (speed ?? 1) - boost)
    }

    var readyAt: Date? {
        guard crop != nil, let plantedAt else { return nil }
        return plantedAt.addingTimeInterval(growTime)
    }

    /// Доля роста от 0 до 1.
    func progress(at now: Date) -> Double {
        guard crop != nil, let plantedAt else { return 0 }
        return min(1, max(0, now.timeIntervalSince(plantedAt) / max(1, growTime)))
    }

    func isRipe(at now: Date) -> Bool { crop != nil && progress(at: now) >= 1 }

    /// Стадия спрайта: 0 росток ... 3 спелое.
    func stage(at now: Date) -> Int {
        let p = progress(at: now)
        if p >= 1 { return 3 }
        return min(2, Int(p * 3))
    }
}

/// Удобрения: ускоряют рост и прибавляют урожай. Делаются из ресурсов.
enum FertilizerID: String, CaseIterable, Identifiable, Codable {
    case compost, superGrow, magic

    var id: String { rawValue }
    var name: String { tr("fert.\(rawValue)") }
    var icon: String {
        switch self {
        case .compost: "fert_compost"
        case .superGrow: "fert_super"
        case .magic: "fert_magic"
        }
    }

    /// Какая доля оставшегося времени роста пропадает.
    var cut: Double {
        switch self {
        case .compost: 0.4
        case .superGrow: 0.7
        case .magic: 0.85
        }
    }

    /// Сколько урожая сверху.
    var extra: Int {
        switch self {
        case .compost: 0
        case .superGrow: 1
        case .magic: 2
        }
    }

    var level: Int {
        switch self {
        case .compost: 3
        case .superGrow: 10
        case .magic: 22
        }
    }

    var recipe: Cost {
        switch self {
        case .compost: Cost(coins: 10, (.berries, 6), (.wood, 6), (.wheat, 3))
        case .superGrow: Cost(coins: 60, (.fish, 5), (.mushrooms, 6), (.carrots, 6))
        case .magic: Cost(coins: 400, (.herbs, 10), (.honey, 3), (.crystal, 1))
        }
    }

    var effectText: String {
        extra > 0 ? tr("fert.effect.extra", Fmt.pct(cut), extra) : tr("fert.effect", Fmt.pct(cut))
    }
}

/// Лейка: чем лучше, тем сильнее полив; с 3 уровня поливает весь огород сразу.
enum WateringCan {
    static let maxLevel = 5

    static func boost(_ level: Int) -> Double { 0.2 + 0.075 * Double(max(1, min(maxLevel, level)) - 1) }

    /// Больше этой доли оставшегося времени полив не срезает.
    static let maxCut = 0.75

    static func waterAll(_ level: Int) -> Bool { level >= 3 }

    static func requiredLevel(_ next: Int) -> Int {
        switch next {
        case 2: 5
        case 3: 12
        case 4: 20
        default: 28
        }
    }

    static func cost(_ next: Int) -> Cost {
        switch next {
        case 2: Cost(coins: 300, (.iron, 10))
        case 3: Cost(coins: 1500, (.iron, 30), (.bamboo, 20))
        case 4: Cost(coins: 5000, (.gold, 20), (.ice, 20))
        default: Cost(coins: 15000, (.diamond, 6), (.crystal, 4))
        }
    }
}

/// Что случилось с грядкой по кнопке в интерфейсе: сцена покажет эффект.
struct GardenEvent {
    enum Kind {
        case planted
        case harvested(ResourceAmount)
        case boosted
    }

    let bed: Int
    let kind: Kind
}

enum Garden {
    static let maxBeds = 12
    /// Оранжерея: растения растут на 20% быстрее.
    static let greenhouseSpeed = 0.8

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
        case map
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
