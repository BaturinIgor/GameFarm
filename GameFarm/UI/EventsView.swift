import SwiftUI

extension Countdown {
    /// Долгий отсчёт: дни и часы, меньше суток - часы, минуты и секунды.
    static func long(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        let d = s / 86_400
        if d > 0 { return tr("time.dayHour", d, (s % 86_400) / 3600) }
        return text(seconds)
    }

    /// Совсем короткий отсчёт для плашки: дни, часы или минуты.
    static func short(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        if s >= 86_400 { return tr("time.dayShort", s / 86_400) }
        if s >= 3600 { return tr("time.hour", s / 3600) }
        return tr("time.min", max(1, s / 60))
    }
}

/// Окно ивентов: текущий праздник, пропуск наград и анонсы следующих.
struct EventsView: View {
    @Environment(GameState.self) private var game
    let onTravel: () -> Void

    var body: some View {
        let run = Events.current
        ScrollView {
            VStack(spacing: 14) {
                EventBanner(run: run, onTravel: onTravel)
                if game.eventsOpen {
                    EventRunCard()
                    EventProgressCard()
                    if !game.hasVip { EventVipCard(event: run.event) }
                    EventTierList(event: run.event)
                } else {
                    Card {
                        Label(tr("event.locked", Events.minLevel), systemImage: "lock.fill")
                            .font(.game(14, .semibold))
                    }
                }
                SectionTitle(text: tr("event.upcoming"))
                ForEach(Events.upcoming()) { UpcomingEventCard(run: $0) }
                Text(tr("event.tip"))
                    .font(.game(11, .semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(16)
        }
        .sheetChrome(tr("event.title"), coins: game.save.coins)
        .onAppear {
            game.syncEvent()
            game.markEventSeen()
        }
    }
}

/// Баннер текущего ивента: название, таймер, карта и главные награды.
private struct EventBanner: View {
    @Environment(GameState.self) private var game
    let run: EventRun
    let onTravel: () -> Void

    var body: some View {
        let event = run.event
        let colors = event.colors
        let here = game.save.current == event.location
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        PixelIcon(name: event.icon, size: 30)
                        Text(event.name)
                            .gameTitle(21, outline: Palette.outline)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                    }
                    Text(event.blurb)
                        .font(.game(12, .bold))
                        .foregroundStyle(.white)
                        .outlined(Palette.outline.opacity(0.8), width: 1)
                        .fixedSize(horizontal: false, vertical: true)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Label(tr("event.left", Countdown.long(run.end.timeIntervalSince(context.date))), systemImage: "clock.fill")
                            .font(.game(12))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Palette.outline.opacity(0.45)))
                    }
                }
                Spacer(minLength: 0)
                Image(uiImage: MiniMap.image(event.location, framed: false))
                    .resizable()
                    .interpolation(.none)
                    .scaledToFill()
                    .frame(width: 86, height: 104)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.outline, lineWidth: 2.5))
            }
            HStack(spacing: 10) {
                PreviewTile(caption: tr("event.preview.node")) { PixelSprite(name: event.preview, scale: 2) }
                PreviewTile(caption: tr("event.preview.decor")) { PixelSprite(name: event.decor.sprite, scale: 2) }
                PreviewTile(caption: tr("event.preview.skin")) { SkinIcon(skin: event.skin, size: 46) }
            }
            if game.eventsOpen {
                if here {
                    Button {
                        game.leaveEvent()
                        onTravel()
                    } label: {
                        Label(tr("event.home"), systemImage: "house.fill")
                    }
                    .buttonStyle(.game(.wood, wide: true))
                } else {
                    Button {
                        game.goToEvent()
                        onTravel()
                    } label: {
                        Label(tr("event.go"), systemImage: "figure.walk")
                    }
                    .buttonStyle(.game(.green, wide: true))
                    .disabled(game.save.expedition != nil)
                }
            }
        }
        .padding(14)
        .background(shape.fill(LinearGradient(colors: [Color(hex: colors.0), Color(hex: colors.1)], startPoint: .top, endPoint: .bottom)))
        .overlay(shape.inset(by: 3).strokeBorder(Color.white.opacity(0.25), lineWidth: 1.5))
        .overlay(shape.strokeBorder(Palette.outline, lineWidth: 3))
        .background(shape.fill(Palette.outline.opacity(0.5)).offset(y: 4))
    }
}

private struct PreviewTile<Content: View>: View {
    let caption: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 3) {
            content
                .frame(height: 50)
            Text(caption)
                .font(.game(10))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.parchmentLight.opacity(0.92)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.outline.opacity(0.7), lineWidth: 2))
    }
}

/// Очки и ступень пропуска.
private struct EventProgressCard: View {
    @Environment(GameState.self) private var game

    var body: some View {
        let tier = game.eventTier
        let points = game.save.eventPoints
        let maxed = tier >= Events.tiers
        let from = maxed ? Events.total + ((points - Events.total) / Events.bonusEvery) * Events.bonusEvery : Events.threshold(tier: tier)
        let need = maxed ? Events.bonusEvery : Events.cost(tier: tier + 1)
        let have = points - from
        Card {
            HStack(spacing: 10) {
                PixelIcon(name: Events.current.event.icon, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("event.tier", tier, Events.tiers)).font(.game(16))
                    Text(tr("event.points", Fmt.n(points))).font(.game(12, .semibold)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if game.hasVip {
                    Text(tr("event.vip.active"))
                        .font(.game(12))
                        .foregroundStyle(.white)
                        .outlined(ButtonTone.gold.lip, width: 1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(LinearGradient(colors: [ButtonTone.gold.top, ButtonTone.gold.base],
                                                                  startPoint: .top, endPoint: .bottom)))
                        .overlay(Capsule().strokeBorder(Palette.outline, lineWidth: 2))
                }
            }
            GameBar(value: Double(have) / Double(max(1, need)), tone: maxed ? .purple : .orange, height: 18,
                    label: maxed ? tr("event.bonusProgress", have, need) : "\(have) / \(need)")
                .animation(.easeOut(duration: 0.3), value: points)
            if game.eventClaimable > 0 {
                Button {
                    withAnimation(.spring(duration: 0.35)) { game.claimAllEvent() }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: {
                    Text(tr("event.claimAll", game.eventClaimable))
                }
                .buttonStyle(.game(.green, wide: true))
            }
        }
    }
}

/// Предложение VIP-пропуска.
struct EventVipCard: View {
    let event: EventID

    var body: some View {
        ShopCard(title: ProductID.eventPass.title, tone: .gold) {
            HStack(spacing: 12) {
                SkinIcon(skin: event.skin, size: 52)
                    .frame(width: 60, height: 60)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.parchmentDeep.opacity(0.7)))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.outline.opacity(0.6), lineWidth: 2))
                Text(tr("event.vip.desc", event.skin.name))
                    .font(.game(12, .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            BuyButton(product: .eventPass, tone: .orange)
        }
    }
}

/// Ступени пропуска: бесплатная линия и VIP.
private struct EventTierList: View {
    @Environment(GameState.self) private var game
    let event: EventID

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Color.clear.frame(width: 34, height: 1)
                Text(tr("event.track.free")).font(.game(12)).foregroundStyle(Palette.inkSoft).frame(maxWidth: .infinity)
                Text(tr("event.track.vip")).font(.game(12)).foregroundStyle(ButtonTone.gold.lip).frame(maxWidth: .infinity)
            }
            LazyVStack(spacing: 8) {
                ForEach(1...Events.tiers, id: \.self) { tier in
                    HStack(spacing: 8) {
                        TierBadge(tier: tier, reached: tier <= game.eventTier)
                        RewardCell(reward: Events.free(tier: tier), event: event, tier: tier, vip: false)
                        RewardCell(reward: Events.vip(tier: tier), event: event, tier: tier, vip: true)
                    }
                }
            }
            BonusRow()
        }
    }
}

private struct TierBadge: View {
    let tier: Int
    let reached: Bool

    var body: some View {
        let tone: ButtonTone = reached ? .orange : .gray
        Text("\(tier)")
            .font(.game(14))
            .foregroundStyle(.white)
            .outlined(tone.lip, width: 1)
            .frame(width: 34, height: 34)
            .background(Circle().fill(LinearGradient(colors: [tone.top, tone.base], startPoint: .top, endPoint: .bottom)))
            .overlay(Circle().strokeBorder(Palette.outline, lineWidth: 2))
    }
}

private struct RewardCell: View {
    @Environment(GameState.self) private var game
    let reward: Events.Reward
    let event: EventID
    let tier: Int
    let vip: Bool

    var body: some View {
        let claimed = vip ? game.save.eventVip.contains(tier) : game.save.eventFree.contains(tier)
        let reached = tier <= game.eventTier
        let locked = vip && !game.hasVip
        let ready = game.canClaimEvent(tier, vip: vip)
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        Button {
            withAnimation(.spring(duration: 0.3)) { game.claimEvent(tier, vip: vip) }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } label: {
            EventRewardIcon(reward: reward, event: event)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .opacity(claimed ? 0.4 : (reached ? 1 : 0.6))
                .background(shape.fill(vip ? Color(hex: 0xFBE3A8) : Palette.parchmentLight))
                .overlay(shape.strokeBorder(ready ? ButtonTone.green.base : Palette.woodDark.opacity(0.45), lineWidth: ready ? 3 : 1.5))
                .overlay(alignment: .topTrailing) {
                    if claimed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Palette.good)
                            .background(Circle().fill(.white))
                            .offset(x: 4, y: -4)
                    } else if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Palette.inkSoft)
                            .padding(4)
                    }
                }
                .overlay(alignment: .bottom) {
                    if ready {
                        Text(tr("quests.claim"))
                            .font(.game(10))
                            .foregroundStyle(.white)
                            .outlined(ButtonTone.green.lip, width: 1)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(ButtonTone.green.base))
                            .overlay(Capsule().strokeBorder(Palette.outline, lineWidth: 1.5))
                            .offset(y: 8)
                    }
                }
        }
        .buttonStyle(.press)
        .disabled(!ready)
    }
}

/// Иконка награды пропуска.
struct EventRewardIcon: View {
    @Environment(GameState.self) private var game
    let reward: Events.Reward
    let event: EventID

    var body: some View {
        HStack(spacing: 5) {
            switch reward {
            case .coins(let n):
                CoinIcon(size: 26)
                amount(Fmt.n(game.eventRewardCoins(n)))
            case .tickets(let n):
                TicketIcon(size: 26)
                amount("x\(n)")
            case .seeds(let n):
                PixelIcon(name: event.crop.seedIcon, size: 28, fallback: "🌱")
                amount("x\(n)")
            case .dish(let n):
                PixelIcon(name: event.dish.icon, size: 28, fallback: event.dish.emoji)
                amount("x\(n)")
            case .cards(let n):
                PixelIcon(name: "cards", size: 26, fallback: "🃏")
                amount("x\(n)")
            case .sparks(let n):
                PixelIcon(name: "spark", size: 26, fallback: "✨")
                amount("x\(n)")
            case .maps(let n):
                PixelIcon(name: "tmap", size: 26)
                amount("x\(n)")
            case .decor:
                PixelSprite(name: event.decor.sprite, scale: 1.4)
                    .frame(height: 44)
            case .skin:
                SkinIcon(skin: event.skin, size: 44)
            }
        }
    }

    private func amount(_ text: String) -> some View {
        Text(text)
            .font(.game(13))
            .foregroundStyle(Palette.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

/// Бонусный сундук после последней ступени.
private struct BonusRow: View {
    @Environment(GameState.self) private var game

    var body: some View {
        let ready = game.eventBonusReady
        HStack(spacing: 10) {
            PixelIcon(name: "chest_gold", size: 34, fallback: "🎁")
            VStack(alignment: .leading, spacing: 2) {
                Text(tr("event.bonus.title")).font(.game(13))
                HStack(spacing: 4) {
                    Text(tr("event.bonus.desc", Events.bonusEvery)).font(.game(11, .semibold)).foregroundStyle(.secondary)
                    CoinIcon(size: 13)
                    Text(Fmt.n(Events.bonusCoins(level: game.save.level))).font(.game(11))
                }
            }
            Spacer(minLength: 4)
            if ready > 0 {
                Button {
                    withAnimation(.spring(duration: 0.3)) { game.claimEventBonus() }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: {
                    Text(tr("event.bonus.claim", ready))
                }
                .buttonStyle(.game(.green, small: true))
            }
        }
        .padding(10)
        .listBox(radius: 12)
    }
}

/// Анонс следующего ивента.
struct UpcomingEventCard: View {
    let run: EventRun

    var body: some View {
        let event = run.event
        Card(tint: Color(hex: event.colors.0).opacity(0.18)) {
            HStack(alignment: .top, spacing: 12) {
                Image(uiImage: MiniMap.image(event.location, framed: false))
                    .resizable()
                    .interpolation(.none)
                    .scaledToFill()
                    .frame(width: 62, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Palette.outline.opacity(0.7), lineWidth: 2))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) { PixelIcon(name: event.icon, size: 20); Text(event.name).font(.game(15)) }
                    Text(event.blurb)
                        .font(.game(11, .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        Label(tr("event.startsIn", Countdown.long(run.start.timeIntervalSince(context.date))), systemImage: "calendar")
                            .font(.game(11))
                            .foregroundStyle(Palette.inkSoft)
                    }
                }
                Spacer(minLength: 0)
                VStack(spacing: 4) {
                    PixelSprite(name: event.preview, scale: 1.4).frame(height: 36)
                    SkinIcon(skin: event.skin, size: 34)
                }
            }
        }
    }
}

/// Ивент на карте мира: быстрый переход.
struct EventMapCard: View {
    @Environment(GameState.self) private var game
    let onTravel: () -> Void
    let onOpen: () -> Void

    var body: some View {
        let run = Events.current
        let event = run.event
        ShopCard(title: tr("event.title"), tone: .orange) {
            HStack(spacing: 12) {
                PixelSprite(name: event.preview, scale: 1.6).frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(event.name).font(.game(14))
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        Text(tr("event.left", Countdown.long(run.end.timeIntervalSince(context.date))))
                            .font(.game(11, .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            if game.eventsOpen {
                HStack(spacing: 8) {
                    Button(action: onOpen) {
                        Text(tr("event.pass"))
                    }
                    .buttonStyle(.game(.wood, wide: true))
                    if game.save.current != event.location {
                        Button {
                            game.goToEvent()
                            onTravel()
                        } label: {
                            Text(tr("event.go"))
                        }
                        .buttonStyle(.game(.green, wide: true))
                        .disabled(game.save.expedition != nil)
                    }
                }
            } else {
                Label(tr("event.locked", Events.minLevel), systemImage: "lock.fill")
                    .font(.game(12, .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: Плашки поверх карты

/// Кнопка ивента в правом столбце интерфейса: таймер и отметка о наградах.
struct EventHUDPill: View {
    @Environment(GameState.self) private var game
    let action: () -> Void

    var body: some View {
        if game.eventsOpen {
            let run = Events.current
            Button(action: action) {
                HStack(spacing: 5) {
                    PixelIcon(name: run.event.icon, size: 18)
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        Text(Countdown.short(run.end.timeIntervalSince(context.date)))
                            .font(.game(12))
                            .foregroundStyle(.white)
                            .outlined(Palette.outline, width: 1)
                            .monospacedDigit()
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .woodPill(radius: 13, tint: Color(hex: run.event.colors.1))
                .overlay(alignment: .topTrailing) {
                    if game.eventClaimable > 0 {
                        CountBadge(count: game.eventClaimable).offset(x: 8, y: -8)
                    } else if game.eventIsNew {
                        Text("!")
                            .font(.game(11))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(ButtonTone.red.base))
                            .overlay(Circle().strokeBorder(Palette.outline, lineWidth: 1.5))
                            .offset(x: 8, y: -8)
                    }
                }
            }
            .buttonStyle(.press)
        }
    }
}

/// На карте ивента: этап, цель этапа, усиления и дорога домой.
struct EventMapPill: View {
    @Environment(GameState.self) private var game
    let onOpen: () -> Void

    var body: some View {
        if game.inEvent {
            let progress = game.save.eventProgress
            let goal = game.eventGoal
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 8) {
                    Button(action: onOpen) {
                        HStack(spacing: 6) {
                            PixelIcon(name: Events.current.event.icon, size: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tr("event.stage", game.save.eventStage) + (game.eventBossStage ? " · " + tr("event.bossStage") : ""))
                                    .font(.game(11))
                                    .foregroundStyle(.white)
                                    .outlined(Palette.outline, width: 1)
                                GameBar(value: Double(min(progress, goal)) / Double(max(1, goal)),
                                        tone: game.eventStageCleared ? .green : (game.eventBossDue ? .red : .orange), height: 12,
                                        label: game.eventStageCleared ? tr("event.portalOpen")
                                            : (game.eventBossDue ? tr("event.bossDue") : "\(progress)/\(game.eventTarget)"))
                                    .frame(width: 110)
                                    .animation(.easeOut(duration: 0.3), value: progress)
                            }
                        }
                    }
                    .buttonStyle(.press)
                    Button {
                        game.leaveEvent()
                    } label: {
                        Text(tr("event.home"))
                    }
                    .buttonStyle(.game(.wood, small: true))
                }
                .padding(.leading, 10)
                .padding(.trailing, 6)
                .padding(.vertical, 5)
                .woodPill(radius: 16)
                BoonStrip()
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

/// Значки взятых усилений с рангом.
struct BoonStrip: View {
    @Environment(GameState.self) private var game

    var body: some View {
        let taken = EventBoon.allCases.filter { game.boonRank($0) > 0 }
        if !taken.isEmpty {
            HStack(spacing: 3) {
                ForEach(taken) { boon in
                    ZStack(alignment: .bottomTrailing) {
                        PixelIcon(name: boon.icon, size: 18)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(Palette.parchmentLight))
                            .overlay(Circle().strokeBorder(Palette.outline, lineWidth: 1.5))
                        Text("\(game.boonRank(boon))")
                            .font(.game(9))
                            .foregroundStyle(.white)
                            .outlined(Palette.outline, width: 1)
                            .offset(x: 3, y: 3)
                    }
                }
            }
        }
    }
}

/// После этапа: выбор одного из трёх усилений до конца ивента.
struct EventBoonPicker: View {
    @Environment(GameState.self) private var game

    var body: some View {
        ZStack {
            Palette.dim.ignoresSafeArea()
            VStack(spacing: 12) {
                Text(tr("boon.subtitle"))
                    .font(.game(13, .semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 22)
                ForEach(game.save.eventChoice) { boon in
                    let rank = game.boonRank(boon)
                    Button {
                        withAnimation(.spring(duration: 0.3)) { game.chooseBoon(boon) }
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } label: {
                        HStack(spacing: 12) {
                            PixelIcon(name: boon.icon, size: 34)
                                .frame(width: 50, height: 50)
                                .background(Circle().fill(Color(hex: 0xFFF3D0)))
                                .overlay(Circle().strokeBorder(Palette.outline, lineWidth: 2))
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(boon.name).font(.game(15))
                                    Text(tr("boon.rank", rank + 1, EventBoon.maxRank))
                                        .font(.game(11))
                                        .foregroundStyle(Palette.inkSoft)
                                }
                                Text(boon.text(rank: rank + 1))
                                    .font(.game(12, .semibold))
                                    .foregroundStyle(Palette.ink)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.parchmentLight))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.goldDark, lineWidth: 2))
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.woodDark.opacity(0.3)).offset(y: 3))
                    }
                    .buttonStyle(.press)
                }
            }
            .foregroundStyle(Palette.ink)
            .padding(16)
            .frame(maxWidth: 380)
            .gamePanel()
            .overlay(alignment: .top) {
                RibbonTitle(text: tr("boon.title", game.save.eventStage), tone: .gold, size: 18)
                    .padding(.horizontal, 24)
                    .offset(y: -18)
            }
            .padding(20)
            .popIn()
        }
    }
}

/// Забег по этапам в окне ивента: где ты сейчас, рекорд и взятые усиления.
struct EventRunCard: View {
    @Environment(GameState.self) private var game

    var body: some View {
        Card(tint: ButtonTone.orange.base) {
            HStack(spacing: 12) {
                PixelIcon(name: "portal", size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("event.stage", game.save.eventStage)).font(.game(16))
                    Text(tr("event.best", game.save.eventBest))
                        .font(.game(12, .semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            Text(tr("event.runHint"))
                .font(.game(12, .semibold))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            let taken = EventBoon.allCases.filter { game.boonRank($0) > 0 }
            if !taken.isEmpty {
                PaperDivider()
                ForEach(taken) { boon in
                    HStack(spacing: 8) {
                        PixelIcon(name: boon.icon, size: 22).frame(width: 26)
                        Text(boon.name + " " + tr("boon.rank", game.boonRank(boon), EventBoon.maxRank)).font(.game(13))
                        Spacer(minLength: 4)
                        Text(boon.text(rank: game.boonRank(boon)))
                            .font(.game(11, .semibold))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
        }
    }
}
