import Foundation
import Observation

/// Единое состояние игры. Сцена и интерфейс читают и меняют его напрямую.
@Observable
final class GameState {
    static let shared = GameState()

    private(set) var save: SaveData
    private(set) var stats = Stats()

    // Временное состояние для интерфейса, не сохраняется.
    private(set) var encounter: Encounter?
    private(set) var backpackFull = false
    private(set) var toasts: [Toast] = []
    private(set) var banner: LocationID?
    var levelUp: LevelUpInfo?
    var offlineReport: OfflineReport?
    var treasureFound: Treasure?

    @ObservationIgnored private var dirty = false
    @ObservationIgnored private var lastWrite = Date.distantPast
    @ObservationIgnored private var bannerToken = 0

    private init() {
        save = SaveFile.load()
        recalc()
        ensureQuests()
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
    }

    func resetProgress() {
        save = SaveData()
        save.tutorialDone = true
        encounter = nil
        backpackFull = false
        levelUp = nil
        offlineReport = nil
        treasureFound = nil
        recalc()
        ensureQuests()
        saveNow()
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

    var talentPointsTotal: Int { GameRules.talentPoints(at: save.level) + save.bonusTalentPoints }
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
        if save.level > from {
            recalc()
            levelUp = LevelUpInfo(from: levelUp?.from ?? from, to: save.level)
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
            if moved > 0 { toast("🌀", "Портал отправил \(moved) ресурсов на склад") }
        }
        let n = min(amount, backpackFree)
        guard n > 0 else { return 0 }
        save.backpack[kind, default: 0] += n
        save.gathered[kind, default: 0] += n
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
        }
        if spec.tier >= 5 { base *= 1 + s.highTierBonus }
        return base * s.damageMult
    }

    func nextToolCost(_ tool: ToolKind) -> Cost? {
        let next = tier(tool) + 1
        guard next <= ToolTier.maxTier else { return nil }
        return discounted(ToolTier.cost(tool, tier: next))
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
        toast(tool.emoji, "Новый инструмент: \(ToolTier.name(tool, tier: next))")
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
        return true
    }

    @discardableResult
    func tame(_ id: AnimalID) -> Bool {
        guard stars(id) < AnimalSpec.maxStars, let cost = tameCost(id), canAfford(cost) else { return false }
        pay(cost)
        let bonus = Double.random(in: 0..<1) < stats.doubleStarChance ? 2 : 1
        addStar(id, count: bonus)
        if bonus > 1 { toast("🌠", "Двойная звезда!") }
        gainXP(GameRules.tameXP(save.level))
        return true
    }

    private func addStar(_ id: AnimalID, count: Int) {
        let isNew = stars(id) == 0
        save.animals[id] = min(AnimalSpec.maxStars, stars(id) + count)
        progressQuests(.tame, amount: 1)
        if isNew {
            if save.active.count < GameRules.maxActiveAnimals {
                save.active.append(id)
                toast(id.spec.emoji, "\(id.spec.name) теперь с тобой")
            } else {
                toast(id.spec.emoji, "\(id.spec.name) ждёт в загоне: все 5 мест заняты")
            }
        } else {
            toast(id.spec.emoji, "\(id.spec.name): \(String(repeating: "★", count: stars(id)))")
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

    // MARK: Локации

    func isUnlocked(_ id: LocationID) -> Bool { save.unlocked.contains(id) }

    func unlockCost(_ id: LocationID) -> Cost { discounted(id.spec.cost) }

    @discardableResult
    func unlock(_ id: LocationID) -> Bool {
        guard !isUnlocked(id), save.level >= id.spec.level, canAfford(unlockCost(id)) else { return false }
        pay(unlockCost(id))
        save.unlocked.append(id)
        toast(id.spec.emoji, "Открыта локация: \(id.spec.name)")
        gainXP(GameRules.unlockXP(id))
        markDirty()
        return true
    }

    func travel(to id: LocationID) {
        guard isUnlocked(id), save.current != id else { return }
        save.current = id
        encounter = nil
        markDirty()
    }

    // MARK: Клады

    /// Награда за клад зависит от уровня и открытых локаций.
    func openTreasure() -> Treasure {
        let level = save.level
        let coins = Int(Double(40 + level * 25) * Double.random(in: 0.8...1.4))
        var items: [ResourceAmount] = []
        let pool = gatherableKinds
        for kind in pool.shuffled().prefix(2) {
            let n = max(1, Int(Double(20 + level * 3) / pow(Double(kind.price), 0.6) * Double.random(in: 0.7...1.3)))
            items.append(ResourceAmount(kind: kind, amount: n))
        }
        save.coins += coins
        save.coinsEarned += coins
        for item in items { addToStorage(item.kind, item.amount) }
        save.treasures += 1
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
        while save.quests.count < 3 {
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
                toast("📜", "Задание выполнено: забери награду")
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
        let fresh = Quest.make(level: save.level, available: gatherableKinds,
                               producers: stats.producers.map(\.kind), avoid: save.quests)
        save.quests.insert(fresh, at: min(index, save.quests.count))
        gainXP(quest.xp)
        markDirty()
    }

    var rerollCost: Int { 15 * save.level }

    func rerollQuest(_ id: UUID) {
        guard let index = save.quests.firstIndex(where: { $0.id == id }), save.coins >= rerollCost else { return }
        save.coins -= rerollCost
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
        case .animals: return save.animals.count
        case .stars: return save.animals.values.reduce(0, +)
        case .locations: return save.unlocked.count
        case .level: return save.level
        case .minTool: return ToolKind.upgradable.map { tier($0) }.min() ?? 1
        case .talents: return talentPointsSpent
        case .quests: return save.questsDone
        case .treasures: return save.treasures
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
        save.coins += achievement.coins
        save.coinsEarned += achievement.coins
        save.bonusTalentPoints += achievement.talentPoints
        if achievement.talentPoints > 0 {
            toast("🌟", "+\(achievement.talentPoints) очко таланта за достижение")
        }
        markDirty()
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
        s.yieldCategory[.food] = 0.2 * r(.farmer)
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
        s.autoDeposit = r(.portal) > 0

        s.animalMult = (1 + 0.12 * r(.beastBond) + 0.05 * r(.animalFriend)) * (r(.soul) > 0 ? 1.3 : 1)
        s.helperMult = (1 + 0.25 * r(.packLeader)) * (1 + 0.1 * r(.alpha))
        s.helperSpeed = 1 + 0.08 * r(.training)
        s.helperRange = 260 * (1 + 0.2 * r(.keenEye))
        s.helperTierBonus = Int(r(.packTier))
        s.helperYield = 1 + 0.15 * r(.beastLoot)
        s.producerMult = (1 + 0.2 * r(.nightShift)) * (1 + 0.1 * r(.herdsman))
        s.doubleProductChance = 0.08 * r(.rancher)
        s.offlineHours = 6 + 2 * r(.pasture)
        s.starStep = 0.25 + 0.05 * r(.starFood)
        s.doubleStarChance = 0.15 * r(.starHunter)

        var speedBonus = 0.07 * r(.swift) + 0.05 * r(.tailwind)
        var critBonus = 0.05 * r(.crit)
        var respawnBonus = 0.08 * r(.regrowth) + (r(.abundance) > 0 ? 0.5 : 0)
        var xpBonus = 0.1 * r(.scholar) + 0.06 * r(.sage)
        var sellBonus = 0.08 * r(.trader)
        var capacity = Double(GameRules.capacity(at: save.level)) + 15 * r(.bigPack)

        for id in save.active {
            let m = s.starMultiplier(save.animals[id] ?? 1) * s.animalMult
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
