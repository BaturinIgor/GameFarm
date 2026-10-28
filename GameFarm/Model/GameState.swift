import Foundation
import Observation

/// Единое состояние игры. Сцена и интерфейс читают и меняют его напрямую.
@Observable
final class GameState {
    static let shared = GameState()

    private(set) var save: SaveData
    private(set) var stats = Stats()
    /// Бонусы ступеней снаряжения (собираются в recalc).
    private(set) var gear = GearPerks()
    /// Идущий забег по подземелью и итог последнего.
    private(set) var dungeonRun: DungeonRun?
    var dungeonReport: DungeonReport?
    /// Босс на арене: имя и сколько здоровья осталось.
    private(set) var bossInfo: BossInfo?

    // Временное состояние для интерфейса, не сохраняется.
    private(set) var encounter: Encounter?
    private(set) var backpackFull = false
    private(set) var toasts: [Toast] = []
    private(set) var banner: LocationID?
    var levelUp: LevelUpInfo?
    var offlineReport: OfflineReport?
    var treasureFound: Treasure?
    var offerPopup = false
    /// Закрытый проход рядом с персонажем.
    private(set) var gatePrompt: String?
    var expeditionReport: ExpeditionReport?
    var gardenChestFound: Treasure?
    /// Открыта крупная карта текущей локации (по нажатию на мини-карту).
    var bigMap = false
    /// Персонаж стоит у грядок.
    private(set) var nearGarden = false
    /// Рядом торговец: лавка у дома или бродячий.
    private(set) var traderPrompt: TraderKind?
    /// Бродячий торговец сейчас в одной из локаций.
    private(set) var wanderer: WandererVisit?
    /// Персонаж у двери дома или у загона.
    private(set) var placePrompt: PlaceKind?
    /// В доме: у какой станции или места стоит герой.
    private(set) var homePrompt: HomePrompt?
    /// Показать календарь наград при запуске.
    var loginPopup = false
    /// Здоровье героя (не сохраняется: после запуска герой здоров).
    private(set) var hp: Double = 100
    /// Рядом монстры: показываем сердечки.
    private(set) var inCombat = false
    /// Локации, куда можно дойти через открытые проходы.
    private(set) var reachable: Set<LocationID> = [.meadow]
    /// Через какие ворота персонаж пришёл в локацию (сцена ставит его к ним).
    @ObservationIgnored var arrivalGate: String?
    /// В какой точке дома появиться после перехода (лестница или дверь).
    @ObservationIgnored var arrivalStation: HomeStation?
    /// Растёт, когда та же локация получает новую карту (следующий этап ивента): сцена перестраивается.
    @ObservationIgnored var mapVersion = 0
    /// Вышли из дома: появляемся у двери на поляне.
    @ObservationIgnored var arriveAtDoor = false
    /// Посадки и сбор с кнопок интерфейса: сцена забирает и показывает эффекты.
    @ObservationIgnored var gardenEvents: [GardenEvent] = []

    @ObservationIgnored private var dirty = false
    @ObservationIgnored private var lastWrite = Date.distantPast
    @ObservationIgnored private var lastBackup = Date.distantPast
    @ObservationIgnored var lastSecondWind = Date.distantPast
    @ObservationIgnored var lastStandAt = Date.distantPast
    @ObservationIgnored var lastPotion = Date.distantPast
    @ObservationIgnored var dungeonReturn: LocationID = .meadow
    @ObservationIgnored var lastChest: DungeonReport?
    @ObservationIgnored private var bannerToken = 0

    private init() {
        save = SaveFile.load()
        migrateGates()
        refreshReachable()
        if save.current == .garden && !owns(.garden) { save.current = .meadow }
        if owns(.garden) && (save.weapons[.royalSword] ?? 0) == 0 { save.weapons[.royalSword] = WeaponID.royalSword.startTier }
        syncEvent()
        recalc()
        ensureQuests()
        checkStarterOffer()
        // На холодном старте фаза .active может прийти раньше, чем её начнут слушать.
        applyOfflineProgress()
    }

    // MARK: Сохранение

    func markDirty() { dirty = true }

    func saveIfNeeded() {
        guard dirty, Date().timeIntervalSince(lastWrite) > 4 else { return }
        saveNow()
    }

    func saveNow() {
        save.lastSeen = Date()
        SaveFile.write(save)
        dirty = false
        lastWrite = Date()
        if Date().timeIntervalSince(lastBackup) > 300 {
            lastBackup = Date()
            SaveFile.writeAutoBackup(save)
        }
    }

    // MARK: Резервная копия

    func exportBackup() -> URL? {
        save.lastSeen = Date()
        return SaveFile.exportFile(save)
    }

    /// Проверить файл копии: какой там уровень (nil, если файл не подходит).
    func peekBackup(_ data: Data) -> SaveData? { SaveFile.decode(data) }

    /// Заменить прогресс копией из файла.
    func restoreBackup(_ restored: SaveData) {
        save = restored
        save.lastSeen = Date()
        refreshReachable()
        encounter = nil
        gatePrompt = nil
        homePrompt = nil
        levelUp = nil
        offlineReport = nil
        expeditionReport = nil
        recalc()
        ensureQuests()
        SaveFile.write(save)
        toast("px:scroll2", tr("backup.restored", save.level))
        SoundFX.play(.success)
    }

    // MARK: Перерождение

    func legacyRank(_ perk: LegacyPerk) -> Int { save.legacy[perk] ?? 0 }

    /// Сколько искр даст перерождение прямо сейчас.
    var rebirthReward: Int {
        Rebirth.sparks(level: save.level, achievements: save.claimed.count, gates: save.openGates.count)
    }

    func canBuyLegacy(_ perk: LegacyPerk) -> Bool {
        let rank = legacyRank(perk)
        return rank < perk.maxRank && save.sparks >= perk.cost(rank: rank)
    }

    @discardableResult
    func buyLegacy(_ perk: LegacyPerk) -> Bool {
        guard canBuyLegacy(perk) else { return false }
        let rank = legacyRank(perk)
        save.sparks -= perk.cost(rank: rank)
        save.legacy[perk] = rank + 1
        if perk == .tools {
            for tool in ToolKind.upgradable {
                save.tools[tool] = max(tier(tool), min(ToolTier.maxTier, 1 + rank + 1))
            }
        }
        recalc()
        SoundFX.play(.unlock)
        markDirty()
        return true
    }

    /// Начать заново: уровень, ресурсы, звери, таланты и проходы обнуляются,
    /// а покупки, билеты, искры и наследие остаются. За забег начисляются искры.
    func rebirth() {
        let old = save
        let reward = rebirthReward
        save = SaveData()
        save.tutorialDone = true
        save.purchases = old.purchases
        save.granted = old.granted
        save.consumed = old.consumed
        save.tickets = max(old.tickets, 1)
        save.maps = old.maps
        save.lastFreeTicket = old.lastFreeTicket
        save.gardenChestAt = old.gardenChestAt
        save.starterOfferUntil = old.starterOfferUntil
        save.starterOffers = old.starterOffers
        save.luckUntil = old.luckUntil
        save.luckReadyAt = old.luckReadyAt
        save.adsWatched = old.adsWatched
        save.skin = old.skin
        save.legacy = old.legacy
        save.loginDay = old.loginDay
        save.loginClaims = old.loginClaims
        save.cards = old.cards
        save.shiny = old.shiny
        save.eventKey = old.eventKey
        save.eventPoints = old.eventPoints
        save.eventFree = old.eventFree
        save.eventVip = old.eventVip
        save.eventBonus = old.eventBonus
        save.vipKeys = old.vipKeys
        save.eventSeen = old.eventSeen
        save.eventDecor = old.eventDecor
        save.eventSkins = old.eventSkins
        save.bestLevel = max(old.bestLevel, old.level)
        save.potions = old.potions
        save.dungeonBest = old.dungeonBest
        save.weapons = Dictionary(uniqueKeysWithValues: old.weapons.keys.map { ($0, $0.startTier) })
        save.weapon = old.weapon
        save.rebirths = old.rebirths + (reward > 0 ? 1 : 0)
        save.sparks = old.sparks + reward
        save.sparksEarned = old.sparksEarned + reward
        save.coins += legacyRank(.capital) * Int(LegacyPerk.capital.perRank)
        let toolTier = min(ToolTier.maxTier, 1 + legacyRank(.tools))
        for tool in ToolKind.upgradable { save.tools[tool] = toolTier }
        if owns(.starter) {
            save.animals[.duckHat] = 1
            save.active = [.duckHat]
        }
        // Верные звери (наследие): лучшие звери остаются с одной звездой
        let keep = legacyRank(.companions)
        if keep > 0 {
            let best = old.animals.filter { $0.key != .duckHat && $0.value > 0 }
                .sorted { $0.value > $1.value }.prefix(keep).map(\.key)
            for id in best {
                save.animals[id] = 1
                if save.active.count < GameRules.maxActiveAnimals { save.active.append(id) }
            }
        }
        refreshReachable()
        encounter = nil
        backpackFull = false
        levelUp = nil
        offlineReport = nil
        treasureFound = nil
        expeditionReport = nil
        recalc()
        if !isSkinUnlocked(currentSkin) { save.skin = Skin.farmer.rawValue }
        ensureQuests()
        saveNow()
        if reward > 0 {
            SoundFX.play(.levelUp)
            toast("px:spark", tr("rebirth.toast", reward))
        }
    }

    func finishTutorial() {
        save.tutorialDone = true
        markDirty()
    }

    // MARK: Уровень

    var xpToNext: Int { GameRules.xpToNext(save.level) }

    var levelProgress: Double {
        guard save.level < GameRules.maxLevel else { return 1 }
        return min(1, Double(save.xp) / Double(max(1, xpToNext)))
    }

    var talentPointsTotal: Int {
        GameRules.talentPoints(at: save.level) + save.bonusTalentPoints + legacyRank(.talent) * Int(LegacyPerk.talent.perRank)
            + dungeonTalentPoints
    }

    /// Очко таланта за первую победу над каждым боссом подземелий (этажи 5 и 10).
    var dungeonTalentPoints: Int {
        DungeonID.allCases.reduce(0) { sum, id in
            let best = dungeonBest(id)
            return sum + (best >= 5 ? 1 : 0) + (best >= 10 ? 1 : 0)
        }
    }
    var talentPointsSpent: Int { save.talents.values.reduce(0, +) }
    var talentPointsFree: Int { max(0, talentPointsTotal - talentPointsSpent) }

    func gainXP(_ base: Int) {
        guard save.level < GameRules.maxLevel, base > 0 else { return }
        let amount = max(1, Int((Double(base) * stats.xpMult).rounded()))
        save.xp += amount
        let from = save.level
        while save.level < GameRules.maxLevel && save.xp >= GameRules.xpToNext(save.level) {
            save.xp -= GameRules.xpToNext(save.level)
            save.level += 1
            save.coins += GameRules.levelCoinReward(save.level)
        }
        if save.level >= GameRules.maxLevel { save.xp = 0 }
        if save.level > save.bestLevel { save.bestLevel = save.level }
        if save.level > from {
            recalc()
            levelUp = LevelUpInfo(from: levelUp?.from ?? from, to: save.level)
            SoundFX.play(.levelUp)
            checkStarterOffer()
        }
        markDirty()
    }

    // MARK: Ресурсы

    func amount(_ kind: ResourceKind) -> Int {
        (save.storage[kind] ?? 0) + (save.backpack[kind] ?? 0)
    }

    var backpackCount: Int { save.backpack.values.reduce(0, +) }
    var backpackFree: Int { max(0, stats.capacity - backpackCount) }

    /// Кладёт добычу в рюкзак. Возвращает, сколько поместилось.
    @discardableResult
    func addToBackpack(_ kind: ResourceKind, _ amount: Int) -> Int {
        guard amount > 0 else { return 0 }
        if stats.autoDeposit && backpackFree < amount {
            let moved = depositBackpack()
            if moved > 0 { toast("px:portal", tr("toast.portal", moved)) }
        }
        let n = min(amount, backpackFree)
        guard n > 0 else { return 0 }
        save.backpack[kind, default: 0] += n
        save.gathered[kind, default: 0] += n
        noteExpeditionLoot(kind, n)
        progressQuests(.gather, kind: kind, amount: n)
        markDirty()
        return n
    }

    @discardableResult
    func addToStorage(_ kind: ResourceKind, _ amount: Int, counts: Bool = true) -> Int {
        guard amount > 0 else { return 0 }
        save.storage[kind, default: 0] += amount
        if counts {
            save.gathered[kind, default: 0] += amount
            noteExpeditionLoot(kind, amount)
            progressQuests(.gather, kind: kind, amount: amount)
        }
        markDirty()
        return amount
    }

    @discardableResult
    func depositBackpack() -> Int {
        let total = backpackCount
        guard total > 0 else { return 0 }
        for (kind, n) in save.backpack {
            save.storage[kind, default: 0] += n
        }
        save.backpack = [:]
        progressQuests(.deposit, amount: total)
        if stats.storekeeperXP > 0 {
            gainXP(stats.storekeeperXP * (total / 10))
        }
        markDirty()
        return total
    }

    /// Учитывает добычу: опыт, монеты "Золотого касания", задания. Возвращает монеты.
    func registerHarvest(xp: Int) -> Int {
        save.harvests += 1
        var coins = 0
        if stats.goldenTouch {
            coins = Int((Double(1 + save.level / 5) * stats.goldMult).rounded())
            save.coins += coins
            save.coinsEarned += coins
        }
        progressQuests(.harvest, amount: 1)
        gainXP(xp)
        return coins
    }

    func addCoins(_ n: Int) {
        guard n > 0 else { return }
        save.coins += n
        save.coinsEarned += n
        markDirty()
    }

    func sellPrice(_ kind: ResourceKind) -> Int {
        let bonus = 1 + (stats.sellCategory[kind.category] ?? 0)
        return max(1, Int((Double(kind.price) * stats.sellMult * bonus).rounded()))
    }

    func sell(_ kind: ResourceKind, _ amount: Int) {
        let have = save.storage[kind] ?? 0
        let n = min(amount, have)
        guard n > 0 else { return }
        save.storage[kind] = have - n
        let earned = n * sellPrice(kind)
        save.coins += earned
        save.coinsEarned += earned
        progressQuests(.sell, amount: earned)
        SoundFX.play(.coin)
        markDirty()
    }

    /// Ресурсы, которые сейчас реально добыть: для заданий и находок.
    var gatherableKinds: [ResourceKind] {
        var out: [ResourceKind] = []
        for id in save.unlocked {
            for type in id.spec.nodeTypes where canHarvest(type.spec) {
                for y in type.spec.yields where y.chance >= 0.5 && !out.contains(y.kind) {
                    out.append(y.kind)
                }
            }
        }
        return out
    }

    // MARK: Стоимость

    func discounted(_ cost: Cost) -> Cost {
        stats.discount < 1 ? cost.scaled(stats.discount) : cost
    }

    func canAfford(_ cost: Cost) -> Bool {
        guard save.coins >= cost.coins else { return false }
        return cost.items.allSatisfy { amount($0.kind) >= $0.amount }
    }

    /// Списывает стоимость: сначала со склада, затем из рюкзака.
    private func pay(_ cost: Cost) {
        save.coins -= cost.coins
        for item in cost.items {
            var left = item.amount
            let fromStorage = min(left, save.storage[item.kind] ?? 0)
            save.storage[item.kind] = (save.storage[item.kind] ?? 0) - fromStorage
            left -= fromStorage
            if left > 0 {
                save.backpack[item.kind] = max(0, (save.backpack[item.kind] ?? 0) - left)
            }
        }
        markDirty()
    }

    // MARK: Инструменты

    func tier(_ tool: ToolKind) -> Int {
        tool == .hand ? 1 : (save.tools[tool] ?? 1)
    }

    /// Ступень с учётом таланта "Мастер инструмента".
    func effectiveTier(_ tool: ToolKind) -> Int {
        tool == .hand ? 1 : tier(tool) + stats.toolBonus
    }

    func canHarvest(_ spec: NodeSpec) -> Bool {
        spec.tool == .hand || effectiveTier(spec.tool) >= spec.tier
    }

    func damage(against spec: NodeSpec) -> Double {
        let s = stats
        var base: Double
        switch spec.tool {
        case .hand: base = s.handMult * (1 + 0.04 * Double(save.level - 1))
        case .rod: base = ToolTier.power(effectiveTier(.rod)) * s.handMult
        case .axe: base = ToolTier.power(effectiveTier(.axe)) * (1 + s.woodBonus)
        case .pickaxe: base = ToolTier.power(effectiveTier(.pickaxe)) * (1 + s.stoneBonus)
        case .sword, .armor, .helmet, .boots: base = 1
        }
        if spec.tier >= 5 { base *= 1 + s.highTierBonus }
        return base * s.damageMult
    }

    func nextToolCost(_ tool: ToolKind) -> Cost? {
        let next = tier(tool) + 1
        guard next <= ToolTier.maxTier else { return nil }
        return discounted(ToolTier.cost(tool, tier: next))
    }

    /// Можно улучшить прямо сейчас (для значков на вкладках).
    func canUpgradeNow(_ tool: ToolKind) -> Bool {
        let next = tier(tool) + 1
        guard next <= ToolTier.maxTier, save.level >= ToolTier.requiredLevel(tool, tier: next),
              let cost = nextToolCost(tool) else { return false }
        return canAfford(cost)
    }

    @discardableResult
    func upgradeTool(_ tool: ToolKind) -> Bool {
        let next = tier(tool) + 1
        guard next <= ToolTier.maxTier,
              save.level >= ToolTier.requiredLevel(tool, tier: next),
              let cost = nextToolCost(tool), canAfford(cost) else { return false }
        pay(cost)
        save.tools[tool] = next
        recalc()
        SoundFX.play(.unlock)
        toast("px:" + tool.icon, tr("toast.newTool", ToolTier.name(tool, tier: next)))
        return true
    }

    // MARK: Таланты

    func rank(_ id: TalentID) -> Int { save.talents[id] ?? 0 }

    func talentAvailable(_ id: TalentID) -> Bool {
        let spec = id.spec
        return save.level >= spec.requiredLevel && spec.parents.allSatisfy { rank($0) > 0 }
    }

    func canLearn(_ id: TalentID) -> Bool {
        talentPointsFree > 0 && rank(id) < id.spec.maxRank && talentAvailable(id)
    }

    @discardableResult
    func learn(_ id: TalentID) -> Bool {
        guard canLearn(id) else { return false }
        save.talents[id] = rank(id) + 1
        recalc()
        markDirty()
        return true
    }

    func pointsSpent(in branch: TalentBranch) -> Int {
        branch.talents.reduce(0) { $0 + rank($1) }
    }

    var respecCost: Int { GameRules.respecCost(save.level) }

    @discardableResult
    func resetTalents() -> Bool {
        guard talentPointsSpent > 0, save.coins >= respecCost else { return false }
        save.coins -= respecCost
        save.talents = [:]
        recalc()
        markDirty()
        return true
    }

    // MARK: Животные

    func stars(_ id: AnimalID) -> Int { save.animals[id] ?? 0 }

    func shopPrice(_ id: AnimalID) -> Int? {
        guard case .shop(let price, _) = id.spec.source else { return nil }
        return Int((Double(price) * pow(1.8, Double(stars(id))) * stats.shopMult).rounded())
    }

    func tameCost(_ id: AnimalID) -> Cost? {
        guard case .wild(_, let cost, _) = id.spec.source else { return nil }
        let factor = (1 + 0.5 * Double(stars(id))) * stats.tameMult
        return cost.scaled(factor)
    }

    @discardableResult
    func buyAnimal(_ id: AnimalID) -> Bool {
        guard case .shop(_, let level) = id.spec.source,
              save.level >= level,
              stars(id) < AnimalSpec.maxStars,
              let price = shopPrice(id), save.coins >= price else { return false }
        save.coins -= price
        addStar(id, count: 1)
        SoundFX.play(.purchase)
        return true
    }

    @discardableResult
    func tame(_ id: AnimalID) -> Bool {
        guard stars(id) < AnimalSpec.maxStars, let cost = tameCost(id), canAfford(cost) else { return false }
        pay(cost)
        let bonus = Double.random(in: 0..<1) < stats.doubleStarChance ? 2 : 1
        addStar(id, count: bonus)
        if bonus > 1 { toast("px:stardust", tr("toast.doubleStar")) }
        gainXP(GameRules.tameXP(save.level))
        return true
    }

    private func addStar(_ id: AnimalID, count: Int) {
        if let card = CardID.forAnimal(id), Double.random(in: 0..<1) < 0.35 { gainCard(card) }
        let isNew = stars(id) == 0
        save.animals[id] = min(AnimalSpec.maxStars, stars(id) + count)
        progressQuests(.tame, amount: 1)
        if isNew {
            if save.active.count < GameRules.maxActiveAnimals {
                save.active.append(id)
                toast("an:" + id.rawValue, tr("toast.animalJoined", id.spec.name))
            } else {
                toast("an:" + id.rawValue, tr("toast.animalPen", id.spec.name))
            }
        } else {
            toast("an:" + id.rawValue, "\(id.spec.name): \(String(repeating: "★", count: stars(id)))")
        }
        recalc()
        markDirty()
    }

    func isActive(_ id: AnimalID) -> Bool { save.active.contains(id) }

    @discardableResult
    func toggleActive(_ id: AnimalID) -> Bool {
        if let index = save.active.firstIndex(of: id) {
            save.active.remove(at: index)
        } else {
            guard stars(id) > 0, save.active.count < GameRules.maxActiveAnimals else { return false }
            save.active.append(id)
        }
        recalc()
        markDirty()
        return true
    }

    // MARK: Локации и проходы

    func isUnlocked(_ id: LocationID) -> Bool {
        switch id.spec.kind {
        case .world: return id.planet == .home ? reachable.contains(id) : save.level >= max(id.planet.level, id.spec.level)
        case .garden: return owns(.garden)
        case .expedition: return save.expedition?.id == id
        case .event: return eventsOpen && Events.current.event.location == id
        case .home: return id.floor.map { isBuilt($0) } ?? false
        case .dungeon: return dungeonRun?.dungeon.location == id
        }
    }

    func refreshReachable() {
        reachable = WorldGraph.reachable(open: Set(save.openGates))
        save.unlocked = LocationID.world.filter { reachable.contains($0) }
    }

    /// Старые сохранения: локации открывались без проходов. Открываем проходы по цепочке до каждой.
    private func migrateGates() {
        guard save.openGates.isEmpty, save.unlocked.count > 1 else { return }
        let had = Set(save.unlocked)
        for id in save.unlocked where id != .meadow {
            let path = WorldGraph.path(to: id, within: had) ?? WorldGraph.path(to: id, within: nil) ?? []
            for gate in path where !save.openGates.contains(gate) {
                save.openGates.append(gate)
                if let spec = WorldGraph.gate(gate) {
                    for g in WorldGraph.bundle(spec) where !save.openGates.contains(g.id) { save.openGates.append(g.id) }
                }
            }
        }
    }

    func isGateOpen(_ id: String) -> Bool {
        guard let gate = WorldGraph.gate(id) else { return false }
        if gate.royal { return owns(.garden) }
        return save.openGates.contains(id)
    }

    /// Цена прохода. Короткий путь между двумя уже открытыми локациями стоит вдвое дешевле.
    func gateCost(_ gate: GateSpec) -> Cost {
        let cost = discounted(gate.cost)
        if reachable.contains(gate.a) && reachable.contains(gate.b) { return cost.scaled(0.5) }
        return cost
    }

    func canOpenGate(_ gate: GateSpec) -> Bool {
        !gate.royal && !isGateOpen(gate.id) && save.level >= gate.level && canAfford(gateCost(gate))
    }

    /// Сколько закрытых проходов можно открыть прямо сейчас (для значка на карте).
    var openableGates: Int {
        WorldGraph.gates.filter { gate in
            (reachable.contains(gate.a) || reachable.contains(gate.b)) && canOpenGate(gate)
        }.count
    }

    @discardableResult
    func openGate(_ id: String) -> Bool {
        guard let gate = WorldGraph.gate(id), canOpenGate(gate) else { return false }
        let before = reachable
        pay(gateCost(gate))
        for g in WorldGraph.bundle(gate) where !save.openGates.contains(g.id) {
            save.openGates.append(g.id)
        }
        refreshReachable()
        let fresh = LocationID.world.filter { reachable.contains($0) && !before.contains($0) }
        for loc in fresh {
            toast("px:map", tr("toast.locationOpened", loc.spec.name))
            gainXP(GameRules.unlockXP(loc))
        }
        if fresh.isEmpty { toast("px:door", tr("toast.gateOpened")) }
        gatePrompt = nil
        SoundFX.play(.gateOpen)
        saveNow()
        return true
    }

    func setGatePrompt(_ id: String?) {
        if gatePrompt != id { gatePrompt = id }
    }

    /// Персонаж прошёл через открытые ворота на краю карты.
    func walk(through gateID: String) {
        guard let gate = WorldGraph.gate(gateID), isGateOpen(gateID), gate.connects(save.current) else { return }
        let target = gate.other(save.current)
        guard isUnlocked(target) else { return }
        arrivalGate = gateID
        save.current = target
        encounter = nil
        gatePrompt = nil
        markDirty()
    }

    /// Быстрый переход по карте: появляемся у склада.
    func travel(to id: LocationID) {
        guard isUnlocked(id), save.current != id, save.expedition == nil else { return }
        let wasEvent = save.current.spec.kind == .event
        arrivalGate = nil
        save.current = id
        encounter = nil
        gatePrompt = nil
        // Усиления ивента действуют только на его картах
        if wasEvent || id.spec.kind == .event { recalc() }
        markDirty()
    }

    // MARK: Экспедиции

    var freeTicketReady: Bool {
        save.tickets < Expedition.maxTickets
            && (save.lastFreeTicket ?? .distantPast).addingTimeInterval(freeTicketInterval) <= Date()
    }

    var nextFreeTicket: Date? {
        guard let last = save.lastFreeTicket else { return nil }
        let next = last.addingTimeInterval(freeTicketInterval)
        return next > Date() ? next : nil
    }

    func claimFreeTicket() {
        guard freeTicketReady else { return }
        let n = hasPro ? 2 : 1
        save.tickets = min(Expedition.maxTickets, save.tickets + n)
        save.lastFreeTicket = Date()
        toast("px:ticket", tr("toast.ticket", n))
        SoundFX.play(.coin)
        saveNow()
    }

    /// Уйти в экспедицию по билету. Возвращаемся туда, откуда ушли.
    @discardableResult
    func startExpedition(_ id: LocationID) -> Bool {
        let price = Expedition.cost(id)
        let maps = Expedition.maps(id)
        guard id.spec.kind == .expedition, save.expedition == nil, save.tickets >= price, save.maps >= maps else { return false }
        save.tickets -= price
        save.maps -= maps
        save.expedition = ExpeditionRun(location: id.rawValue, endsAt: Date().addingTimeInterval(Expedition.duration(id)),
                                        returnTo: save.current.rawValue)
        if backpackCount > 0 { depositBackpack() }
        arrivalGate = nil
        save.current = id
        encounter = nil
        gatePrompt = nil
        saveNow()
        return true
    }

    var inExpedition: Bool { save.current.spec.kind == .expedition && save.expedition != nil }

    private func noteExpeditionLoot(_ kind: ResourceKind, _ n: Int) {
        guard var run = save.expedition, run.id == save.current else { return }
        run.loot[kind.rawValue, default: 0] += n
        save.expedition = run
    }

    func noteExpeditionCoins(_ n: Int) {
        guard var run = save.expedition, run.id == save.current, n > 0 else { return }
        run.coins += n
        save.expedition = run
    }

    /// Время вышло (или игрок ушёл сам): показываем итог и возвращаемся.
    func finishExpedition() {
        guard let run = save.expedition else { return }
        randomCard()
        if backpackCount > 0 { depositBackpack() }
        if let id = run.id {
            expeditionReport = ExpeditionReport(location: id, items: run.items, coins: run.coins)
        }
        save.expedition = nil
        arrivalGate = nil
        let home = run.home
        save.current = isUnlocked(home) ? home : .meadow
        encounter = nil
        gatePrompt = nil
        SoundFX.play(.success)
        saveNow()
    }

    // MARK: Королевский сад

    var gardenChestReady: Bool {
        owns(.garden) && (save.gardenChestAt ?? .distantPast) <= Date()
    }

    /// Королевский сундук раз в сутки: много монет, ресурсы и билет.
    func openGardenChest() {
        guard gardenChestReady else { return }
        let level = save.level
        let coins = Int(Double(300 + level * 120) * Double.random(in: 0.9...1.2))
        var items: [ResourceAmount] = []
        for kind in gatherableKinds.shuffled().prefix(3) {
            let n = max(2, Int(Double(60 + level * 8) / pow(Double(kind.price), 0.6)))
            items.append(ResourceAmount(kind: kind, amount: n))
        }
        save.coins += coins
        save.coinsEarned += coins
        for item in items { addToStorage(item.kind, item.amount) }
        save.tickets = min(Expedition.maxTickets, save.tickets + 1)
        save.gardenChestAt = Date().addingTimeInterval(RoyalGarden.chestEvery)
        gardenChestFound = Treasure(coins: coins, items: items)
        SoundFX.play(.treasure)
        saveNow()
    }

    // MARK: Клады

    /// Награда за клад зависит от уровня и открытых локаций.
    func openTreasure() -> Treasure {
        if Double.random(in: 0..<1) < 0.35 { randomCard() }
        let level = save.level
        let proBonus = hasPro ? 2.0 : 1.0
        let coins = Int(Double(40 + level * 25) * Double.random(in: 0.8...1.4) * proBonus)
        var items: [ResourceAmount] = []
        let pool = gatherableKinds
        for kind in pool.shuffled().prefix(2) {
            let n = max(1, Int(Double(20 + level * 3) / pow(Double(kind.price), 0.6) * Double.random(in: 0.7...1.3) * proBonus))
            items.append(ResourceAmount(kind: kind, amount: n))
        }
        save.coins += coins
        save.coinsEarned += coins
        for item in items { addToStorage(item.kind, item.amount) }
        save.treasures += 1
        if Double.random(in: 0..<1) < TreasureMaps.treasureChance {
            save.maps += 1
            toast("px:tmap", tr("toast.map"))
        }
        progressQuests(.treasure, amount: 1)
        gainXP(max(5, xpToNext / 25))
        let treasure = Treasure(coins: coins, items: items)
        treasureFound = treasure
        markDirty()
        return treasure
    }

    // MARK: Задания

    func ensureQuests() {
        save.quests.removeAll { $0.kind == nil && $0.type == .gather }
        while save.quests.count < questSlots {
            let quest = Quest.make(level: save.level, available: gatherableKinds,
                                   producers: stats.producers.map(\.kind), avoid: save.quests)
            save.quests.append(quest)
        }
    }

    private func progressQuests(_ type: QuestType, kind: ResourceKind? = nil, amount: Int) {
        guard amount > 0 else { return }
        for i in save.quests.indices where save.quests[i].type == type && !save.quests[i].done {
            if type == .gather && save.quests[i].kind != kind { continue }
            save.quests[i].progress = min(save.quests[i].target, save.quests[i].progress + amount)
            if save.quests[i].done {
                toast("px:quest", tr("toast.questDone"))
            }
        }
    }

    var claimableQuests: Int { save.quests.filter(\.done).count }

    func claimQuest(_ id: UUID) {
        guard let index = save.quests.firstIndex(where: { $0.id == id }), save.quests[index].done else { return }
        let quest = save.quests.remove(at: index)
        save.coins += quest.coins
        save.coinsEarned += quest.coins
        save.questsDone += 1
        SoundFX.play(.success)
        let fresh = Quest.make(level: save.level, available: gatherableKinds,
                               producers: stats.producers.map(\.kind), avoid: save.quests)
        save.quests.insert(fresh, at: min(index, save.quests.count))
        gainXP(quest.xp)
        markDirty()
    }

    var questSlots: Int { hasPro ? 4 : 3 }

    var rerollCost: Int { 15 * save.level }

    func rerollQuest(_ id: UUID, free: Bool = false) {
        guard let index = save.quests.firstIndex(where: { $0.id == id }), free || save.coins >= rerollCost else { return }
        if free {
            save.adsWatched += 1
        } else {
            save.coins -= rerollCost
        }
        var others = save.quests
        others.remove(at: index)
        save.quests[index] = Quest.make(level: save.level, available: gatherableKinds,
                                        producers: stats.producers.map(\.kind), avoid: others + [save.quests[index]])
        markDirty()
    }

    // MARK: Достижения

    func progress(_ achievement: Achievement) -> Int {
        switch achievement.metric {
        case .gathered(let kind): return save.gathered[kind] ?? 0
        case .category(let category):
            return save.gathered.filter { $0.key.category == category }.values.reduce(0, +)
        case .harvests: return save.harvests
        case .coinsEarned: return save.coinsEarned
        case .animals: return save.animals.keys.filter { !$0.spec.isPremium }.count
        case .stars: return save.animals.values.reduce(0, +)
        case .locations: return save.unlocked.count
        case .level: return save.level
        case .minTool: return ToolKind.gathering.map { tier($0) }.min() ?? 1
        case .talents: return talentPointsSpent
        case .quests: return save.questsDone
        case .treasures: return save.treasures
        case .floors: return save.houseFloors.count
        case .kills: return save.kills
        }
    }

    func isClaimed(_ achievement: Achievement) -> Bool { save.claimed.contains(achievement.id) }

    func canClaim(_ achievement: Achievement) -> Bool {
        !isClaimed(achievement) && progress(achievement) >= achievement.target
    }

    var claimableAchievements: Int { Achievement.all.filter { canClaim($0) }.count }

    func claim(_ achievement: Achievement) {
        guard canClaim(achievement) else { return }
        save.claimed.append(achievement.id)
        SoundFX.play(.success)
        save.coins += achievement.coins
        save.coinsEarned += achievement.coins
        save.bonusTalentPoints += achievement.talentPoints
        if achievement.talentPoints > 0 {
            toast("px:star", tr("toast.achievementPoints", achievement.talentPoints))
        }
        markDirty()
    }

    // MARK: Покупки

    func owns(_ product: ProductID) -> Bool { save.purchases.contains(product.rawValue) }

    var hasPro: Bool { owns(.pro) }

    /// Выдаёт покупку. Разовые награды (монеты, зверь) выдаются один раз даже при повторном восстановлении.
    func grant(_ product: ProductID, transaction: String? = nil) {
        if product.consumable {
            // Билеты можно покупать много раз: каждую покупку выдаём ровно один раз.
            if let transaction {
                guard !save.consumed.contains(transaction) else { return }
                save.consumed.append(transaction)
            }
            if product == .eventPass {
                activateVip()
            } else {
                save.tickets += Expedition.ticketPack
            }
            toast("px:chest_gold", tr("toast.purchased", product.title))
            saveNow()
            return
        }
        if !owns(product) { save.purchases.append(product.rawValue) }
        if !save.granted.contains(product.rawValue) {
            save.granted.append(product.rawValue)
            switch product {
            case .starter:
                save.coins += Premium.starterCoins
                if stars(.duckHat) == 0 { addStar(.duckHat, count: 1) }
                save.skin = Skin.robot.rawValue
                save.starterOfferUntil = nil
            case .pro:
                save.skin = Skin.genie.rawValue
            case .skins:
                break
            case .garden:
                save.skin = Skin.knight.rawValue
                save.gardenChestAt = nil
                save.weapons[.royalSword] = max(save.weapons[.royalSword] ?? 0, WeaponID.royalSword.startTier)
            case .tickets, .eventPass:
                break
            }
            toast("px:chest_gold", tr("toast.purchased", product.title))
            SoundFX.play(.purchase)
        }
        offerPopup = false
        recalc()
        ensureQuests()
        saveNow()
    }

    /// Покупку вернули: убираем её, образ сбрасываем, если он был из неё.
    func revoke(_ product: ProductID) {
        guard !product.consumable, owns(product) else { return }
        save.purchases.removeAll { $0 == product.rawValue }
        if !isSkinUnlocked(currentSkin) { save.skin = Skin.farmer.rawValue }
        recalc()
        save.quests = Array(save.quests.prefix(questSlots))
        saveNow()
    }

    #if SIDELOAD
    func resetTestPurchases() {
        save.purchases = []
        if !isSkinUnlocked(currentSkin) { save.skin = Skin.farmer.rawValue }
        recalc()
        save.quests = Array(save.quests.prefix(questSlots))
        saveNow()
    }
    #endif

    var starterAvailable: Bool {
        !owns(.starter) && (save.starterOfferUntil ?? .distantPast) > Date()
    }

    /// Открывает окно стартового набора на 48 часов: на 5 уровне и ещё раз на 15.
    func checkStarterOffer() {
        guard !owns(.starter), !starterAvailable else { return }
        let due = (save.starterOffers == 0 && save.level >= Premium.starterLevel)
            || (save.starterOffers == 1 && save.level >= Premium.starterSecondLevel)
        guard due else { return }
        save.starterOffers += 1
        save.starterOfferUntil = Date().addingTimeInterval(Premium.starterWindow)
        offerPopup = true
        markDirty()
    }

    // MARK: Образы

    var currentSkin: Skin { Skin(rawValue: save.skin) ?? .farmer }

    func isSkinUnlocked(_ skin: Skin) -> Bool {
        switch skin.unlock {
        case .free: return true
        case .level(let level): return max(save.level, save.bestLevel) >= level
        case .product(let product): return owns(product)
        case .constellation(let c): return isComplete(c)
        case .event: return save.eventSkins.contains(skin.rawValue)
        }
    }

    func selectSkin(_ skin: Skin) {
        guard isSkinUnlocked(skin) else { return }
        save.skin = skin.rawValue
        markDirty()
    }

    // MARK: Награды за рекламу

    var luckActive: Bool { (save.luckUntil ?? .distantPast) > Date() }

    /// Если часы на телефоне перевели назад, таймеры могли улететь далеко в будущее. Сбрасываем такие.
    func repairTimers() {
        let now = Date()
        if let ready = save.luckReadyAt, ready.timeIntervalSince(now) > Premium.luckDuration + Premium.luckCooldown + 60 {
            save.luckUntil = nil
            save.luckReadyAt = nil
            markDirty()
        }
        if let until = save.starterOfferUntil, until.timeIntervalSince(now) > Premium.starterWindow + 60 {
            save.starterOfferUntil = now.addingTimeInterval(Premium.starterWindow)
            markDirty()
        }
    }

    var luckReady: Bool { !luckActive && (save.luckReadyAt ?? .distantPast) <= Date() }

    func activateLuck(fromAd: Bool) {
        guard luckReady else { return }
        let until = Date().addingTimeInterval(Premium.luckDuration)
        save.luckUntil = until
        save.luckReadyAt = until.addingTimeInterval(Premium.luckCooldown)
        if fromAd { save.adsWatched += 1 }
        toast("px:clover", tr("toast.luck"))
        SoundFX.play(.luck)
        markDirty()
    }

    /// Удваивает добычу зверей за время отсутствия.
    func doubleOffline(fromAd: Bool) {
        guard let report = offlineReport, !report.doubled else { return }
        for item in report.items { addToStorage(item.kind, item.amount) }
        if fromAd { save.adsWatched += 1 }
        offlineReport = OfflineReport(duration: report.duration, items: report.items, doubled: true)
        saveNow()
    }

    // MARK: Для сцены

    func setEncounter(_ value: Encounter?) {
        if encounter != value { encounter = value }
    }

    func setBackpackFull(_ value: Bool) {
        if backpackFull != value { backpackFull = value }
    }

    func showBanner(_ id: LocationID) {
        bannerToken += 1
        let token = bannerToken
        banner = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { [weak self] in
            guard let self, self.bannerToken == token else { return }
            self.banner = nil
        }
    }

    func toast(_ icon: String, _ text: String) {
        if toasts.contains(where: { $0.text == text }) { return }
        let item = Toast(icon: icon, text: text)
        toasts.append(item)
        if toasts.count > 3 { toasts.removeFirst(toasts.count - 3) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) { [weak self] in
            self?.toasts.removeAll { $0.id == item.id }
        }
    }

    // MARK: Пока игры не было

    func applyOfflineProgress() {
        if canClaimLogin && save.tutorialDone { loginPopup = true }
        syncEvent()
        repairTimers()
        let elapsed = min(Date().timeIntervalSince(save.lastSeen), stats.offlineHours * 3600)
        save.lastSeen = Date()
        guard elapsed > 90 else { return }
        var totals: [ResourceKind: Int] = [:]
        for producer in stats.producers {
            let n = Int(elapsed * stats.producerMult / producer.interval * (1 + stats.doubleProductChance))
            if n > 0 { totals[producer.kind, default: 0] += n }
        }
        guard !totals.isEmpty else { return }
        var items: [ResourceAmount] = []
        for kind in ResourceKind.allCases {
            if let n = totals[kind] {
                addToStorage(kind, n)
                items.append(ResourceAmount(kind: kind, amount: n))
            }
        }
        offlineReport = OfflineReport(duration: elapsed, items: items)
        saveNow()
    }

    // MARK: Характеристики

    func recalc() {
        var s = Stats()
        func r(_ id: TalentID) -> Double { Double(save.talents[id] ?? 0) }
        let lvl = Double(save.level)

        s.damageMult = (1 + 0.02 * (lvl - 1)) * (1 + 0.12 * r(.power))
        s.woodBonus = 0.2 * r(.lumberjack)
        s.stoneBonus = 0.2 * r(.miner)
        s.highTierBonus = 0.15 * r(.crusher)
        s.handMult = 1 + 0.4 * r(.strongHands)
        s.hitInterval = 0.55 / ((1 + 0.07 * r(.quickHands)) * (1 + 0.05 * r(.tireless)))
        s.critMult = 2 + 0.3 * r(.critPower)
        s.shatterChance = 0.04 * r(.shatter)
        s.doubleStrikeChance = 0.05 * r(.doubleStrike)
        s.executeThreshold = 0.06 * r(.execute)
        s.quake = r(.quake) > 0
        s.quakePower = 0.4 * (1 + 0.25 * r(.shockwave))
        s.quakeRadius = 110 * (1 + 0.25 * r(.shockwave))
        s.toolBonus = r(.toolMaster) > 0 ? 1 : 0

        s.yieldAll = 0.1 * r(.bounty) + 0.06 * r(.fertile) + (r(.abundance) > 0 ? 0.1 : 0)
            + (owns(.garden) ? RoyalGarden.capybaraYield : 0)
        s.yieldCategory[.food] = 0.2 * r(.farmer)
        s.yieldCategory[.crop] = 0.2 * r(.farmer)
        s.yieldCategory[.ore] = 0.1 * r(.oreHunter)
        s.yieldCategory[.gem] = 0.1 * r(.oreHunter)
        s.regrowChance = 0.06 * r(.gardener)
        s.doubleChance = 0.05 * r(.doubleDrop)
        s.tripleChance = 0.03 * r(.triple)
        s.finderChance = 0.04 * r(.finder)
        s.gemChance = 0.015 * r(.gemFinder)
        s.goldenTouch = r(.goldenTouch) > 0
        s.goldMult = 1 + 0.5 * r(.goldRush)
        let jeweler = 0.15 * r(.jeweler)
        s.sellCategory[.ore] = jeweler
        s.sellCategory[.gem] = jeweler
        s.sellCategory[.treasure] = jeweler

        s.reach = GameRules.baseReach * (1 + 0.12 * r(.reach))
        s.depositRadius = 92 * (1 + 0.3 * r(.depotReach))
        s.tameMult = (1 - 0.15 * r(.tamer)) * (1 - 0.1 * r(.catcher))
        s.shopMult = 1 - 0.08 * r(.bargain)
        s.spawnMult = (1 + 0.25 * r(.tamer)) * (1 + 0.2 * r(.tracker))
        s.storekeeperXP = Int(r(.storekeeper))
        s.discount = 1 - 0.07 * r(.thrift)
        s.autoDeposit = r(.portal) > 0 || hasPro

        s.animalMult = (1 + 0.12 * r(.beastBond) + 0.05 * r(.animalFriend)) * (r(.soul) > 0 ? 1.3 : 1)
        s.helperMult = (1 + 0.25 * r(.packLeader)) * (1 + 0.1 * r(.alpha))
        s.helperSpeed = 1 + 0.08 * r(.training)
        s.helperRange = 260 * (1 + 0.2 * r(.keenEye))
        s.helperTierBonus = Int(r(.packTier))
        s.helperYield = 1 + 0.15 * r(.beastLoot)
        s.producerMult = (1 + 0.2 * r(.nightShift)) * (1 + 0.1 * r(.herdsman))
        s.doubleProductChance = 0.08 * r(.rancher)
        s.offlineHours = (hasPro ? Premium.proOfflineHours : 6) + 2 * r(.pasture)
        s.starStep = 0.25 + 0.05 * r(.starFood)
        s.doubleStarChance = 0.15 * r(.starHunter)

        // Огород
        s.growMult = 1 / (1 + 0.06 * r(.greenThumb))
        s.extraCropChance = 0.12 * r(.bigHarvest)
        s.seedBackChance = 0.08 * r(.seedSaver)
        s.waterMult = 1 + 0.15 * r(.rainmaker)
        s.fertSaveChance = 0.12 * r(.composter)
        s.fertExtra = Int(r(.deepRoots))
        s.mealMult = 1 + 0.15 * r(.chef)
        s.cookMult = 1 - 0.1 * r(.quickCook)
        s.sellCategory[.crop, default: 0] += 0.1 * r(.marketDay)
        s.seedMult = 1 - 0.1 * r(.seedTrader)
        s.goldenHarvest = r(.goldenHarvest) > 0
        s.harvestXPMult = r(.harvestMoon) > 0 ? 2 : 1

        // Бой
        let warlord = r(.warlord) > 0 ? 0.15 : 0
        s.hpMult = (1 + 0.08 * r(.toughness)) * (1 + warlord)
        s.weaponMult = (1 + 0.07 * r(.bladeMaster)) * (1 + warlord)
        s.defenseBonus = 0.03 * r(.stance)
        s.dodgeBonus = 0.02 * r(.evasion)
        s.lifesteal = 0.02 * r(.vampirism)
        s.potionBonus = 0.1 * r(.alchemist)
        s.berserk = 0.12 * r(.berserk)
        s.bossBonus = 0.08 * r(.bossSlayer)
        s.lastStand = r(.lastStand) > 0
        s.dungeonBonus = 0.1 * r(.delver)
        s.regen = 0.005 * r(.regen)

        // Наследие: вечные бонусы за перерождения.
        func legacy(_ perk: LegacyPerk) -> Double { Double(legacyRank(perk)) * perk.perRank }
        s.yieldAll += legacy(.harvest)
        s.weaponMult *= 1 + legacy(.fighter)
        s.hpMult *= 1 + legacy(.vigor)
        s.growMult /= 1 + legacy(.gardener)
        s.mealMult *= 1 + legacy(.chef)
        // Уют дома и блюдо, которое сейчас действует.
        let cozy = Comfort.bonus(comfort)
        s.yieldAll += cozy
        var meal = MealBuff()
        for dish in activeMeals.map(\.dish) {
            let b = dish.buff
            meal.yield += b.yield
            meal.xp += b.xp
            meal.speed += b.speed
            meal.sell += b.sell
            meal.crit += b.crit
            meal.animals += b.animals
        }
        s.yieldAll += meal.yield
        // Созвездия
        let cHarvest = constellationBonus(.harvest)
        let cForest = constellationBonus(.forest)
        let cDepths = constellationBonus(.depths)
        let cSea = constellationBonus(.sea)
        s.yieldCategory[.crop, default: 0] += cHarvest
        s.yieldCategory[.wood, default: 0] += cForest
        s.yieldCategory[.food, default: 0] += cForest
        s.yieldCategory[.stone, default: 0] += cDepths
        s.yieldCategory[.ore, default: 0] += cDepths
        s.yieldCategory[.gem, default: 0] += cDepths
        s.yieldKind[.fish, default: 0] += cSea
        s.yieldCategory[.treasure, default: 0] += cSea
        s.swordMult = 1 + constellationBonus(.monsters)
        s.animalMult *= 1 + constellationBonus(.beasts)
        s.growMult /= 1 + constellationBonus(.garden)
        s.weaponMult *= 1 + constellationBonus(.dungeon)
        s.producerMult *= 1 + constellationBonus(.birds)
        if isBuilt(.upper) { s.offlineHours += 2 }

        var speedBonus = 0.07 * r(.swift) + 0.05 * r(.tailwind) + legacy(.boots)
        var critBonus = 0.05 * r(.crit) + legacy(.luck)
        var respawnBonus = 0.08 * r(.regrowth) + (r(.abundance) > 0 ? 0.5 : 0) + legacy(.growth)
        var xpBonus = 0.1 * r(.scholar) + 0.06 * r(.sage) + legacy(.wisdom) + cozy + meal.xp + constellationBonus(.sky)
        var sellBonus = 0.08 * r(.trader) + legacy(.merchant) + meal.sell
        speedBonus += meal.speed
        critBonus += meal.crit
        s.animalMult *= 1 + meal.animals
        var capacity = Double(GameRules.capacity(at: save.level)) + 15 * r(.bigPack)
            + (owns(.starter) ? Double(Premium.starterBackpack) : 0) + legacy(.pack)

        for id in save.active {
            let m = s.starMultiplier(save.animals[id] ?? 1) * s.animalMult * animalBoost(id)
            for effect in id.spec.effects {
                switch effect {
                case .xp(let v): xpBonus += v * m
                case .yield(let category, let v):
                    if let category {
                        s.yieldCategory[category, default: 0] += v * m
                    } else {
                        s.yieldAll += v * m
                    }
                case .yieldKind(let kind, let v): s.yieldKind[kind, default: 0] += v * m
                case .speed(let v): speedBonus += v * m
                case .respawn(let v): respawnBonus += v * m
                case .crit(let v): critBonus += v * m
                case .backpack(let v): capacity += Double(v) * m
                case .sell(let v): sellBonus += v * m
                case .produce(let kind, let interval):
                    s.producers.append(Producer(animal: id, kind: kind, interval: interval / m))
                case .helper(let h):
                    s.helpers.append(Helper(animal: id, spec: h, damage: h.damage * m))
                }
            }
        }

        // Снаряжение: бонусы ступеней и особое оружие
        let critBefore = s.critChance
        let g = GearPerks.collect(tiers: { self.tier($0) }, into: &s)
        critBonus += s.critChance - critBefore
        speedBonus += g.speed + Hero.speed(boots: tier(.boots))
        if save.weapon == .boneSaber {
            critBonus += 0.1
            s.critMult += 0.2
        }
        gear = g

        // Усиления этапов ивента (только на его картах)
        if save.current.spec.kind == .event {
            func boon(_ b: EventBoon) -> Double { b.perRank * Double(save.eventBoons[b] ?? 0) }
            s.damageMult *= 1 + boon(.damage)
            s.hpMult *= 1 + boon(.vitality)
            speedBonus += boon(.swift)
            critBonus += boon(.lucky)
            s.regen += boon(.regen)
            respawnBonus += boon(.regrowth)
        }

        let strider = r(.strider) > 0 ? 1.25 : 1
        capacity *= (1 + 0.1 * r(.packMaster)) * strider
        s.speed = GameRules.baseSpeed * (1 + speedBonus) * strider
        s.critChance = min(0.75, critBonus)
        s.respawnMult = 1 / (1 + respawnBonus)
        s.xpMult = 1 + xpBonus
        s.sellMult = (1 + 0.01 * (lvl - 1)) * (1 + sellBonus)
        s.capacity = Int(capacity)
        stats = s
    }
}

enum TraderKind: Equatable {
    case stall, wanderer
}

// MARK: Огород

extension GameState {
    var bedCount: Int { Garden.beds(at: save.level) }

    func bed(_ index: Int) -> Bed {
        index < save.beds.count ? save.beds[index] : Bed()
    }

    private func setBed(_ index: Int, _ bed: Bed) {
        while save.beds.count <= index { save.beds.append(Bed()) }
        save.beds[index] = bed
        markDirty()
    }

    func seeds(_ crop: CropID) -> Int { save.seeds[crop] ?? 0 }

    var totalSeeds: Int { save.seeds.values.reduce(0, +) }

    func setNearGarden(_ value: Bool) {
        if nearGarden != value { nearGarden = value }
    }

    func selectSeed(_ crop: CropID) {
        guard save.selectedSeed != crop else { return }
        save.selectedSeed = crop
        markDirty()
    }

    func seedCost(_ crop: CropID, count: Int) -> Int {
        max(1, Int((Double(crop.spec.seedPrice * count) * stats.shopMult * stats.seedMult).rounded(.up)))
    }

    @discardableResult
    func buySeeds(_ crop: CropID, count: Int) -> Bool {
        let cost = seedCost(crop, count: count)
        guard save.level >= crop.spec.level, save.coins >= cost else { return false }
        save.coins -= cost
        save.seeds[crop, default: 0] += count
        if save.selectedSeed == nil || seeds(save.selectedSeed!) == 0 { save.selectedSeed = crop }
        SoundFX.play(.purchase)
        markDirty()
        return true
    }

    /// Выбранные семена, если они ещё есть.
    var chosenSeed: CropID? {
        guard let chosen = save.selectedSeed, seeds(chosen) > 0 else { return nil }
        return chosen
    }

    /// Посадить выбранные семена на пустую грядку.
    @discardableResult
    func plant(_ index: Int, crop: CropID? = nil) -> Bool {
        guard let crop = crop ?? chosenSeed, seeds(crop) > 0, index < bedCount, bed(index).isEmpty else { return false }
        save.seeds[crop] = seeds(crop) - 1
        let speed = (isBuilt(.greenhouse) ? Garden.greenhouseSpeed : 1) * stats.growMult
        setBed(index, Bed(crop: crop, plantedAt: Date(), speed: speed))
        gardenEvents.append(GardenEvent(bed: index, kind: .planted))
        SoundFX.play(.pick)
        return true
    }

    /// Засадить все пустые грядки выбранными семенами. Возвращает, сколько посажено.
    @discardableResult
    func plantAll() -> Int {
        guard let crop = chosenSeed else { return 0 }
        var n = 0
        for i in 0..<bedCount where bed(i).isEmpty && seeds(crop) > 0 {
            if plant(i, crop: crop) { n += 1 }
        }
        return n
    }

    /// Собрать одну грядку с кнопки.
    @discardableResult
    func harvestOne(_ index: Int) -> Bool {
        guard let got = harvestBed(index) else { return false }
        gardenEvents.append(GardenEvent(bed: index, kind: .harvested(got)))
        SoundFX.play(.pickup)
        return true
    }

    /// Собрать все спелые грядки.
    @discardableResult
    func harvestAll() -> Int {
        var n = 0
        for i in 0..<bedCount where bed(i).isRipe(at: Date()) {
            if let got = harvestBed(i) {
                gardenEvents.append(GardenEvent(bed: i, kind: .harvested(got)))
                n += 1
            }
        }
        if n > 0 { SoundFX.play(.pickup) }
        return n
    }

    /// Полить растущую грядку: оставшееся время роста сокращается. Хорошая лейка поливает всё сразу.
    func water(_ index: Int) -> Bool {
        guard waterOne(index) else { return false }
        if WateringCan.waterAll(save.canLevel) {
            for i in 0..<bedCount where i != index && waterOne(i) {
                gardenEvents.append(GardenEvent(bed: i, kind: .boosted))
            }
        }
        return true
    }

    private func waterOne(_ index: Int) -> Bool {
        var b = bed(index)
        let now = Date()
        guard !b.isEmpty, !b.watered, !b.isRipe(at: now), let ready = b.readyAt else { return false }
        b.boost += max(0, ready.timeIntervalSince(now)) * min(0.9, WateringCan.boost(save.canLevel) * stats.waterMult)
        b.watered = true
        setBed(index, b)
        return true
    }

    // MARK: Удобрения и лейка

    func fertilizers(_ id: FertilizerID) -> Int { save.fertilizers[id] ?? 0 }

    var chosenFertilizer: FertilizerID? {
        guard let id = save.selectedFertilizer, fertilizers(id) > 0 else { return nil }
        return id
    }

    func selectFertilizer(_ id: FertilizerID?) {
        guard save.selectedFertilizer != id else { return }
        save.selectedFertilizer = id
        markDirty()
    }

    func canCraft(_ id: FertilizerID, count: Int = 1) -> Bool {
        save.level >= id.level && canAfford(id.recipe.scaled(Double(count)))
    }

    @discardableResult
    func craft(_ id: FertilizerID, count: Int = 1) -> Bool {
        guard canCraft(id, count: count) else { return false }
        pay(id.recipe.scaled(Double(count)))
        save.fertilizers[id, default: 0] += count
        if chosenFertilizer == nil { save.selectedFertilizer = id }
        SoundFX.play(.pick)
        markDirty()
        return true
    }

    /// Удобрить растущую грядку выбранным удобрением.
    @discardableResult
    func fertilize(_ index: Int, with id: FertilizerID? = nil) -> Bool {
        guard let id = id ?? chosenFertilizer, fertilizers(id) > 0 else { return false }
        var b = bed(index)
        let now = Date()
        guard !b.isEmpty, b.fertilized != true, !b.isRipe(at: now), let ready = b.readyAt else { return false }
        b.boost += max(0, ready.timeIntervalSince(now)) * id.cut + (id.cut >= 1 ? 1 : 0)
        b.fertilized = true
        b.extra = (b.extra ?? 0) + id.extra + stats.fertExtra
        if Double.random(in: 0..<1) >= stats.fertSaveChance {
            save.fertilizers[id] = fertilizers(id) - 1
        }
        setBed(index, b)
        gardenEvents.append(GardenEvent(bed: index, kind: .boosted))
        SoundFX.play(.success)
        return true
    }

    /// Удобрить все растущие грядки, пока хватает удобрения.
    @discardableResult
    func fertilizeAll() -> Int {
        guard let id = chosenFertilizer else { return 0 }
        var n = 0
        for i in 0..<bedCount where fertilizers(id) > 0 {
            if fertilize(i, with: id) { n += 1 }
        }
        return n
    }

    /// Сколько грядок можно удобрить прямо сейчас.
    var fertilizableBeds: Int {
        let now = Date()
        return (0..<bedCount).filter { let b = bed($0); return !b.isEmpty && b.fertilized != true && !b.isRipe(at: now) }.count
    }

    var nextCanCost: Cost? {
        let next = save.canLevel + 1
        return next <= WateringCan.maxLevel ? WateringCan.cost(next) : nil
    }

    func canUpgradeCan() -> Bool {
        guard let cost = nextCanCost else { return false }
        return save.level >= WateringCan.requiredLevel(save.canLevel + 1) && canAfford(cost)
    }

    func upgradeCan() {
        guard canUpgradeCan(), let cost = nextCanCost else { return }
        pay(cost)
        save.canLevel += 1
        SoundFX.play(.levelUp)
        toast("px:watering_can", tr("toast.can", save.canLevel))
        saveNow()
    }

    /// Собрать спелый урожай: сразу на склад (огород у дома), плюс опыт.
    func harvestBed(_ index: Int) -> ResourceAmount? {
        let b = bed(index)
        guard let crop = b.crop, b.isRipe(at: Date()) else { return nil }
        let spec = crop.spec
        var amount = max(1, Int((Double(spec.yield) * stats.yieldMultiplier(for: spec.produce)).rounded())) + (b.extra ?? 0)
        if Double.random(in: 0..<1) < stats.extraCropChance { amount += 1 }
        addToStorage(spec.produce, amount)
        if Double.random(in: 0..<1) < stats.seedBackChance { save.seeds[crop, default: 0] += 1 }
        if stats.goldenHarvest && Double.random(in: 0..<1) < 0.1 { addToStorage(.goldenApple, 1) }
        rollCard(for: spec.produce, chance: 0.05)
        setBed(index, Bed())
        save.cropsHarvested += 1
        gainXP(Int(Double(spec.xp) * stats.harvestXPMult))
        return ResourceAmount(kind: spec.produce, amount: amount)
    }

    var ripeBeds: Int {
        let now = Date()
        return (0..<bedCount).filter { bed($0).isRipe(at: now) }.count
    }

    var emptyBeds: Int {
        (0..<bedCount).filter { bed($0).isEmpty }.count
    }
}

// MARK: Лавка и бродячий торговец

extension GameState {
    private var today: Int {
        Int(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970 / 86_400)
    }

    var nextDealsAt: Date {
        let start = Calendar.current.startOfDay(for: Date())
        return Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
    }

    func setTraderPrompt(_ value: TraderKind?) {
        if traderPrompt != value { traderPrompt = value }
    }

    /// Три обмена дня. Одинаковые весь день, меняются в полночь.
    var dailyDeals: [TradeDeal] {
        var rng = DayRandom(seed: today * 7919 + save.rebirths * 31 + save.level / 10)
        var pool = gatherableKinds.sorted { $0.rawValue < $1.rawValue }
        if pool.isEmpty { pool = [.wood, .stone] }
        let level = save.level
        var deals: [TradeDeal] = []

        // Ресурсы за монеты вдвое дороже обычной продажи
        let a = rng.pick(pool)
        let n = max(5, (40 + 15 * level) / max(1, a.price))
        deals.append(TradeDeal(id: 0, give: [ResourceAmount(kind: a, amount: n)], coinsPrice: 0,
                               reward: .coins(n * sellPrice(a) * 2)))

        // Ресурсы за билет в экспедицию
        let b = rng.pick(pool)
        let m = max(20, (700 + 60 * level) / max(1, b.price))
        deals.append(TradeDeal(id: 1, give: [ResourceAmount(kind: b, amount: m)], coinsPrice: 0, reward: .ticket))

        // Набор семян за полцены
        let crops = CropID.allCases.filter { $0.spec.level <= level }
        let crop = crops.isEmpty ? CropID.wheat : rng.pick(crops)
        deals.append(TradeDeal(id: 2, give: [], coinsPrice: max(1, crop.spec.seedPrice * 6 / 2), reward: .seeds(crop, 6)))
        return deals
    }

    func dealBought(_ deal: TradeDeal) -> Bool {
        save.dealsDay == today && save.dealsBought.contains(deal.id)
    }

    func canTrade(_ deal: TradeDeal) -> Bool {
        !dealBought(deal) && canAfford(Cost(coins: deal.coinsPrice, items: deal.give))
    }

    @discardableResult
    func trade(_ deal: TradeDeal) -> Bool {
        guard canTrade(deal) else { return false }
        pay(Cost(coins: deal.coinsPrice, items: deal.give))
        switch deal.reward {
        case .coins(let n): addCoins(n)
        case .ticket: save.tickets += 1
        case .seeds(let crop, let n): save.seeds[crop, default: 0] += n
        }
        if save.dealsDay != today {
            save.dealsDay = today
            save.dealsBought = []
        }
        save.dealsBought.append(deal.id)
        SoundFX.play(.purchase)
        markDirty()
        return true
    }

    /// Бродячий торговец приходит в локацию на три минуты с тремя редкими товарами.
    func spawnWanderer(at location: LocationID) {
        var rng = DayRandom(seed: Int(Date().timeIntervalSince1970) / 60)
        let level = save.level
        var offers: [WandererOffer] = [rng.next() % 2 == 0 ? WandererOffer(id: 0, goods: .ticket, price: 800 + 80 * level)
                                                        : WandererOffer(id: 0, goods: .map, price: TreasureMaps.wandererPrice(level: level))]
        let crops = CropID.allCases.filter { $0.spec.level <= level + 4 }
        let crop = rng.pick(Array(crops.suffix(4)))
        offers.append(WandererOffer(id: 1, goods: .seeds(crop, 6), price: max(10, Int(Double(crop.spec.seedPrice * 6) * 0.6))))
        let rare: [ResourceKind] = [.crystal, .ruby, .diamond, .pearl, .coral, .honey, .goldenApple, .obsidian]
        let kind = rng.pick(rare)
        let count = rng.int(2...4)
        offers.append(WandererOffer(id: 2, goods: .resource(kind, count), price: Int(Double(kind.price * count) * 1.6)))
        wanderer = WandererVisit(location: location, until: Date().addingTimeInterval(180), offers: offers)
    }

    func dismissWanderer() {
        if wanderer != nil { wanderer = nil }
        if traderPrompt == .wanderer { traderPrompt = nil }
    }

    @discardableResult
    func buyWanderer(_ offer: WandererOffer) -> Bool {
        guard var visit = wanderer, !visit.bought.contains(offer.id), save.coins >= offer.price else { return false }
        save.coins -= offer.price
        switch offer.goods {
        case .ticket: save.tickets += 1
        case .map: save.maps += 1
        case .seeds(let crop, let n): save.seeds[crop, default: 0] += n
        case .resource(let kind, let n): addToStorage(kind, n, counts: false)
        }
        visit.bought.insert(offer.id)
        wanderer = visit
        SoundFX.play(.purchase)
        markDirty()
        return true
    }
}

enum PlaceKind: Equatable {
    case house, pen, hunter
}

// MARK: Дом

extension GameState {
    func isBuilt(_ floor: HouseFloor) -> Bool { save.houseFloors.contains(floor) }

    func canBuild(_ floor: HouseFloor) -> Bool {
        !isBuilt(floor) && save.level >= floor.level && canAfford(floor.cost)
    }

    @discardableResult
    func build(_ floor: HouseFloor) -> Bool {
        guard canBuild(floor) else { return false }
        pay(floor.cost)
        save.houseFloors.append(floor)
        recalc()
        SoundFX.play(.unlock)
        saveNow()
        return true
    }

    // MARK: Прогулка по дому

    var currentFloor: HouseFloor? { save.current.floor }

    func setHomePrompt(_ value: HomePrompt?) {
        if homePrompt != value { homePrompt = value }
    }

    /// Войти в дом с поляны: появляемся у двери на первом этаже.
    func enterHouse() {
        arrivalStation = .exit
        arrivalGate = nil
        save.current = .homeGround
        encounter = nil
        gatePrompt = nil
        placePrompt = nil
        markDirty()
    }

    /// Выйти из дома на поляну, к двери.
    func leaveHouse() {
        arrivalStation = nil
        arriveAtDoor = true
        arrivalGate = nil
        save.current = .meadow
        homePrompt = nil
        markDirty()
    }

    /// Подняться или спуститься по лестнице.
    func goFloor(_ floor: HouseFloor, via stairs: HomeStation) {
        guard isBuilt(floor) else { return }
        arrivalStation = stairs == .up ? .down : .up
        save.current = floor.location
        homePrompt = nil
        markDirty()
    }

    /// Перейти на другой этаж кнопкой: появляемся в середине комнаты.
    func switchFloor(_ floor: HouseFloor) {
        guard isBuilt(floor), currentFloor != floor else { return }
        arrivalStation = nil
        save.current = floor.location
        homePrompt = nil
        SoundFX.play(.tap)
        markDirty()
    }

    /// Поспать: здоровье полностью восстанавливается.
    func rest() {
        healFull()
        toast("px:bed", tr("toast.rest"))
        SoundFX.play(.success)
    }

    func isEarned(_ trophy: Trophy) -> Bool { trophyProgress(trophy) >= trophy.target }

    func trophyProgress(_ trophy: Trophy) -> Int {
        switch trophy {
        case .wolf, .bear: save.kills
        case .shield: save.claimed.count
        case .sword: save.tools[.sword] ?? 1
        case .star: ConstellationID.allCases.filter { isComplete($0) }.count
        case .cup: save.rebirths
        }
    }

    // MARK: Уровень кухни

    var nextKitchenCost: Cost? {
        save.kitchenLevel < Kitchen.maxLevel ? Kitchen.cost(save.kitchenLevel + 1) : nil
    }

    func canUpgradeKitchen() -> Bool {
        guard let cost = nextKitchenCost else { return false }
        return save.level >= Kitchen.requiredLevel(save.kitchenLevel + 1) && canAfford(cost)
    }

    func upgradeKitchen() {
        guard canUpgradeKitchen(), let cost = nextKitchenCost else { return }
        pay(cost)
        save.kitchenLevel += 1
        SoundFX.play(.levelUp)
        toast("px:dish_omelette", tr("toast.kitchen", save.kitchenLevel))
        saveNow()
    }

    func decor(at slot: String) -> DecorID? { save.decor[slot] }

    var comfort: Int { save.decor.values.reduce(0) { $0 + $1.comfort } }

    /// Украшение ивента можно поставить, только если оно получено, и только одно.
    func hasDecor(_ decor: DecorID) -> Bool { decor.event == nil || save.eventDecor.contains(decor.rawValue) }

    func canPlace(_ decor: DecorID) -> Bool {
        if decor.event != nil { return hasDecor(decor) && !save.decor.values.contains(decor) }
        return canAfford(decor.cost)
    }

    @discardableResult
    func place(_ decor: DecorID, at slot: String) -> Bool {
        guard save.decor[slot] == nil, canPlace(decor) else { return false }
        pay(decor.cost)
        save.decor[slot] = decor
        recalc()
        SoundFX.play(.purchase)
        markDirty()
        return true
    }

    func removeDecor(at slot: String) {
        guard save.decor[slot] != nil else { return }
        save.decor[slot] = nil
        recalc()
        markDirty()
    }

    func setPlacePrompt(_ value: PlaceKind?) {
        if placePrompt != value { placePrompt = value }
    }

    /// Чердак с подзорной трубой: бесплатный билет вдвое чаще.
    var freeTicketInterval: Double {
        isBuilt(.attic) ? Expedition.freeTicketEvery / 2 : Expedition.freeTicketEvery
    }

    // MARK: Кухня

    var cookSlots: Int { Kitchen.slots(save.kitchenLevel) }

    func cookTime(_ dish: DishID) -> Double { dish.cookTime * Kitchen.speed(save.kitchenLevel) * stats.cookMult }

    func dishes(_ dish: DishID) -> Int { save.dishes[dish] ?? 0 }

    var totalDishes: Int { save.dishes.values.reduce(0, +) }

    func canCook(_ dish: DishID) -> Bool {
        save.cooking.count < cookSlots && canAfford(Cost(coins: 0, items: dish.ingredients))
    }

    @discardableResult
    func cook(_ dish: DishID) -> Bool {
        collectDishes()
        guard canCook(dish) else { return false }
        pay(Cost(coins: 0, items: dish.ingredients))
        save.cooking.append(CookJob(dish: dish, readyAt: Date().addingTimeInterval(cookTime(dish))))
        SoundFX.play(.pick)
        markDirty()
        return true
    }

    /// Готовые блюда с плиты переходят в запасы.
    @discardableResult
    func collectDishes() -> Int {
        let now = Date()
        let ready = save.cooking.filter { $0.readyAt <= now }
        guard !ready.isEmpty else { return 0 }
        for job in ready { save.dishes[job.dish, default: 0] += 1 }
        save.cooking.removeAll { $0.readyAt <= now }
        markDirty()
        return ready.count
    }

    /// Сколько блюд может действовать одновременно.
    var mealSlots: Int { Kitchen.mealSlots(save.kitchenLevel) }

    /// Действующие блюда: ближайшее к концу первым.
    var activeMeals: [ActiveMeal] {
        let now = Date()
        return save.meals.filter { $0.value > now }.map { ActiveMeal(dish: $0.key, until: $0.value) }.sorted { $0.until < $1.until }
    }

    func mealDuration(_ dish: DishID) -> Double { dish.duration * (isBuilt(.basement) ? 1.5 : 1) * stats.mealMult }

    /// Можно ли съесть: есть в запасах и есть свободное место (или это блюдо уже действует и продлится).
    func canEat(_ dish: DishID) -> Bool {
        guard dishes(dish) > 0 else { return false }
        return save.meals[dish].map { $0 > Date() } == true || activeMeals.count < mealSlots
    }

    @discardableResult
    func eat(_ dish: DishID) -> Bool {
        guard dishes(dish) > 0 else { return false }
        guard canEat(dish) else {
            toast("px:dish_stew", tr("toast.mealsFull", mealSlots))
            return false
        }
        heal(0.4)
        save.dishes[dish] = dishes(dish) - 1
        // То же блюдо ещё раз продлевает его действие.
        let start = max(Date(), save.meals[dish] ?? .distantPast)
        save.meals[dish] = min(start.addingTimeInterval(mealDuration(dish)), Date().addingTimeInterval(mealDuration(dish) * 3))
        recalc()
        SoundFX.play(.success)
        toast("px:" + dish.icon, tr("toast.meal", dish.name))
        saveNow()
        return true
    }

    /// Блюдо закончилось: убираем бонус.
    func refreshMeal() {
        let now = Date()
        if save.meals.contains(where: { $0.value <= now }) {
            save.meals = save.meals.filter { $0.value > now }
            recalc()
            markDirty()
        }
        collectDishes()
    }

    // MARK: Календарь

    private var dayIndex: Int {
        Int(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970 / 86_400)
    }

    var canClaimLogin: Bool { save.loginDay != dayIndex }

    func loginReward(_ claim: Int) -> LoginCalendar.Reward {
        LoginCalendar.reward(claim: claim, level: save.level)
    }

    func claimLogin() {
        guard canClaimLogin else { return }
        switch loginReward(save.loginClaims) {
        case .coins(let n): addCoins(n)
        case .seeds(let crop, let n): save.seeds[crop, default: 0] += n
        case .tickets(let n): save.tickets += n
        case .coinsAndWood(let n, let wood):
            addCoins(n)
            addToStorage(.wood, wood, counts: false)
        case .dish(let dish): save.dishes[dish, default: 0] += 1
        case .resource(let kind, let n): addToStorage(kind, n, counts: false)
        case .chest(let tickets, let coins):
            save.tickets += tickets
            addCoins(coins)
            randomCard()
        }
        save.loginDay = dayIndex
        save.loginClaims += 1
        SoundFX.play(.treasure)
        saveNow()
    }
}

// MARK: Бой и охота

extension GameState {
    var maxHP: Double {
        Hero.maxHP(level: save.level, armor: tier(.armor), helmet: tier(.helmet)) * (1 + gear.hpBonus) * stats.hpMult
    }

    /// Доля урона, которую гасит шлем.
    var defense: Double { min(0.65, Hero.defense(helmet: tier(.helmet)) + gear.defense + stats.defenseBonus) }

    /// Шанс увернуться от укуса.
    var dodgeChance: Double { min(0.4, Hero.dodge(boots: tier(.boots)) + gear.dodge + stats.dodgeBonus) }

    var hpFraction: Double { min(1, max(0, hp / max(1, maxHP))) }

    func setInCombat(_ value: Bool) {
        if inCombat != value { inCombat = value }
    }

    func setBossInfo(_ value: BossInfo?) {
        if bossInfo != value { bossInfo = value }
    }

    /// Урон герою с учётом шлема. Возвращает, сколько здоровья ушло.
    @discardableResult
    func hurtHero(_ amount: Double) -> Double {
        let dealt = amount * (1 - defense)
        var next = max(0, min(hp, maxHP) - dealt)
        // Второе дыхание (броня 10 ступени): раз в 5 минут герой не падает.
        if next <= 0 && gear.secondWind && Date().timeIntervalSince(lastSecondWind) > 300 {
            lastSecondWind = Date()
            next = maxHP * 0.3
            toast("px:heart_plus", tr("toast.secondWind"))
        }
        // Последний рубеж (талант): раз в 3 минуты.
        if next <= 0 && stats.lastStand && Date().timeIntervalSince(lastStandAt) > 180 {
            lastStandAt = Date()
            next = maxHP * 0.25
            toast("px:heart_shield", tr("toast.lastStand"))
        }
        hp = next
        return dealt
    }

    /// Лечит на долю от максимума.
    func heal(_ fraction: Double) {
        let next = min(maxHP, hp + maxHP * fraction)
        if abs(next - hp) > 0.01 { hp = next }
    }

    /// Лечит на число единиц здоровья (вампиризм).
    func healAmount(_ amount: Double) {
        let next = min(maxHP, hp + amount)
        if abs(next - hp) > 0.01 { hp = next }
    }

    func healFull() {
        if hp != maxHP { hp = maxHP }
    }

    /// Герой упал без сил: просыпается у склада и теряет часть рюкзака (немного).
    func faint() -> Int {
        var lost = 0
        for (kind, n) in save.backpack {
            let drop = n * 15 / 100
            if drop > 0 {
                save.backpack[kind] = n - drop
                lost += drop
            }
        }
        hp = maxHP * 0.6
        markDirty()
        return lost
    }

    // MARK: Оружие

    func weaponTier(_ id: WeaponID) -> Int { id == .forged ? tier(.sword) : (save.weapons[id] ?? 0) }

    func ownsWeapon(_ id: WeaponID) -> Bool { weaponTier(id) > 0 }

    func equip(_ id: WeaponID) {
        guard ownsWeapon(id), save.weapon != id else { return }
        save.weapon = id
        recalc()
        SoundFX.play(.tap)
        markDirty()
    }

    /// Урон текущим оружием за удар.
    func weaponDamage(boss: Bool = false) -> Double {
        let w = save.weapon
        let base = Hero.swordDamage(level: save.level, sword: max(1, weaponTier(w))) * w.mult
        let rage = hpFraction < 0.5 ? 1 + stats.berserk : 1
        return base * stats.damageMult * stats.swordMult * stats.weaponMult * rage
            * (boss ? 1 + gear.bossDamage + stats.bossBonus : 1)
    }

    func swordDamage() -> Double { weaponDamage() }

    func weaponUpgradeCost(_ id: WeaponID) -> Cost? {
        guard id != .forged, ownsWeapon(id), weaponTier(id) < ToolTier.maxTier else { return nil }
        return discounted(WeaponID.upgradeCost(to: weaponTier(id) + 1))
    }

    func canUpgradeWeapon(_ id: WeaponID) -> Bool {
        guard let cost = weaponUpgradeCost(id) else { return false }
        return save.level >= ToolTier.requiredLevel(.sword, tier: weaponTier(id) + 1) && canAfford(cost)
    }

    func upgradeWeapon(_ id: WeaponID) {
        guard canUpgradeWeapon(id), let cost = weaponUpgradeCost(id) else { return }
        pay(cost)
        save.weapons[id] = weaponTier(id) + 1
        recalc()
        SoundFX.play(.unlock)
        toast("px:sword", tr("toast.weaponUp", id.name, weaponTier(id)))
        saveNow()
    }

    /// Получить особое оружие (с босса или за покупку).
    func grantWeapon(_ id: WeaponID) {
        guard id != .forged else { return }
        if ownsWeapon(id) { return }
        save.weapons[id] = id.startTier
        toast("px:sword", tr("toast.weaponNew", id.name))
        markDirty()
    }

    // MARK: Зелья

    func potionPrice(_ count: Int) -> Int { Potion.price(level: save.level) * count }

    func buyPotions(_ count: Int) {
        let price = potionPrice(count)
        guard save.coins >= price else { return }
        save.coins -= price
        save.potions += count
        SoundFX.play(.purchase)
        markDirty()
    }

    var potionReady: Bool { save.potions > 0 && Date().timeIntervalSince(lastPotion) > Potion.cooldown }

    func drinkPotion() {
        guard potionReady, hp < maxHP else { return }
        save.potions -= 1
        lastPotion = Date()
        heal(Potion.heal + stats.potionBonus)
        SoundFX.play(.success)
        markDirty()
    }

    // MARK: Подземелья

    func dungeonBest(_ id: DungeonID) -> Int { save.dungeonBest[id] ?? 0 }

    var inDungeon: Bool { save.current.spec.kind == .dungeon && dungeonRun != nil }

    func canEnter(_ id: DungeonID, floor: Int) -> Bool {
        save.level >= id.level && floor >= 1 && floor <= min(Dungeon.floors, dungeonBest(id) + 1)
            && save.expedition == nil && dungeonRun == nil
    }

    func startDungeon(_ id: DungeonID, floor: Int) {
        guard canEnter(id, floor: floor) else { return }
        if backpackCount > 0 { depositBackpack() }
        dungeonReturn = save.current.spec.kind == .world || save.current.spec.kind == .garden ? save.current : .meadow
        dungeonRun = DungeonRun(dungeon: id, floor: floor, waves: Dungeon.waves(floor: floor))
        arrivalGate = nil
        save.current = id.location
        encounter = nil
        gatePrompt = nil
        healFull()
        markDirty()
    }

    func setDungeonWave(_ wave: Int) {
        guard var run = dungeonRun, run.wave != wave else { return }
        run.wave = wave
        dungeonRun = run
    }

    func dungeonCleared() {
        guard var run = dungeonRun, !run.cleared else { return }
        run.cleared = true
        dungeonRun = run
        SoundFX.play(.levelUp)
        toast("px:trophy", tr("toast.floorCleared", run.floor))
    }

    /// Сундук после этажа: монеты, эссенция, зелья, карта и, может быть, оружие босса.
    func openDungeonChest() {
        guard var run = dungeonRun, run.cleared, !run.chestOpened else { return }
        let id = run.dungeon
        let first = run.floor > dungeonBest(id)
        let coins = Int(Double(Dungeon.coins(id, floor: run.floor, first: first)) * (1 + stats.dungeonBonus))
        let essence = Int((Double(Dungeon.essence(id, floor: run.floor, first: first)) * (1 + stats.dungeonBonus)).rounded())
        addCoins(coins)
        addToStorage(.essence, essence, counts: false)
        let potions = first ? 2 : (Double.random(in: 0..<1) < 0.3 ? 1 : 0)
        save.potions += potions
        var weapon: WeaponID?
        if Dungeon.isBossFloor(run.floor), !ownsWeapon(id.weapon), Double.random(in: 0..<1) < Dungeon.weaponChance(floor: run.floor, first: first) {
            grantWeapon(id.weapon)
            weapon = id.weapon
        }
        randomCard()
        rollCard(for: .essence, chance: 0.25)
        let maps = Dungeon.isBossFloor(run.floor) || Double.random(in: 0..<1) < TreasureMaps.dungeonChance ? 1 : 0
        save.maps += maps
        if first {
            save.dungeonBest[id] = run.floor
            if Dungeon.isBossFloor(run.floor) {
                recalc()
                toast("px:star", tr("toast.dungeonTalent"))
            }
        }
        run.chestOpened = true
        run.coins += coins
        run.essence += essence
        dungeonRun = run
        lastChest = DungeonReport(dungeon: id, floor: run.floor, won: true, firstClear: first, coins: run.coins,
                                  essence: run.essence, weapon: weapon, potions: potions, maps: maps)
        SoundFX.play(.treasure)
        saveNow()
    }

    /// Выйти из подземелья: через портал после победы или раньше (тогда награды за этаж нет).
    func leaveDungeon() {
        guard let run = dungeonRun else { return }
        dungeonReport = run.chestOpened ? lastChest
            : DungeonReport(dungeon: run.dungeon, floor: run.floor, won: false, firstClear: false, coins: run.coins,
                            essence: run.essence, weapon: nil, potions: 0)
        dungeonRun = nil
        lastChest = nil
        bossInfo = nil
        arrivalGate = nil
        save.current = dungeonReturn
        encounter = nil
        healFull()
        saveNow()
    }

    /// Награда за убийство в подземелье копится в итоге забега.
    func noteDungeonKill(coins: Int, essence: Int) {
        guard var run = dungeonRun else { return }
        run.kills += 1
        run.coins += coins
        run.essence += essence
        dungeonRun = run
    }

    /// Монстр побеждён: опыт, монеты, трофеи, заказы стражника.
    func noteKill(_ kind: MonsterKind, level: Int, boss: Bool = false) -> (coins: Int, loot: Int) {
        let st = MonsterStats(kind: kind, level: level, boss: boss)
        save.kills += 1
        addCoins(st.coins)
        let loot = Int.random(in: 1...(kind == .slimeGold ? 4 : 2))
        let direct = inExpedition || inDungeon
        let added = direct ? addToStorage(kind.loot, loot) : addToBackpack(kind.loot, loot)
        if inDungeon {
            let essence = Double.random(in: 0..<1) < 0.2 ? 1 : 0
            if essence > 0 { addToStorage(.essence, essence, counts: false) }
            noteDungeonKill(coins: st.coins, essence: essence)
        }
        gainXP(st.xp)
        rollCard(for: kind)
        if inEvent {
            if boss { eventBossDefeated() } else { addEventPoints(eventPoints(for: kind, boss: false)) }
        }
        ensureHunts()
        for i in save.hunts.indices where save.hunts[i].monster == kind && !save.hunts[i].done {
            save.hunts[i].progress += 1
            if save.hunts[i].done { toast("px:sword", tr("toast.huntDone", kind.name)) }
        }
        markDirty()
        return (st.coins, added)
    }

    private var huntToday: Int {
        Int(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970 / 86_400)
    }

    var nextHuntsAt: Date {
        let start = Calendar.current.startOfDay(for: Date())
        return Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
    }

    /// Три заказа на день: монстры из уже открытых локаций.
    func ensureHunts() {
        guard save.huntDay != huntToday || save.hunts.isEmpty else { return }
        save.huntDay = huntToday
        var kinds: [MonsterKind] = []
        for id in save.unlocked where id.spec.kind == .world {
            for (kind, _) in Bestiary.monsters(in: id) where !kinds.contains(kind) { kinds.append(kind) }
        }
        if kinds.isEmpty { kinds = [.slimeGreen] }
        var rng = DayRandom(seed: huntToday * 131 + save.level)
        var made: [HuntContract] = []
        for i in 0..<3 {
            let kind = rng.pick(kinds)
            let target = [5, 8, 12][i]
            let level = Bestiary.home(of: kind).map { Bestiary.level(in: $0) }.min() ?? 3
            let st = MonsterStats(kind: kind, level: level)
            made.append(HuntContract(monster: kind, target: target, coins: st.coins * target * 3,
                                     xp: st.xp * target, ticket: i == 2))
        }
        save.hunts = made
        markDirty()
    }

    var claimableHunts: Int { save.hunts.filter(\.done).count }

    func claimHunt(_ id: UUID) {
        guard let i = save.hunts.firstIndex(where: { $0.id == id }), save.hunts[i].done else { return }
        let hunt = save.hunts.remove(at: i)
        addCoins(hunt.coins)
        if hunt.ticket { save.tickets += 1 }
        gainXP(hunt.xp)
        SoundFX.play(.success)
        saveNow()
    }
}

// MARK: Коллекция

extension GameState {
    func cardCount(_ card: CardID) -> Int { save.cards[card] ?? 0 }

    func cardStars(_ card: CardID) -> Int { Cards.stars(count: cardCount(card)) }

    func isComplete(_ c: ConstellationID) -> Bool { c.cards.allSatisfy { cardCount($0) > 0 } }

    func minStars(_ c: ConstellationID) -> Int { c.cards.map { cardStars($0) }.min() ?? 0 }

    func constellationBonus(_ c: ConstellationID) -> Double {
        isComplete(c) ? ConstellationID.bonus(minStars: minStars(c)) : 0
    }

    var cardsOwned: Int { CardID.allCases.filter { cardCount($0) > 0 }.count }

    /// Новая карта (или копия, которая поднимает звёзды).
    func gainCard(_ card: CardID) {
        let wasComplete = isComplete(card.constellation)
        let before = cardStars(card)
        save.cards[card, default: 0] += 1
        let after = cardStars(card)
        if before == 0 {
            toast("px:cards", tr("toast.card", card.name))
        } else if after > before {
            toast("px:star", tr("toast.cardStar", card.name, after))
        }
        if !wasComplete && isComplete(card.constellation) {
            toast("px:spark", tr("toast.constellation", card.constellation.name))
            SoundFX.play(.unlock)
        }
        recalc()
        markDirty()
    }

    /// Шанс карты при добыче ресурса.
    func rollCard(for kind: ResourceKind, chance: Double = 0.012) {
        guard let card = CardID.forResource(kind), Double.random(in: 0..<1) < chance else { return }
        gainCard(card)
    }

    func rollCard(for monster: MonsterKind) {
        guard let card = CardID.forMonster(monster), Double.random(in: 0..<1) < 0.05 else { return }
        gainCard(card)
    }

    func randomCard() {
        if let card = CardID.allCases.randomElement() { gainCard(card) }
    }

    // MARK: Пробуждение и редкие окраски

    func awakenLevel(_ id: AnimalID) -> Int { save.awaken[id] ?? 0 }

    func isShiny(_ id: AnimalID) -> Bool { save.shiny.contains(id) }

    /// Сила зверя от пробуждения и редкой окраски.
    func animalBoost(_ id: AnimalID) -> Double {
        Awakening.multiplier(awakenLevel(id)) * (isShiny(id) ? 1 + Shiny.bonus : 1)
    }

    func awakenCost(_ id: AnimalID) -> Cost? {
        let next = awakenLevel(id) + 1
        guard stars(id) >= AnimalSpec.maxStars, next <= Awakening.maxLevel else { return nil }
        return Awakening.cost(level: next)
    }

    func canAwaken(_ id: AnimalID) -> Bool {
        guard let cost = awakenCost(id) else { return false }
        return canAfford(cost)
    }

    func awakenAnimal(_ id: AnimalID) {
        guard canAwaken(id), let cost = awakenCost(id) else { return }
        pay(cost)
        save.awaken[id] = awakenLevel(id) + 1
        recalc()
        SoundFX.play(.levelUp)
        toast("px:star", tr("toast.awaken", id.spec.name, Awakening.title(awakenLevel(id))))
        saveNow()
    }

    func markShiny(_ id: AnimalID) {
        guard !save.shiny.contains(id) else { return }
        save.shiny.append(id)
        toast("px:rainbow", tr("toast.shiny", id.spec.name))
        recalc()
        markDirty()
    }
}


// MARK: Ивенты

extension GameState {
    var eventsOpen: Bool { save.level >= Events.minLevel }

    var hasVip: Bool { save.vipKeys.contains(Events.current.key) }

    var eventTier: Int { Events.tier(points: save.eventPoints) }

    var inEvent: Bool { save.current.spec.kind == .event }

    /// Ивент ещё не открывали: на кнопке горит отметка.
    var eventIsNew: Bool { eventsOpen && save.eventSeen != Events.current.key }

    func markEventSeen() {
        let key = Events.current.key
        guard save.eventSeen != key else { return }
        save.eventSeen = key
        markDirty()
    }

    /// Начался новый проход ивента: незабранные награды выдаём сами, очки обнуляем.
    func syncEvent() {
        let run = Events.current
        LocationLayout.eventVariant = Events.variant(stage: save.eventKey == run.key ? save.eventStage : 1, run: run.index)
        guard save.eventKey != run.key else { return }
        if !save.eventKey.isEmpty { claimLeftovers(key: save.eventKey) }
        let first = save.eventKey.isEmpty
        save.eventKey = run.key
        save.eventPoints = 0
        save.eventFree = []
        save.eventVip = []
        save.eventBonus = 0
        save.eventStage = 1
        save.eventProgress = 0
        save.eventBest = 0
        save.eventBoons = [:]
        save.eventChoice = []
        LocationLayout.eventVariant = Events.variant(stage: 1, run: run.index)
        mapVersion += 1
        if eventsOpen && !first { toast("px:star", tr("toast.eventStarted", run.event.name)) }
        markDirty()
    }

    private func claimLeftovers(key: String) {
        guard let raw = key.split(separator: "-").first, let event = EventID(rawValue: String(raw)) else { return }
        let tier = Events.tier(points: save.eventPoints)
        guard tier > 0 else { return }
        let vip = save.vipKeys.contains(key)
        var any = false
        for t in 1...tier {
            if !save.eventFree.contains(t) { grantEventReward(Events.free(tier: t), event: event); any = true }
            if vip && !save.eventVip.contains(t) { grantEventReward(Events.vip(tier: t), event: event); any = true }
        }
        if any { toast("px:chest", tr("toast.eventLeftovers", event.name)) }
    }

    func canClaimEvent(_ tier: Int, vip: Bool) -> Bool {
        guard tier <= eventTier else { return false }
        return vip ? hasVip && !save.eventVip.contains(tier) : !save.eventFree.contains(tier)
    }

    /// Бонусные сундуки после последней ступени.
    var eventBonusReady: Int {
        let extra = save.eventPoints - Events.total
        guard extra >= Events.bonusEvery else { return 0 }
        return extra / Events.bonusEvery - save.eventBonus
    }

    /// Сколько наград ждёт (для значка на кнопке).
    var eventClaimable: Int {
        guard eventsOpen else { return 0 }
        var n = 0
        for t in 1...Events.tiers {
            if canClaimEvent(t, vip: false) { n += 1 }
            if canClaimEvent(t, vip: true) { n += 1 }
        }
        return n + max(0, eventBonusReady)
    }

    func claimEvent(_ tier: Int, vip: Bool) {
        syncEvent()
        guard canClaimEvent(tier, vip: vip) else { return }
        let event = Events.current.event
        if vip {
            save.eventVip.append(tier)
            grantEventReward(Events.vip(tier: tier), event: event)
        } else {
            save.eventFree.append(tier)
            grantEventReward(Events.free(tier: tier), event: event)
        }
        SoundFX.play(.treasure)
        saveNow()
    }

    func claimAllEvent() {
        syncEvent()
        let event = Events.current.event
        var any = false
        for t in 1...Events.tiers {
            if canClaimEvent(t, vip: false) {
                save.eventFree.append(t)
                grantEventReward(Events.free(tier: t), event: event)
                any = true
            }
            if canClaimEvent(t, vip: true) {
                save.eventVip.append(t)
                grantEventReward(Events.vip(tier: t), event: event)
                any = true
            }
        }
        if eventBonusReady > 0 { claimEventBonus(); any = true }
        guard any else { return }
        SoundFX.play(.treasure)
        saveNow()
    }

    func claimEventBonus() {
        guard eventBonusReady > 0 else { return }
        let n = eventBonusReady
        save.eventBonus += n
        addCoins(Events.bonusCoins(level: save.level) * n)
        for _ in 0..<n { randomCard() }
        toast("px:chest", tr("toast.eventBonus", n))
        markDirty()
    }

    func eventRewardCoins(_ base: Int) -> Int { Events.coins(base, level: save.level) }

    private func grantEventReward(_ reward: Events.Reward, event: EventID) {
        switch reward {
        case .coins(let n): addCoins(eventRewardCoins(n))
        case .tickets(let n): save.tickets += n
        case .seeds(let n): save.seeds[event.crop, default: 0] += n
        case .dish(let n): save.dishes[event.dish, default: 0] += n
        case .cards(let n): for _ in 0..<n { randomCard() }
        case .sparks(let n):
            save.sparks += n
            save.sparksEarned += n
        case .maps(let n): save.maps += n
        case .decor:
            if save.eventDecor.contains(event.decor.rawValue) {
                addCoins(eventRewardCoins(1500))
            } else {
                save.eventDecor.append(event.decor.rawValue)
                toast("px:stairs", tr("toast.eventDecor", event.decor.name))
            }
        case .skin:
            if save.eventSkins.contains(event.skin.rawValue) {
                addCoins(eventRewardCoins(3000))
            } else {
                save.eventSkins.append(event.skin.rawValue)
                toast("skin:" + event.skin.rawValue, tr("toast.eventSkin", event.skin.name))
            }
        }
    }

    /// Очки ивента за добычу и монстров на карте ивента: идут и в пропуск, и в цель этапа.
    /// Возвращает, сколько очков начислено с учётом усилений.
    @discardableResult
    func addEventPoints(_ base: Int) -> Int {
        guard base > 0, inEvent else { return 0 }
        syncEvent()
        let n = Int((Double(base) * (1 + boonValue(.points))).rounded())
        addPassPoints(n)
        addStageProgress(n)
        markDirty()
        return n
    }

    private func addPassPoints(_ n: Int) {
        let before = eventTier
        save.eventPoints += n
        let after = eventTier
        if after > before {
            toast("px:star", tr("toast.eventTier", after))
            SoundFX.play(.unlock)
        }
    }

    // MARK: Этапы ивента

    func boonRank(_ boon: EventBoon) -> Int { save.eventBoons[boon] ?? 0 }

    /// Сила усиления (только на картах ивента).
    func boonValue(_ boon: EventBoon) -> Double { inEvent ? boon.perRank * Double(boonRank(boon)) : 0 }

    /// Очки за особую точку и за монстра с учётом усилений "Урожай" и "Охотник".
    func eventPoints(for type: NodeType) -> Int {
        let base = Events.points(for: type)
        return base > 0 ? base + Int(boonValue(.harvest)) : 0
    }

    func eventPoints(for monster: MonsterKind, boss: Bool) -> Int {
        boss ? Events.bossPoints : Events.points(for: monster) + Int(boonValue(.hunter))
    }

    var eventTarget: Int { Events.target(stage: save.eventStage) }
    var eventBossStage: Bool { Events.isBossStage(save.eventStage) }

    /// Сколько нужно для прохождения: на этапе с боссом - ещё и победа над ним.
    var eventGoal: Int { eventTarget + (eventBossStage ? Events.bossPoints : 0) }

    var eventStageCleared: Bool { save.eventProgress >= eventGoal }

    /// Цель собрана, пора звать босса.
    var eventBossDue: Bool { eventBossStage && save.eventProgress >= eventTarget && !eventStageCleared }

    private func addStageProgress(_ n: Int) {
        guard !eventStageCleared else { return }
        // Пока босс жив, прогресс этапа не растёт выше цели.
        let cap = eventBossStage ? eventTarget : eventGoal
        save.eventProgress = min(cap, save.eventProgress + n)
        if eventStageCleared { stageCleared() }
    }

    /// Босс этапа побеждён.
    func eventBossDefeated() {
        guard inEvent, eventBossStage, !eventStageCleared else { return }
        addPassPoints(Events.bossPoints)
        save.eventProgress = eventGoal
        stageCleared()
        markDirty()
    }

    private func stageCleared() {
        let stage = save.eventStage
        save.eventBest = max(save.eventBest, stage)
        addPassPoints(Events.clearPoints(stage: stage))
        addCoins(Events.clearCoins(stage: stage, level: save.level))
        if Events.isBossStage(stage) {
            save.maps += 1
            toast("px:tmap", tr("toast.map"))
        }
        toast("px:portal", tr("toast.stageCleared", stage))
        SoundFX.play(.levelUp)
        saveNow()
    }

    /// Герой вошёл в портал: предлагаем три усиления (или сразу дальше, если всё на максимуме).
    func enterEventPortal() {
        guard inEvent, eventStageCleared, save.eventChoice.isEmpty else { return }
        let open = EventBoon.allCases.filter { boonRank($0) < EventBoon.maxRank }
        if open.isEmpty {
            nextStage()
        } else {
            save.eventChoice = Array(open.shuffled().prefix(3))
            markDirty()
        }
    }

    func chooseBoon(_ boon: EventBoon) {
        guard save.eventChoice.contains(boon) else { return }
        save.eventBoons[boon] = min(EventBoon.maxRank, boonRank(boon) + 1)
        save.eventChoice = []
        SoundFX.play(.unlock)
        nextStage()
    }

    private func nextStage() {
        save.eventStage += 1
        save.eventProgress = 0
        LocationLayout.eventVariant = Events.variant(stage: save.eventStage, run: Events.current.index)
        mapVersion += 1
        recalc()
        toast("px:star", tr("toast.stageStart", save.eventStage))
        saveNow()
    }

    /// Упал без сил на этапе: теряется четверть набранного прогресса.
    func eventFaint() {
        guard inEvent, !eventStageCleared else { return }
        let cap = eventBossStage ? min(save.eventProgress, eventTarget) : save.eventProgress
        save.eventProgress = cap * 3 / 4
        markDirty()
    }

    /// Купили VIP-пропуск: он действует на текущий ивент.
    func activateVip() {
        syncEvent()
        let key = Events.current.key
        guard !save.vipKeys.contains(key) else { return }
        save.vipKeys.append(key)
        // Старые ключи не нужны, оставляем последние.
        if save.vipKeys.count > 8 { save.vipKeys.removeFirst(save.vipKeys.count - 8) }
        recalc()
    }

    /// Отправиться на карту ивента.
    func goToEvent() {
        syncEvent()
        travel(to: Events.current.event.location)
        recalc()
    }

    /// С карты ивента домой, на поляну.
    func leaveEvent() {
        guard inEvent else { return }
        arrivalGate = nil
        save.current = .meadow
        encounter = nil
        gatePrompt = nil
        recalc()
        markDirty()
    }
}

// MARK: Где добыть ресурс

extension GameState {
    /// Подсказка, где взять ресурс: огород, звери, локации, монстры.
    func sources(of kind: ResourceKind) -> String {
        var lines: [String] = []
        if let crop = CropID.allCases.first(where: { $0.spec.produce == kind }) {
            lines.append(tr("source.garden", crop.name, crop.spec.level))
        }
        let animals = AnimalID.allCases.filter { id in
            id.spec.effects.contains { if case .produce(let k, _) = $0 { return k == kind } else { return false } }
        }
        if !animals.isEmpty {
            lines.append(tr("source.animals", animals.map { $0.spec.name }.joined(separator: ", ")))
        }
        let places = LocationID.allCases.filter { id in
            let kindOK = id.spec.kind == .world || id.spec.kind == .garden || id.spec.kind == .expedition
            return kindOK && id.layout.nodeTypes.contains { type in type.spec.yields.contains { $0.kind == kind } }
        }
        if !places.isEmpty {
            let open = places.filter { isUnlocked($0) || $0.spec.kind == .expedition }
            let names = (open.isEmpty ? places : open).prefix(4).map { $0.spec.name }
            lines.append(tr("source.places", names.joined(separator: ", ")))
            if let node = LocationID.allCases.lazy.flatMap({ $0.layout.nodeTypes }).first(where: { t in t.spec.yields.first?.kind == kind }) {
                let spec = node.spec
                if spec.tool != .hand {
                    lines.append(tr("source.tool", spec.name, ToolTier.name(spec.tool, tier: spec.tier)))
                }
            }
        }
        let monsters = MonsterKind.allCases.filter { $0.loot == kind }
        if !monsters.isEmpty {
            lines.append(tr("source.monsters", monsters.prefix(3).map(\.name).joined(separator: ", ")))
        }
        if lines.isEmpty { lines.append(tr("source.unknown")) }
        lines.append(tr("source.have", Fmt.n(amount(kind))))
        return lines.joined(separator: "\n")
    }
}
