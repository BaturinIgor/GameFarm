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
    var levelUp: LevelUpInfo?
    var offlineReport: OfflineReport?

    @ObservationIgnored private var dirty = false
    @ObservationIgnored private var lastWrite = Date.distantPast

    private init() {
        save = SaveFile.load()
        recalc()
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
        recalc()
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

    var talentPointsTotal: Int { GameRules.talentPoints(at: save.level) }
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
        markDirty()
        return n
    }

    @discardableResult
    func addToStorage(_ kind: ResourceKind, _ amount: Int) -> Int {
        guard amount > 0 else { return 0 }
        save.storage[kind, default: 0] += amount
        save.gathered[kind, default: 0] += amount
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
        markDirty()
        return total
    }

    func registerHarvest(xp: Int) -> Int {
        save.harvests += 1
        var coins = 0
        if stats.goldenTouch {
            coins = 1 + save.level / 5
            save.coins += coins
            save.coinsEarned += coins
        }
        gainXP(xp)
        return coins
    }

    func sellPrice(_ kind: ResourceKind) -> Int {
        max(1, Int((Double(kind.price) * stats.sellMult).rounded()))
    }

    func sell(_ kind: ResourceKind, _ amount: Int) {
        let have = save.storage[kind] ?? 0
        let n = min(amount, have)
        guard n > 0 else { return }
        save.storage[kind] = have - n
        let earned = n * sellPrice(kind)
        save.coins += earned
        save.coinsEarned += earned
        markDirty()
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

    func canHarvest(_ spec: NodeSpec) -> Bool {
        spec.tool == .hand || tier(spec.tool) >= spec.tier
    }

    func damage(against spec: NodeSpec) -> Double {
        let s = stats
        let base: Double
        switch spec.tool {
        case .hand: base = s.handMult
        case .rod: base = ToolTier.power(tier(.rod)) * s.handMult
        case .axe: base = ToolTier.power(tier(.axe)) * (1 + s.woodBonus)
        case .pickaxe: base = ToolTier.power(tier(.pickaxe)) * (1 + s.stoneBonus)
        }
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
        return Int((Double(price) * pow(1.8, Double(stars(id)))).rounded())
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
        addStar(id)
        return true
    }

    @discardableResult
    func tame(_ id: AnimalID) -> Bool {
        guard stars(id) < AnimalSpec.maxStars, let cost = tameCost(id), canAfford(cost) else { return false }
        pay(cost)
        addStar(id)
        gainXP(GameRules.tameXP(save.level))
        return true
    }

    private func addStar(_ id: AnimalID) {
        let isNew = stars(id) == 0
        save.animals[id] = min(AnimalSpec.maxStars, stars(id) + 1)
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

    // MARK: Для сцены

    func setEncounter(_ value: Encounter?) {
        if encounter != value { encounter = value }
    }

    func setBackpackFull(_ value: Bool) {
        if backpackFull != value { backpackFull = value }
    }

    func toast(_ icon: String, _ text: String) {
        let item = Toast(icon: icon, text: text)
        toasts.append(item)
        if toasts.count > 3 { toasts.removeFirst(toasts.count - 3) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) { [weak self] in
            self?.toasts.removeAll { $0.id == item.id }
        }
    }

    // MARK: Пока игры не было

    func applyOfflineProgress() {
        let elapsed = min(Date().timeIntervalSince(save.lastSeen), 6 * 3600)
        save.lastSeen = Date()
        guard elapsed > 90 else { return }
        var totals: [ResourceKind: Int] = [:]
        for producer in stats.producers {
            let n = Int(elapsed * stats.producerMult / producer.interval)
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
        s.handMult = 1 + 0.4 * r(.strongHands)
        s.hitInterval = 0.55 / (1 + 0.07 * r(.quickHands))
        s.critMult = 2 + 0.3 * r(.critPower)
        s.shatterChance = 0.04 * r(.shatter)
        s.quake = r(.quake) > 0
        s.yieldAll = 0.1 * r(.bounty)
        s.yieldCategory[.food] = 0.2 * r(.farmer)
        s.regrowChance = 0.06 * r(.gardener)
        s.doubleChance = 0.05 * r(.doubleDrop)
        s.gemChance = 0.015 * r(.gemFinder)
        s.goldenTouch = r(.goldenTouch) > 0
        s.reach = GameRules.baseReach * (1 + 0.12 * r(.reach))
        s.tameMult = 1 - 0.15 * r(.tamer)
        s.spawnMult = 1 + 0.25 * r(.tamer)
        s.helperMult = 1 + 0.25 * r(.packLeader)
        s.producerMult = 1 + 0.2 * r(.nightShift)
        s.discount = 1 - 0.07 * r(.thrift)
        s.autoDeposit = r(.portal) > 0
        s.animalMult = 1 + 0.12 * r(.beastBond)

        var speedBonus = 0.07 * r(.swift)
        var critBonus = 0.05 * r(.crit)
        var respawnBonus = 0.08 * r(.regrowth)
        var xpBonus = 0.1 * r(.scholar)
        var sellBonus = 0.08 * r(.trader)
        var capacity = Double(GameRules.capacity(at: save.level)) + 15 * r(.bigPack)

        for id in save.active {
            let m = AnimalSpec.starMultiplier(save.animals[id] ?? 1) * s.animalMult
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

        s.speed = GameRules.baseSpeed * (1 + speedBonus)
        s.critChance = min(0.75, critBonus)
        s.respawnMult = 1 / (1 + respawnBonus)
        s.xpMult = 1 + xpBonus
        s.sellMult = (1 + 0.01 * (lvl - 1)) * (1 + sellBonus)
        s.capacity = Int(capacity)
        stats = s
    }
}
