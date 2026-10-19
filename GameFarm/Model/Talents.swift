import SwiftUI

enum TalentBranch: String, CaseIterable, Identifiable {
    case mining, gathering, travel, beasts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mining: "Добыча"
        case .gathering: "Сбор"
        case .travel: "Странник"
        case .beasts: "Звери"
        }
    }

    var emoji: String {
        switch self {
        case .mining: "⚒️"
        case .gathering: "🧺"
        case .travel: "🧭"
        case .beasts: "🐾"
        }
    }

    var color: Color {
        switch self {
        case .mining: Color(red: 0.95, green: 0.45, blue: 0.25)
        case .gathering: Color(red: 0.3, green: 0.75, blue: 0.35)
        case .travel: Color(red: 0.3, green: 0.6, blue: 1.0)
        case .beasts: Color(red: 0.9, green: 0.4, blue: 0.75)
        }
    }

    var talents: [TalentID] { TalentID.allCases.filter { $0.spec.branch == self } }
}

enum TalentID: String, CaseIterable, Identifiable {
    case power, lumberjack, miner, quickHands, crit, shatter, critPower, strongHands, quake
    case bounty, regrowth, scholar, doubleDrop, farmer, trader, gardener, gemFinder, goldenTouch
    case swift, bigPack, reach, tamer, beastBond, packLeader, thrift, nightShift, portal
    case doubleStrike, shockwave, oreHunter, execute, crusher, tireless, toolMaster
    case finder, goldRush, jeweler, fertile, triple, sage, abundance
    case packMaster, tailwind, depotReach, bargain, tracker, storekeeper, strider
    case animalFriend, training, rancher, keenEye, packTier, pasture, starFood
    case beastLoot, catcher, alpha, herdsman, starHunter, soul

    var id: String { rawValue }
    var spec: TalentSpec { TalentSpec.table[self]! }
}

struct TalentSpec {
    enum Unit { case percent, flat, flag }

    let id: TalentID
    let branch: TalentBranch
    let name: String
    let emoji: String
    let maxRank: Int
    let tier: Int
    let column: Int
    let parents: [TalentID]
    let perRank: Double
    let unit: Unit
    /// Текст эффекта, {v} заменяется на значение.
    let text: String

    /// Уровень персонажа, с которого открывается ряд дерева.
    static let tierLevels = [1, 3, 6, 10, 15, 22, 30, 40, 50]

    var requiredLevel: Int { Self.tierLevels[tier] }

    func effect(at rank: Int) -> String {
        let value = perRank * Double(rank)
        switch unit {
        case .flag:
            return text
        case .percent:
            return text.replacingOccurrences(of: "{v}", with: Fmt.pct(value))
        case .flat:
            return text.replacingOccurrences(of: "{v}", with: "\(Int(value))")
        }
    }

    static let table: [TalentID: TalentSpec] = {
        let list: [TalentSpec] = [
            // Добыча
            TalentSpec(id: .power, branch: .mining, name: "Сильный удар", emoji: "💪", maxRank: 5, tier: 0, column: 1,
                       parents: [], perRank: 0.12, unit: .percent, text: "+{v} к урону всеми инструментами"),
            TalentSpec(id: .lumberjack, branch: .mining, name: "Дровосек", emoji: "🪓", maxRank: 3, tier: 1, column: 0,
                       parents: [.power], perRank: 0.2, unit: .percent, text: "+{v} к урону по деревьям, бамбуку и кактусам"),
            TalentSpec(id: .miner, branch: .mining, name: "Шахтёр", emoji: "⛏️", maxRank: 3, tier: 1, column: 2,
                       parents: [.power], perRank: 0.2, unit: .percent, text: "+{v} к урону по камням, льду и рудам"),
            TalentSpec(id: .quickHands, branch: .mining, name: "Быстрые руки", emoji: "⚡", maxRank: 5, tier: 2, column: 1,
                       parents: [.power], perRank: 0.07, unit: .percent, text: "Удары чаще на {v}"),
            TalentSpec(id: .crit, branch: .mining, name: "Меткость", emoji: "🎯", maxRank: 4, tier: 3, column: 0,
                       parents: [.lumberjack], perRank: 0.05, unit: .percent, text: "{v} шанс критического удара (x2 урона)"),
            TalentSpec(id: .shatter, branch: .mining, name: "Раскол", emoji: "💥", maxRank: 3, tier: 3, column: 2,
                       parents: [.miner], perRank: 0.04, unit: .percent, text: "{v} шанс добыть ресурс с одного удара"),
            TalentSpec(id: .critPower, branch: .mining, name: "Мощный крит", emoji: "🔥", maxRank: 3, tier: 4, column: 0,
                       parents: [.crit], perRank: 0.3, unit: .percent, text: "Критический удар сильнее на {v}"),
            TalentSpec(id: .strongHands, branch: .mining, name: "Крепкие руки", emoji: "✊", maxRank: 3, tier: 4, column: 2,
                       parents: [.shatter], perRank: 0.4, unit: .percent, text: "+{v} к сбору руками и рыбалке"),
            TalentSpec(id: .quake, branch: .mining, name: "Сотрясение", emoji: "🌋", maxRank: 1, tier: 5, column: 1,
                       parents: [.quickHands], perRank: 1, unit: .flag, text: "Каждый удар задевает соседние ресурсы (40% урона)"),
            // Сбор
            TalentSpec(id: .bounty, branch: .gathering, name: "Щедрость", emoji: "🧺", maxRank: 5, tier: 0, column: 1,
                       parents: [], perRank: 0.1, unit: .percent, text: "+{v} ресурсов с каждой добычи"),
            TalentSpec(id: .regrowth, branch: .gathering, name: "Быстрый рост", emoji: "🌱", maxRank: 5, tier: 1, column: 0,
                       parents: [.bounty], perRank: 0.08, unit: .percent, text: "Ресурсы восстанавливаются быстрее на {v}"),
            TalentSpec(id: .scholar, branch: .gathering, name: "Учёный", emoji: "📚", maxRank: 5, tier: 1, column: 2,
                       parents: [.bounty], perRank: 0.1, unit: .percent, text: "+{v} опыта"),
            TalentSpec(id: .doubleDrop, branch: .gathering, name: "Двойная добыча", emoji: "🎲", maxRank: 4, tier: 2, column: 1,
                       parents: [.bounty], perRank: 0.05, unit: .percent, text: "{v} шанс получить ресурсы вдвойне"),
            TalentSpec(id: .farmer, branch: .gathering, name: "Фермер", emoji: "🌾", maxRank: 3, tier: 3, column: 0,
                       parents: [.regrowth], perRank: 0.2, unit: .percent, text: "+{v} еды с каждой добычи"),
            TalentSpec(id: .trader, branch: .gathering, name: "Торговец", emoji: "💰", maxRank: 5, tier: 3, column: 2,
                       parents: [.scholar], perRank: 0.08, unit: .percent, text: "+{v} к цене продажи"),
            TalentSpec(id: .gardener, branch: .gathering, name: "Садовник", emoji: "🪴", maxRank: 3, tier: 4, column: 0,
                       parents: [.farmer], perRank: 0.06, unit: .percent, text: "{v} шанс, что ресурс сразу вырастет снова"),
            TalentSpec(id: .gemFinder, branch: .gathering, name: "Кладоискатель", emoji: "💎", maxRank: 3, tier: 4, column: 2,
                       parents: [.trader], perRank: 0.015, unit: .percent, text: "{v} шанс найти алмаз при добыче камня и руды"),
            TalentSpec(id: .goldenTouch, branch: .gathering, name: "Золотое касание", emoji: "👑", maxRank: 1, tier: 5, column: 1,
                       parents: [.doubleDrop], perRank: 1, unit: .flag, text: "Каждая добыча приносит монеты"),
            // Странник
            TalentSpec(id: .swift, branch: .travel, name: "Быстрые ноги", emoji: "👟", maxRank: 5, tier: 0, column: 1,
                       parents: [], perRank: 0.07, unit: .percent, text: "+{v} к скорости бега"),
            TalentSpec(id: .bigPack, branch: .travel, name: "Большой рюкзак", emoji: "🎒", maxRank: 5, tier: 1, column: 0,
                       parents: [.swift], perRank: 15, unit: .flat, text: "+{v} мест в рюкзаке"),
            TalentSpec(id: .reach, branch: .travel, name: "Длинные руки", emoji: "🤲", maxRank: 3, tier: 1, column: 2,
                       parents: [.swift], perRank: 0.12, unit: .percent, text: "+{v} к радиусу добычи"),
            TalentSpec(id: .tamer, branch: .travel, name: "Укротитель", emoji: "🪢", maxRank: 3, tier: 2, column: 1,
                       parents: [.swift], perRank: 0.15, unit: .percent, text: "Приручение дешевле на {v}, дикие звери появляются чаще"),
            TalentSpec(id: .beastBond, branch: .travel, name: "Любимец", emoji: "❤️", maxRank: 4, tier: 3, column: 0,
                       parents: [.bigPack], perRank: 0.12, unit: .percent, text: "Бонусы животных сильнее на {v}"),
            TalentSpec(id: .packLeader, branch: .travel, name: "Вожак", emoji: "🐺", maxRank: 4, tier: 3, column: 2,
                       parents: [.reach], perRank: 0.25, unit: .percent, text: "Звери-помощники добывают сильнее на {v}"),
            TalentSpec(id: .thrift, branch: .travel, name: "Бережливость", emoji: "🏷️", maxRank: 3, tier: 4, column: 0,
                       parents: [.beastBond], perRank: 0.07, unit: .percent, text: "Улучшения и локации дешевле на {v}"),
            TalentSpec(id: .nightShift, branch: .travel, name: "Ночная смена", emoji: "🌙", maxRank: 3, tier: 4, column: 2,
                       parents: [.packLeader], perRank: 0.2, unit: .percent, text: "Звери-производители работают быстрее на {v}"),
            TalentSpec(id: .portal, branch: .travel, name: "Портал", emoji: "🌀", maxRank: 1, tier: 5, column: 1,
                       parents: [.tamer], perRank: 1, unit: .flag, text: "Полный рюкзак сам отправляется на склад"),
            // Добыча, поздние ряды
            TalentSpec(id: .doubleStrike, branch: .mining, name: "Двойной удар", emoji: "⚔️", maxRank: 4, tier: 6, column: 0,
                       parents: [.critPower], perRank: 0.05, unit: .percent, text: "{v} шанс ударить дважды"),
            TalentSpec(id: .shockwave, branch: .mining, name: "Ударная волна", emoji: "🌊", maxRank: 3, tier: 6, column: 1,
                       parents: [.quake], perRank: 0.25, unit: .percent, text: "Сотрясение сильнее и шире на {v}"),
            TalentSpec(id: .oreHunter, branch: .mining, name: "Рудознатец", emoji: "🪙", maxRank: 4, tier: 6, column: 2,
                       parents: [.strongHands], perRank: 0.1, unit: .percent, text: "+{v} руды и самоцветов с добычи"),
            TalentSpec(id: .execute, branch: .mining, name: "Добивание", emoji: "🗡️", maxRank: 3, tier: 7, column: 0,
                       parents: [.doubleStrike], perRank: 0.06, unit: .percent, text: "Ресурс ломается сразу, если прочности осталось меньше {v}"),
            TalentSpec(id: .crusher, branch: .mining, name: "Сокрушитель", emoji: "🔨", maxRank: 3, tier: 7, column: 1,
                       parents: [.shockwave], perRank: 0.15, unit: .percent, text: "+{v} к урону по ресурсам 5-й ступени и выше"),
            TalentSpec(id: .tireless, branch: .mining, name: "Неутомимость", emoji: "🔋", maxRank: 4, tier: 7, column: 2,
                       parents: [.oreHunter], perRank: 0.05, unit: .percent, text: "Удары ещё чаще на {v}"),
            TalentSpec(id: .toolMaster, branch: .mining, name: "Мастер инструмента", emoji: "🏆", maxRank: 1, tier: 8, column: 1,
                       parents: [.crusher], perRank: 1, unit: .flag, text: "Все инструменты работают как на ступень выше"),
            // Сбор, поздние ряды
            TalentSpec(id: .finder, branch: .gathering, name: "Находка", emoji: "🔍", maxRank: 4, tier: 6, column: 0,
                       parents: [.gardener], perRank: 0.04, unit: .percent, text: "{v} шанс найти ещё один случайный ресурс локации"),
            TalentSpec(id: .goldRush, branch: .gathering, name: "Золотая лихорадка", emoji: "🤑", maxRank: 3, tier: 6, column: 1,
                       parents: [.goldenTouch], perRank: 0.5, unit: .percent, text: "Монет с каждой добычи больше на {v}"),
            TalentSpec(id: .jeweler, branch: .gathering, name: "Ювелир", emoji: "💍", maxRank: 3, tier: 6, column: 2,
                       parents: [.gemFinder], perRank: 0.15, unit: .percent, text: "Руда, самоцветы и диковинки продаются дороже на {v}"),
            TalentSpec(id: .fertile, branch: .gathering, name: "Плодородие", emoji: "🌻", maxRank: 5, tier: 7, column: 0,
                       parents: [.finder], perRank: 0.06, unit: .percent, text: "+{v} ресурсов с каждой добычи"),
            TalentSpec(id: .triple, branch: .gathering, name: "Тройная добыча", emoji: "🎰", maxRank: 3, tier: 7, column: 1,
                       parents: [.goldRush], perRank: 0.03, unit: .percent, text: "{v} шанс получить ресурсы втройне"),
            TalentSpec(id: .sage, branch: .gathering, name: "Мудрец", emoji: "🦉", maxRank: 5, tier: 7, column: 2,
                       parents: [.jeweler], perRank: 0.06, unit: .percent, text: "+{v} опыта"),
            TalentSpec(id: .abundance, branch: .gathering, name: "Изобилие", emoji: "🌈", maxRank: 1, tier: 8, column: 1,
                       parents: [.triple], perRank: 1, unit: .flag, text: "Ресурсы растут на 50% быстрее и дают +10% добычи"),
            // Странник, поздние ряды
            TalentSpec(id: .packMaster, branch: .travel, name: "Вьючный мастер", emoji: "🧳", maxRank: 4, tier: 6, column: 0,
                       parents: [.thrift], perRank: 0.1, unit: .percent, text: "Рюкзак больше на {v}"),
            TalentSpec(id: .tailwind, branch: .travel, name: "Попутный ветер", emoji: "🍃", maxRank: 4, tier: 6, column: 1,
                       parents: [.portal], perRank: 0.05, unit: .percent, text: "+{v} к скорости бега"),
            TalentSpec(id: .depotReach, branch: .travel, name: "Грузчик", emoji: "📦", maxRank: 3, tier: 6, column: 2,
                       parents: [.nightShift], perRank: 0.3, unit: .percent, text: "Склад принимает ресурсы с расстояния больше на {v}"),
            TalentSpec(id: .bargain, branch: .travel, name: "Торг", emoji: "🤝", maxRank: 3, tier: 7, column: 0,
                       parents: [.packMaster], perRank: 0.08, unit: .percent, text: "Звери в лавке дешевле на {v}"),
            TalentSpec(id: .tracker, branch: .travel, name: "Следопыт", emoji: "🧭", maxRank: 3, tier: 7, column: 1,
                       parents: [.tailwind], perRank: 0.2, unit: .percent, text: "Дикие звери и клады появляются чаще на {v}"),
            TalentSpec(id: .storekeeper, branch: .travel, name: "Кладовщик", emoji: "📋", maxRank: 3, tier: 7, column: 2,
                       parents: [.depotReach], perRank: 1, unit: .flat, text: "+{v} опыта за каждые 10 ресурсов, сданных на склад"),
            TalentSpec(id: .strider, branch: .travel, name: "Скороход", emoji: "🚀", maxRank: 1, tier: 8, column: 1,
                       parents: [.tracker], perRank: 1, unit: .flag, text: "+25% к скорости и размеру рюкзака"),
            // Звери
            TalentSpec(id: .animalFriend, branch: .beasts, name: "Друг зверей", emoji: "🤗", maxRank: 5, tier: 0, column: 1,
                       parents: [], perRank: 0.05, unit: .percent, text: "Бонусы зверей сильнее на {v}"),
            TalentSpec(id: .training, branch: .beasts, name: "Дрессировка", emoji: "🎾", maxRank: 5, tier: 1, column: 0,
                       parents: [.animalFriend], perRank: 0.08, unit: .percent, text: "Помощники бьют чаще на {v}"),
            TalentSpec(id: .rancher, branch: .beasts, name: "Хозяин фермы", emoji: "🧑‍🌾", maxRank: 5, tier: 1, column: 2,
                       parents: [.animalFriend], perRank: 0.08, unit: .percent, text: "{v} шанс, что зверь принесёт двойной продукт"),
            TalentSpec(id: .keenEye, branch: .beasts, name: "Зоркий глаз", emoji: "👀", maxRank: 3, tier: 2, column: 1,
                       parents: [.animalFriend], perRank: 0.2, unit: .percent, text: "Помощники ищут ресурсы дальше на {v}"),
            TalentSpec(id: .packTier, branch: .beasts, name: "Опытная стая", emoji: "🐺", maxRank: 2, tier: 3, column: 0,
                       parents: [.training], perRank: 1, unit: .flat, text: "Помощники добывают ресурсы на {v} ступ. выше"),
            TalentSpec(id: .pasture, branch: .beasts, name: "Пастбище", emoji: "🏡", maxRank: 3, tier: 3, column: 2,
                       parents: [.rancher], perRank: 2, unit: .flat, text: "+{v} ч к работе зверей, пока игра закрыта"),
            TalentSpec(id: .starFood, branch: .beasts, name: "Звёздный корм", emoji: "⭐", maxRank: 4, tier: 4, column: 1,
                       parents: [.keenEye], perRank: 0.05, unit: .percent, text: "Каждая звезда усиливает зверя ещё на {v}"),
            TalentSpec(id: .beastLoot, branch: .beasts, name: "Добытчики", emoji: "🦴", maxRank: 4, tier: 5, column: 0,
                       parents: [.packTier], perRank: 0.15, unit: .percent, text: "+{v} ресурсов от помощников"),
            TalentSpec(id: .catcher, branch: .beasts, name: "Ловец", emoji: "🪤", maxRank: 3, tier: 5, column: 2,
                       parents: [.pasture], perRank: 0.1, unit: .percent, text: "Приручение дешевле на {v}"),
            TalentSpec(id: .alpha, branch: .beasts, name: "Альфа", emoji: "🦁", maxRank: 5, tier: 6, column: 1,
                       parents: [.starFood], perRank: 0.1, unit: .percent, text: "Помощники бьют сильнее на {v}"),
            TalentSpec(id: .herdsman, branch: .beasts, name: "Пастух", emoji: "🐑", maxRank: 3, tier: 7, column: 0,
                       parents: [.beastLoot], perRank: 0.1, unit: .percent, text: "Производители работают быстрее на {v}"),
            TalentSpec(id: .starHunter, branch: .beasts, name: "Охотник за звёздами", emoji: "🌠", maxRank: 3, tier: 7, column: 2,
                       parents: [.catcher], perRank: 0.15, unit: .percent, text: "{v} шанс получить 2 звезды за приручение"),
            TalentSpec(id: .soul, branch: .beasts, name: "Душа стаи", emoji: "💞", maxRank: 1, tier: 8, column: 1,
                       parents: [.alpha], perRank: 1, unit: .flag, text: "Все бонусы зверей сильнее на 30%")
        ]
        var dict: [TalentID: TalentSpec] = [:]
        for spec in list { dict[spec.id] = spec }
        return dict
    }()
}
