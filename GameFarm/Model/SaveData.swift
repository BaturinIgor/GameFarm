import Foundation

/// Весь прогресс игрока. Хранится на телефоне в JSON.
struct SaveData: Codable {
    var level = 1
    var xp = 0
    var coins = 30
    var storage: [ResourceKind: Int] = [:]
    var backpack: [ResourceKind: Int] = [:]
    var tools: [ToolKind: Int] = [.axe: 1, .pickaxe: 1, .rod: 1]
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

    init() {}

    enum CodingKeys: String, CodingKey {
        case level, xp, coins, storage, backpack, tools, talents, unlocked, current
        case animals, active, gathered, harvests, coinsEarned, lastSeen, tutorialDone
        case quests, questsDone, claimed, bonusTalentPoints, treasures
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
        animals = try Self.map(c.decodeIfPresent([String: Int].self, forKey: .animals)) ?? d.animals
        gathered = try Self.map(c.decodeIfPresent([String: Int].self, forKey: .gathered)) ?? d.gathered
        unlocked = try Self.list(c.decodeIfPresent([String].self, forKey: .unlocked)) ?? d.unlocked
        active = try Self.list(c.decodeIfPresent([String].self, forKey: .active)) ?? d.active
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

        if !unlocked.contains(.meadow) { unlocked.insert(.meadow, at: 0) }
        if !unlocked.contains(current) { current = .meadow }
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
    }

    private static func map<K: RawRepresentable & Hashable>(_ raw: [String: Int]?) -> [K: Int]? where K.RawValue == String {
        guard let raw else { return nil }
        var out: [K: Int] = [:]
        for (key, value) in raw {
            if let k = K(rawValue: key) { out[k] = value }
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
        return (try? decoder.decode(SaveData.self, from: data)) ?? SaveData()
    }

    static func write(_ save: SaveData) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let data = try? encoder.encode(save) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
