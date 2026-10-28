import Foundation

/// Весь прогресс игрока. Хранится на телефоне в JSON.
struct SaveData: Codable {
    var level = 1
    var xp = 0
    var coins = 30
    var storage: [ResourceKind: Int] = [:]
    var backpack: [ResourceKind: Int] = [:]
    var tools: [ToolKind: Int] = [.axe: 1, .pickaxe: 1, .rod: 1, .sword: 1, .armor: 1]
    var talents: [TalentID: Int] = [:]
    var unlocked: [LocationID] = [.meadow]
    var current: LocationID = .meadow
    /// Звёзды каждого полученного животного (1...5).
    var animals: [AnimalID: Int] = [:]
    var active: [AnimalID] = []
    var gathered: [ResourceKind: Int] = [:]
    var harvests = 0
    var coinsEarned = 0
    var lastSeen = Date()
    var tutorialDone = false
    var quests: [Quest] = []
    var questsDone = 0
    var claimed: [String] = []
    var bonusTalentPoints = 0
    var treasures = 0
    var purchases: [String] = []
    var granted: [String] = []
    var skin: String = Skin.farmer.rawValue
    var starterOfferUntil: Date?
    var starterOffers = 0
    var luckUntil: Date?
    var luckReadyAt: Date?
    var adsWatched = 0
    /// Открытые проходы между локациями.
    var openGates: [String] = []
    var tickets = 1
    var lastFreeTicket: Date?
    var gardenChestAt: Date?
    var expedition: ExpeditionRun?
    /// Обработанные покупки расходников (чтобы не выдать билеты дважды).
    var consumed: [String] = []
    // Перерождение: всё ниже переживает сброс.
    var rebirths = 0
    var sparks = 0
    var sparksEarned = 0
    var legacy: [LegacyPerk: Int] = [:]
    // Огород и лавка
    var beds: [Bed] = []
    var seeds: [CropID: Int] = [:]
    var selectedSeed: CropID?
    var cropsHarvested = 0
    /// День обменов в лавке и какие обмены уже сделаны.
    var dealsDay = 0
    var dealsBought: [Int] = []
    // Дом, кухня и календарь
    var houseFloors: [HouseFloor] = [.ground]
    var decor: [String: DecorID] = [:]
    var dishes: [DishID: Int] = [:]
    var cooking: [CookJob] = []
    /// Блюда, которые сейчас действуют, и до какого времени.
    var meals: [DishID: Date] = [:]
    var loginDay = 0
    var loginClaims = 0
    // Охота
    var hunts: [HuntContract] = []
    var huntDay = 0
    var kills = 0
    // Коллекция
    var cards: [CardID: Int] = [:]
    var awaken: [AnimalID: Int] = [:]
    var shiny: [AnimalID] = []
    // Ивенты
    var eventKey = ""
    var eventPoints = 0
    var eventFree: [Int] = []
    var eventVip: [Int] = []
    var eventBonus = 0
    var vipKeys: [String] = []
    var eventSeen = ""
    var eventDecor: [String] = []
    var eventSkins: [String] = []
    /// Самый высокий уровень за все перерождения: образы за уровень остаются открытыми.
    var bestLevel = 1
    // Огород и кухня
    var canLevel = 1
    var fertilizers: [FertilizerID: Int] = [:]
    var selectedFertilizer: FertilizerID?
    var kitchenLevel = 1
    // Снаряжение и подземелья
    var weapon: WeaponID = .forged
    var weapons: [WeaponID: Int] = [:]
    var potions = 0
    var dungeonBest: [DungeonID: Int] = [:]

    init() {}

    enum CodingKeys: String, CodingKey {
        case level, xp, coins, storage, backpack, tools, talents, unlocked, current
        case animals, active, gathered, harvests, coinsEarned, lastSeen, tutorialDone
        case quests, questsDone, claimed, bonusTalentPoints, treasures
        case purchases, granted, skin, starterOfferUntil, starterOffers, luckUntil, luckReadyAt, adsWatched
        case openGates, tickets, lastFreeTicket, gardenChestAt, expedition, consumed
        case rebirths, sparks, sparksEarned, legacy
        case beds, seeds, selectedSeed, cropsHarvested, dealsDay, dealsBought
        case houseFloors, decor, dishes, cooking, meal, mealUntil, meals, loginDay, loginClaims
        case hunts, huntDay, kills
        case cards, awaken, shiny
        case eventKey, eventPoints, eventFree, eventVip, eventBonus, vipKeys, eventSeen, eventDecor, eventSkins
        case bestLevel, canLevel, fertilizers, selectedFertilizer, kitchenLevel
        case weapon, weapons, potions, dungeonBest
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = SaveData()
        level = try c.decodeIfPresent(Int.self, forKey: .level) ?? d.level
        xp = try c.decodeIfPresent(Int.self, forKey: .xp) ?? d.xp
        coins = try c.decodeIfPresent(Int.self, forKey: .coins) ?? d.coins
        storage = try Self.map(c.decodeIfPresent([String: Int].self, forKey: .storage)) ?? d.storage
        backpack = try Self.map(c.decodeIfPresent([String: Int].self, forKey: .backpack)) ?? d.backpack
        tools = try Self.map(c.decodeIfPresent([String: Int].self, forKey: .tools)) ?? d.tools
        talents = try Self.map(c.decodeIfPresent([String: Int].self, forKey: .talents)) ?? d.talents
        animals = Self.animals(try c.decodeIfPresent([String: Int].self, forKey: .animals))
        gathered = try Self.map(c.decodeIfPresent([String: Int].self, forKey: .gathered)) ?? d.gathered
        unlocked = try Self.list(c.decodeIfPresent([String].self, forKey: .unlocked)) ?? d.unlocked
        var seenActive: [AnimalID] = []
        for raw in try c.decodeIfPresent([String].self, forKey: .active) ?? [] {
            if let id = AnimalID.from(raw), !seenActive.contains(id) { seenActive.append(id) }
        }
        active = seenActive
        if let raw = try c.decodeIfPresent(String.self, forKey: .current), let id = LocationID(rawValue: raw) {
            current = id
        }
        harvests = try c.decodeIfPresent(Int.self, forKey: .harvests) ?? 0
        coinsEarned = try c.decodeIfPresent(Int.self, forKey: .coinsEarned) ?? 0
        lastSeen = try c.decodeIfPresent(Date.self, forKey: .lastSeen) ?? Date()
        tutorialDone = try c.decodeIfPresent(Bool.self, forKey: .tutorialDone) ?? false
        quests = (try? c.decodeIfPresent([Quest].self, forKey: .quests)) ?? []
        questsDone = try c.decodeIfPresent(Int.self, forKey: .questsDone) ?? 0
        claimed = try c.decodeIfPresent([String].self, forKey: .claimed) ?? []
        bonusTalentPoints = try c.decodeIfPresent(Int.self, forKey: .bonusTalentPoints) ?? 0
        treasures = try c.decodeIfPresent(Int.self, forKey: .treasures) ?? 0
        purchases = try c.decodeIfPresent([String].self, forKey: .purchases) ?? []
        granted = try c.decodeIfPresent([String].self, forKey: .granted) ?? []
        skin = try c.decodeIfPresent(String.self, forKey: .skin) ?? Skin.farmer.rawValue
        starterOfferUntil = try c.decodeIfPresent(Date.self, forKey: .starterOfferUntil)
        starterOffers = try c.decodeIfPresent(Int.self, forKey: .starterOffers) ?? 0
        luckUntil = try c.decodeIfPresent(Date.self, forKey: .luckUntil)
        luckReadyAt = try c.decodeIfPresent(Date.self, forKey: .luckReadyAt)
        adsWatched = try c.decodeIfPresent(Int.self, forKey: .adsWatched) ?? 0
        openGates = try c.decodeIfPresent([String].self, forKey: .openGates) ?? []
        tickets = try c.decodeIfPresent(Int.self, forKey: .tickets) ?? d.tickets
        lastFreeTicket = try c.decodeIfPresent(Date.self, forKey: .lastFreeTicket)
        gardenChestAt = try c.decodeIfPresent(Date.self, forKey: .gardenChestAt)
        expedition = try? c.decodeIfPresent(ExpeditionRun.self, forKey: .expedition)
        consumed = try c.decodeIfPresent([String].self, forKey: .consumed) ?? []
        rebirths = try c.decodeIfPresent(Int.self, forKey: .rebirths) ?? 0
        sparks = try c.decodeIfPresent(Int.self, forKey: .sparks) ?? 0
        sparksEarned = try c.decodeIfPresent(Int.self, forKey: .sparksEarned) ?? 0
        legacy = try Self.map(c.decodeIfPresent([String: Int].self, forKey: .legacy)) ?? [:]
        beds = (try? c.decodeIfPresent([Bed].self, forKey: .beds)) ?? []
        seeds = try Self.map(c.decodeIfPresent([String: Int].self, forKey: .seeds)) ?? [:]
        selectedSeed = (try? c.decodeIfPresent(String.self, forKey: .selectedSeed)).flatMap { CropID(rawValue: $0) }
        cropsHarvested = try c.decodeIfPresent(Int.self, forKey: .cropsHarvested) ?? 0
        dealsDay = try c.decodeIfPresent(Int.self, forKey: .dealsDay) ?? 0
        dealsBought = try c.decodeIfPresent([Int].self, forKey: .dealsBought) ?? []
        houseFloors = Self.list(try c.decodeIfPresent([String].self, forKey: .houseFloors)) ?? [.ground]
        if !houseFloors.contains(.ground) { houseFloors.append(.ground) }
        var decorMap: [String: DecorID] = [:]
        for (slot, raw) in try c.decodeIfPresent([String: String].self, forKey: .decor) ?? [:] {
            if let id = DecorID(rawValue: raw) { decorMap[slot] = id }
        }
        decor = decorMap
        dishes = try Self.map(c.decodeIfPresent([String: Int].self, forKey: .dishes)) ?? [:]
        cooking = (try? c.decodeIfPresent([CookJob].self, forKey: .cooking)) ?? []
        var mealMap: [DishID: Date] = [:]
        for (key, until) in (try? c.decodeIfPresent([String: Date].self, forKey: .meals)) ?? [:] {
            if let dish = DishID(rawValue: key) { mealMap[dish] = until }
        }
        // Старые сохранения: одно блюдо.
        if let old = (try? c.decodeIfPresent(String.self, forKey: .meal)).flatMap({ DishID(rawValue: $0) }),
           let until = try? c.decodeIfPresent(Date.self, forKey: .mealUntil) {
            mealMap[old] = until
        }
        meals = mealMap
        loginDay = try c.decodeIfPresent(Int.self, forKey: .loginDay) ?? 0
        loginClaims = try c.decodeIfPresent(Int.self, forKey: .loginClaims) ?? 0
        hunts = (try? c.decodeIfPresent([HuntContract].self, forKey: .hunts)) ?? []
        huntDay = try c.decodeIfPresent(Int.self, forKey: .huntDay) ?? 0
        kills = try c.decodeIfPresent(Int.self, forKey: .kills) ?? 0
        cards = try Self.map(c.decodeIfPresent([String: Int].self, forKey: .cards)) ?? [:]
        var awakenMap: [AnimalID: Int] = [:]
        for (key, value) in try c.decodeIfPresent([String: Int].self, forKey: .awaken) ?? [:] {
            if let id = AnimalID.from(key) { awakenMap[id] = value }
        }
        awaken = awakenMap
        shiny = (try c.decodeIfPresent([String].self, forKey: .shiny) ?? []).compactMap { AnimalID.from($0) }
        eventKey = try c.decodeIfPresent(String.self, forKey: .eventKey) ?? ""
        eventPoints = try c.decodeIfPresent(Int.self, forKey: .eventPoints) ?? 0
        eventFree = try c.decodeIfPresent([Int].self, forKey: .eventFree) ?? []
        eventVip = try c.decodeIfPresent([Int].self, forKey: .eventVip) ?? []
        eventBonus = try c.decodeIfPresent(Int.self, forKey: .eventBonus) ?? 0
        vipKeys = try c.decodeIfPresent([String].self, forKey: .vipKeys) ?? []
        eventSeen = try c.decodeIfPresent(String.self, forKey: .eventSeen) ?? ""
        eventDecor = try c.decodeIfPresent([String].self, forKey: .eventDecor) ?? []
        eventSkins = try c.decodeIfPresent([String].self, forKey: .eventSkins) ?? []
        bestLevel = max(level, try c.decodeIfPresent(Int.self, forKey: .bestLevel) ?? 1)
        canLevel = max(1, try c.decodeIfPresent(Int.self, forKey: .canLevel) ?? 1)
        fertilizers = try Self.map(c.decodeIfPresent([String: Int].self, forKey: .fertilizers)) ?? [:]
        selectedFertilizer = (try? c.decodeIfPresent(String.self, forKey: .selectedFertilizer)).flatMap { FertilizerID(rawValue: $0) }
        // Раньше вторая плита давалась подвалом: такие сохранения начинают со второго уровня кухни.
        kitchenLevel = max(houseFloors.contains(.basement) ? 2 : 1, try c.decodeIfPresent(Int.self, forKey: .kitchenLevel) ?? 1)
        weapon = (try? c.decodeIfPresent(String.self, forKey: .weapon)).flatMap { WeaponID(rawValue: $0) } ?? .forged
        weapons = try Self.map(c.decodeIfPresent([String: Int].self, forKey: .weapons)) ?? [:]
        potions = try c.decodeIfPresent(Int.self, forKey: .potions) ?? 0
        dungeonBest = try Self.map(c.decodeIfPresent([String: Int].self, forKey: .dungeonBest)) ?? [:]
        if weapon != .forged && (weapons[weapon] ?? 0) == 0 { weapon = .forged }
        // Забег по подземелью не сохраняется: после перезапуска - на поляну.
        if current.spec.kind == .dungeon { current = .meadow }

        if !unlocked.contains(.meadow) { unlocked.insert(.meadow, at: 0) }
        // Экспедиция и сад не открываются через список, туда попадают отдельно.
        if current.spec.kind == .world && !unlocked.contains(current) { current = .meadow }
        if current.spec.kind == .expedition && expedition == nil { current = .meadow }
        // Ивент закончился, пока игра была закрыта: возвращаемся домой.
        if current.spec.kind == .event && Events.current.event.location != current { current = .meadow }
        if let floor = current.floor, !houseFloors.contains(floor) { current = .meadow }
        for tool in ToolKind.upgradable where tools[tool] == nil { tools[tool] = 1 }
        active = active.filter { animals[$0] != nil }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(level, forKey: .level)
        try c.encode(xp, forKey: .xp)
        try c.encode(coins, forKey: .coins)
        try c.encode(Self.raw(storage), forKey: .storage)
        try c.encode(Self.raw(backpack), forKey: .backpack)
        try c.encode(Self.raw(tools), forKey: .tools)
        try c.encode(Self.raw(talents), forKey: .talents)
        try c.encode(Self.raw(animals), forKey: .animals)
        try c.encode(Self.raw(gathered), forKey: .gathered)
        try c.encode(unlocked.map(\.rawValue), forKey: .unlocked)
        try c.encode(active.map(\.rawValue), forKey: .active)
        try c.encode(current.rawValue, forKey: .current)
        try c.encode(harvests, forKey: .harvests)
        try c.encode(coinsEarned, forKey: .coinsEarned)
        try c.encode(lastSeen, forKey: .lastSeen)
        try c.encode(tutorialDone, forKey: .tutorialDone)
        try c.encode(quests, forKey: .quests)
        try c.encode(questsDone, forKey: .questsDone)
        try c.encode(claimed, forKey: .claimed)
        try c.encode(bonusTalentPoints, forKey: .bonusTalentPoints)
        try c.encode(treasures, forKey: .treasures)
        try c.encode(purchases, forKey: .purchases)
        try c.encode(granted, forKey: .granted)
        try c.encode(skin, forKey: .skin)
        try c.encodeIfPresent(starterOfferUntil, forKey: .starterOfferUntil)
        try c.encode(starterOffers, forKey: .starterOffers)
        try c.encodeIfPresent(luckUntil, forKey: .luckUntil)
        try c.encodeIfPresent(luckReadyAt, forKey: .luckReadyAt)
        try c.encode(adsWatched, forKey: .adsWatched)
        try c.encode(openGates, forKey: .openGates)
        try c.encode(tickets, forKey: .tickets)
        try c.encodeIfPresent(lastFreeTicket, forKey: .lastFreeTicket)
        try c.encodeIfPresent(gardenChestAt, forKey: .gardenChestAt)
        try c.encodeIfPresent(expedition, forKey: .expedition)
        try c.encode(consumed, forKey: .consumed)
        try c.encode(rebirths, forKey: .rebirths)
        try c.encode(sparks, forKey: .sparks)
        try c.encode(sparksEarned, forKey: .sparksEarned)
        try c.encode(Self.raw(legacy), forKey: .legacy)
        try c.encode(beds, forKey: .beds)
        try c.encode(Self.raw(seeds), forKey: .seeds)
        try c.encodeIfPresent(selectedSeed?.rawValue, forKey: .selectedSeed)
        try c.encode(cropsHarvested, forKey: .cropsHarvested)
        try c.encode(dealsDay, forKey: .dealsDay)
        try c.encode(dealsBought, forKey: .dealsBought)
        try c.encode(houseFloors.map(\.rawValue), forKey: .houseFloors)
        try c.encode(decor.mapValues(\.rawValue), forKey: .decor)
        try c.encode(Self.raw(dishes), forKey: .dishes)
        try c.encode(cooking, forKey: .cooking)
        try c.encode(Dictionary(uniqueKeysWithValues: meals.map { ($0.key.rawValue, $0.value) }), forKey: .meals)
        try c.encode(loginDay, forKey: .loginDay)
        try c.encode(loginClaims, forKey: .loginClaims)
        try c.encode(hunts, forKey: .hunts)
        try c.encode(huntDay, forKey: .huntDay)
        try c.encode(kills, forKey: .kills)
        try c.encode(Self.raw(cards), forKey: .cards)
        try c.encode(Self.raw(awaken), forKey: .awaken)
        try c.encode(shiny.map(\.rawValue), forKey: .shiny)
        try c.encode(eventKey, forKey: .eventKey)
        try c.encode(eventPoints, forKey: .eventPoints)
        try c.encode(eventFree, forKey: .eventFree)
        try c.encode(eventVip, forKey: .eventVip)
        try c.encode(eventBonus, forKey: .eventBonus)
        try c.encode(vipKeys, forKey: .vipKeys)
        try c.encode(eventSeen, forKey: .eventSeen)
        try c.encode(eventDecor, forKey: .eventDecor)
        try c.encode(eventSkins, forKey: .eventSkins)
        try c.encode(bestLevel, forKey: .bestLevel)
        try c.encode(canLevel, forKey: .canLevel)
        try c.encode(Self.raw(fertilizers), forKey: .fertilizers)
        try c.encodeIfPresent(selectedFertilizer?.rawValue, forKey: .selectedFertilizer)
        try c.encode(kitchenLevel, forKey: .kitchenLevel)
        try c.encode(weapon.rawValue, forKey: .weapon)
        try c.encode(Self.raw(weapons), forKey: .weapons)
        try c.encode(potions, forKey: .potions)
        try c.encode(Self.raw(dungeonBest), forKey: .dungeonBest)
    }

    private static func map<K: RawRepresentable & Hashable>(_ raw: [String: Int]?) -> [K: Int]? where K.RawValue == String {
        guard let raw else { return nil }
        var out: [K: Int] = [:]
        for (key, value) in raw {
            if let k = K(rawValue: key) { out[k] = value }
        }
        return out
    }

    /// Звери из старых версий переходят в новых; если двое стали одним, берём больше звёзд.
    private static func animals(_ raw: [String: Int]?) -> [AnimalID: Int] {
        var out: [AnimalID: Int] = [:]
        for (key, stars) in raw ?? [:] {
            guard let id = AnimalID.from(key) else { continue }
            out[id] = max(out[id] ?? 0, min(AnimalSpec.maxStars, stars))
        }
        return out
    }

    private static func list<K: RawRepresentable>(_ raw: [String]?) -> [K]? where K.RawValue == String {
        raw?.compactMap { K(rawValue: $0) }
    }

    private static func raw<K: RawRepresentable & Hashable>(_ dict: [K: Int]) -> [String: Int] where K.RawValue == String {
        var out: [String: Int] = [:]
        for (key, value) in dict { out[key.rawValue] = value }
        return out
    }
}

enum SaveFile {
    private static var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("gamefarm-save.json")
    }

    static func load() -> SaveData {
        guard let data = try? Data(contentsOf: url) else { return SaveData() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        if let save = try? decoder.decode(SaveData.self, from: data) { return save }
        // Файл не прочитался: сохраняем копию, чтобы следующая запись не уничтожила прогресс насовсем.
        let backup = url.deletingLastPathComponent()
            .appendingPathComponent("gamefarm-save.broken-\(Int(Date().timeIntervalSince1970)).json")
        try? data.write(to: backup, options: .atomic)
        return SaveData()
    }

    static func write(_ save: SaveData) {
        guard let data = encode(save) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func encode(_ save: SaveData) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return try? encoder.encode(save)
    }

    static func decode(_ data: Data) -> SaveData? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(SaveData.self, from: data)
    }

    /// Автокопия в папке приложения, её видно в Файлах (На iPhone > Harvest Hollow).
    static var autoBackupURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("HarvestHollow-backup.json")
    }

    static func writeAutoBackup(_ save: SaveData) {
        guard let data = encode(save) else { return }
        try? data.write(to: autoBackupURL, options: .atomic)
        // копия под старым названием игры больше не нужна
        let old = autoBackupURL.deletingLastPathComponent().appendingPathComponent("GameFarm-backup.json")
        if FileManager.default.fileExists(atPath: old.path) { try? FileManager.default.removeItem(at: old) }
    }

    /// Копия для отправки: временный файл с датой в имени.
    static func exportFile(_ save: SaveData) -> URL? {
        guard let data = encode(save) else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmm"
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("HarvestHollow-\(f.string(from: Date())).json")
        try? data.write(to: file, options: .atomic)
        return file
    }
}
