import SwiftUI

/// Лавка у дома: семена и обмены дня.
struct TraderView: View {
    enum Tab: Hashable { case seeds, deals }

    @Environment(GameState.self) private var game
    @State private var tab: Tab = .seeds

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    NPCPortrait(name: "merchant")
                    Text(tr("trader.hello"))
                        .font(.game(13, .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listBox(radius: 12)
                }
                GameTabs(selection: $tab, items: [(.seeds, tr("trader.tab.seeds")), (.deals, tr("trader.tab.deals"))])
                switch tab {
                case .seeds:
                    ForEach(CropID.allCases) { SeedRow(crop: $0) }
                case .deals:
                    dealsList
                }
            }
            .padding(16)
        }
        .sheetChrome(tr("trader.title"), coins: game.save.coins)
    }

    private var dealsList: some View {
        VStack(spacing: 12) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Label(tr("trader.deals.refresh", Countdown.text(game.nextDealsAt.timeIntervalSince(context.date))), systemImage: "clock")
                    .font(.game(12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(game.dailyDeals) { DealRow(deal: $0) }
        }
    }
}

/// Портрет торговца из листа персонажа.
struct NPCPortrait: View {
    let name: String
    var size: CGFloat = 56

    var body: some View {
        Group {
            if let image = Sprites.crisp("pl_\(name)", crop: CGRect(x: 20, y: 14, width: 24, height: 26), scale: 4) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .padding(6)
            } else {
                Text("🧑‍🌾").font(.system(size: size * 0.6))
            }
        }
        .frame(width: size, height: size)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.parchmentDeep))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.outline, lineWidth: 2))
    }
}

/// Семена одной культуры: сколько растёт, сколько даёт, цена.
struct SeedRow: View {
    @Environment(GameState.self) private var game
    let crop: CropID

    var body: some View {
        let spec = crop.spec
        let unlocked = game.save.level >= spec.level
        Card {
            HStack(spacing: 12) {
                PixelIcon(name: crop.seedIcon, size: 34, fallback: "🌱")
                    .frame(width: 50, height: 50)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.parchmentDeep.opacity(0.7)))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.woodDark.opacity(0.4), lineWidth: 1.5))
                    .opacity(unlocked ? 1 : 0.5)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(crop.name).font(.game(15))
                        if game.seeds(crop) > 0 {
                            Text("x\(game.seeds(crop))")
                                .font(.game(11))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color(hex: 0xDDEFC8)))
                                .overlay(Capsule().strokeBorder(Palette.good.opacity(0.5), lineWidth: 1))
                        }
                    }
                    HStack(spacing: 8) {
                        Label(Fmt.seconds(spec.growTime), systemImage: "clock")
                        HStack(spacing: 2) {
                            ResourceIcon(kind: spec.produce, size: 14)
                            Text("x\(spec.yield)")
                        }
                    }
                    .font(.game(11, .bold))
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                if unlocked {
                    VStack(spacing: 4) {
                        buy(1)
                        buy(5)
                    }
                } else {
                    LevelTag(level: spec.level, ok: false)
                }
            }
        }
    }

    private func buy(_ count: Int) -> some View {
        let cost = game.seedCost(crop, count: count)
        return Button {
            withAnimation(.snappy) {
                if game.buySeeds(crop, count: count) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text("+\(count)")
                CoinIcon(size: 14)
                Text(Fmt.n(cost)).monospacedDigit()
            }
        }
        .buttonStyle(.game(.green, small: true))
        .disabled(game.save.coins < cost)
    }
}

/// Обмен дня: отдать ресурсы (и монеты) и получить награду.
struct DealRow: View {
    @Environment(GameState.self) private var game
    let deal: TradeDeal

    var body: some View {
        let bought = game.dealBought(deal)
        Card(tint: bought ? .clear : ButtonTone.orange.base.opacity(0.6)) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(tr("trader.give")).font(.game(11)).foregroundStyle(.secondary)
                    CostView(cost: Cost(coins: deal.coinsPrice, items: deal.give))
                }
                Image(systemName: "arrow.right")
                    .font(.game(16))
                    .foregroundStyle(Palette.woodDark)
                VStack(alignment: .leading, spacing: 6) {
                    Text(tr("trader.get")).font(.game(11)).foregroundStyle(.secondary)
                    RewardView(reward: deal.reward)
                }
                Spacer(minLength: 0)
            }
            if bought {
                Label(tr("trader.bought"), systemImage: "checkmark.seal.fill")
                    .font(.game(13))
                    .foregroundStyle(Palette.good)
            } else {
                Button {
                    withAnimation(.snappy) {
                        if game.trade(deal) {
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    }
                } label: {
                    Text(tr("trader.trade"))
                }
                .buttonStyle(.game(.orange, small: true, wide: true))
                .disabled(!game.canTrade(deal))
            }
        }
    }
}

struct RewardView: View {
    let reward: TradeDeal.Reward

    var body: some View {
        switch reward {
        case .coins(let n):
            RewardChip(text: Fmt.n(n)) { CoinIcon(size: 18) }
        case .ticket:
            RewardChip(text: "1") { TicketIcon(size: 18) }
        case .seeds(let crop, let n):
            RewardChip(text: "\(n)") { PixelIcon(name: crop.seedIcon, size: 18, fallback: "🌱") }
        }
    }
}

/// Бродячий торговец: три редких товара, пока он не ушёл.
struct WandererView: View {
    @Environment(GameState.self) private var game

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    NPCPortrait(name: "wanderer")
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tr("wanderer.hello"))
                            .font(.game(13, .semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        if let visit = game.wanderer {
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                Label(tr("wanderer.leaves", Countdown.text(visit.until.timeIntervalSince(context.date))), systemImage: "clock")
                                    .font(.game(12))
                                    .foregroundStyle(ButtonTone.purple.lip)
                            }
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listBox(radius: 12)
                }
                if let visit = game.wanderer {
                    ForEach(visit.offers) { WandererRow(offer: $0) }
                } else {
                    Card {
                        Text(tr("wanderer.gone")).font(.game(14, .semibold))
                    }
                }
            }
            .padding(16)
        }
        .sheetChrome(tr("wanderer.title"), coins: game.save.coins)
    }
}

struct WandererRow: View {
    @Environment(GameState.self) private var game
    let offer: WandererOffer

    var body: some View {
        let bought = game.wanderer?.bought.contains(offer.id) ?? true
        Card(tint: bought ? .clear : ButtonTone.purple.base.opacity(0.6)) {
            HStack(spacing: 12) {
                icon
                    .frame(width: 50, height: 50)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(hex: 0xEDE2FA)))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.outline.opacity(0.6), lineWidth: 2))
                Text(title).font(.game(15))
                Spacer(minLength: 4)
                if bought {
                    Image(systemName: "checkmark.seal.fill").font(.game(20)).foregroundStyle(Palette.good)
                } else {
                    Button {
                        withAnimation(.snappy) {
                            if game.buyWanderer(offer) {
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            CoinIcon(size: 15)
                            Text(Fmt.n(offer.price)).monospacedDigit()
                        }
                    }
                    .buttonStyle(.game(.purple, small: true))
                    .disabled(game.save.coins < offer.price)
                }
            }
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch offer.goods {
        case .ticket: TicketIcon(size: 30)
        case .seeds(let crop, _): PixelIcon(name: crop.seedIcon, size: 30, fallback: "🌱")
        case .resource(let kind, _): ResourceIcon(kind: kind, size: 30)
        }
    }

    private var title: String {
        switch offer.goods {
        case .ticket: return tr("wanderer.ticket")
        case .seeds(let crop, let n): return "\(crop.name) x\(n)"
        case .resource(let kind, let n): return "\(kind.name) x\(n)"
        }
    }
}
