import SwiftUI

struct ShopView: View {
    @Environment(GameState.self) private var game
    @Environment(Store.self) private var store

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if Store.testMode {
                    Label(tr("shop.testMode"), systemImage: "testtube.2")
                        .font(.game(12))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if game.starterAvailable || game.owns(.starter) {
                    StarterCard()
                }
                ProCard()
                if game.eventsOpen && !game.hasVip { EventVipCard(event: Events.current.event) }
                GardenCard()
                TicketsCard()
                SkinsCard()
                FreeCard()
                Button {
                    Task { await store.restore() }
                } label: {
                    Label(tr("shop.restore"), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.game(.wood, small: true, wide: true))
                Text(tr("shop.footer"))
                    .font(.game(11, .semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(16)
        }
        .sheetChrome(tr("shop.title"), coins: game.save.coins)
        .onChange(of: store.errorMessage) { _, message in
            guard let message else { return }
            Dialogs.shared.info(tr("shop.error"), message: message)
            store.errorMessage = nil
        }
    }
}

/// Карточка товара: цветная рамка и лента с названием.
struct ShopCard<Content: View>: View {
    let title: String
    var tone: ButtonTone = .orange
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(.horizontal, 16)
        .padding(.top, 26)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .gamePanel(fill: Palette.parchmentLight, frame: tone.base, radius: 18, border: 4)
        .overlay(alignment: .top) {
            RibbonTitle(text: title, tone: tone, size: 17)
                .padding(.horizontal, 30)
                .offset(y: -15)
        }
        .padding(.top, 14)
    }
}

/// Кнопка покупки с ценой и индикатором ожидания.
struct BuyButton: View {
    @Environment(GameState.self) private var game
    @Environment(Store.self) private var store
    let product: ProductID
    var tone: ButtonTone = .orange

    var body: some View {
        let owned = game.owns(product)
        Button {
            Task { await store.buy(product) }
        } label: {
            HStack {
                if store.busy == product {
                    Image(systemName: "hourglass")
                } else if owned {
                    Label(tr("shop.owned"), systemImage: "checkmark.seal.fill")
                } else {
                    Text(tr("shop.buyFor", store.price(product)))
                }
            }
        }
        .buttonStyle(.game(owned ? .green : tone, wide: true))
        .disabled(owned || store.busy != nil)
    }
}

private struct Perk: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            IconView(icon: icon, size: 20).frame(width: 26)
            Text(text).font(.game(14, .semibold))
            Spacer(minLength: 0)
        }
    }
}

struct StarterCard: View {
    @Environment(GameState.self) private var game

    var body: some View {
        ShopCard(title: "🎁 " + ProductID.starter.title, tone: .red) {
            HStack {
                if game.starterAvailable, let until = game.save.starterOfferUntil {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Label(tr("shop.endsIn", Countdown.text(until.timeIntervalSince(context.date))), systemImage: "clock")
                            .font(.game(12))
                            .foregroundStyle(ButtonTone.red.lip)
                    }
                }
                Spacer()
                Text(tr("shop.bestValue"))
                    .font(.game(11, .heavy))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Palette.gold))
                    .overlay(Capsule().strokeBorder(Palette.outline, lineWidth: 1.5))
            }
            Perk(icon: "🦆", text: tr("starter.duck"))
            Perk(icon: "🪙", text: tr("starter.coins", Fmt.n(Premium.starterCoins)))
            Perk(icon: "🎒", text: tr("starter.backpack", Premium.starterBackpack))
            Perk(icon: "🤖", text: tr("starter.skin"))
            BuyButton(product: .starter, tone: .red)
        }
    }
}

struct ProCard: View {
    var body: some View {
        ShopCard(title: "👑 " + ProductID.pro.title, tone: .purple) {
            Text(tr("pro.subtitle"))
                .font(.game(12, .semibold))
                .foregroundStyle(.secondary)
            Perk(icon: "🌙", text: tr("pro.offline", Int(Premium.proOfflineHours)))
            Perk(icon: "🌀", text: tr("pro.autoDeposit"))
            Perk(icon: "📜", text: tr("pro.quest"))
            Perk(icon: "🎁", text: tr("pro.treasure"))
            Perk(icon: "🎟️", text: tr("pro.tickets"))
            Perk(icon: "📺", text: tr("pro.noAds"))
            Perk(icon: "🧞", text: tr("pro.skin"))
            BuyButton(product: .pro, tone: .purple)
        }
    }
}

struct GardenCard: View {
    var body: some View {
        ShopCard(title: "🏰 " + ProductID.garden.title, tone: .gold) {
            Text(tr("garden.subtitle"))
                .font(.game(12, .semibold))
                .foregroundStyle(.secondary)
            Perk(icon: "🍒", text: tr("garden.trees"))
            Perk(icon: "🍯", text: tr("garden.bees"))
            Perk(icon: "👑", text: tr("garden.chest"))
            Perk(icon: "🦫", text: tr("garden.capybara", Fmt.pct(RoyalGarden.capybaraYield)))
            Perk(icon: "⚔️", text: tr("garden.skin"))
            BuyButton(product: .garden, tone: .orange)
        }
    }
}

struct TicketsCard: View {
    @Environment(GameState.self) private var game

    var body: some View {
        ShopCard(title: "🎟️ " + ProductID.tickets.title, tone: .blue) {
            HStack {
                Text(tr("tickets.subtitle", Expedition.ticketPack))
                    .font(.game(12, .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    TicketIcon(size: 18)
                    Text("\(game.save.tickets)").font(.game(14)).monospacedDigit()
                }
            }
            BuyButton(product: .tickets, tone: .blue)
        }
    }
}

struct SkinsCard: View {
    @Environment(\.gameActions) private var actions

    var body: some View {
        ShopCard(title: "🎭 " + ProductID.skins.title, tone: .green) {
            Text(tr("skins.subtitle", Skin.collection.count))
                .font(.game(12, .semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
                ForEach(Skin.collection) { skin in
                    SkinIcon(skin: skin, size: 36)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.parchmentDeep.opacity(0.7)))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.woodDark.opacity(0.35), lineWidth: 1.5))
                }
            }
            BuyButton(product: .skins, tone: .green)
            Button {
                actions.open(.wardrobe)
            } label: {
                Label(tr("wardrobe.open"), systemImage: "tshirt")
            }
            .buttonStyle(.game(.wood, small: true, wide: true))
        }
    }
}

/// Бесплатные бонусы за просмотр рекламы.
struct FreeCard: View {
    @Environment(GameState.self) private var game

    var body: some View {
        ShopCard(title: "🍀 " + tr("free.title"), tone: .green) {
            Text(game.hasPro ? tr("free.subtitle.pro") : tr("free.subtitle"))
                .font(.game(12, .semibold))
                .foregroundStyle(.secondary)
            LuckButton(style: .wide)
        }
    }
}

enum Countdown {
    static func text(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }
}

/// Удача: x2 ресурсов на 10 минут за рекламу (для Pro без рекламы).
struct LuckButton: View {
    enum Style { case wide, pill }

    @Environment(GameState.self) private var game
    @Environment(Ads.self) private var ads
    let style: Style

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            let active = (game.save.luckUntil ?? .distantPast) > now
            let readyAt = game.save.luckReadyAt ?? .distantPast
            let ready = !active && readyAt <= now
            content(active: active, ready: ready, now: now)
        }
    }

    @ViewBuilder
    private func content(active: Bool, ready: Bool, now: Date) -> some View {
        switch style {
        case .pill:
            Button {
                if ready { watch() }
            } label: {
                HStack(spacing: 5) {
                    Text("🍀").font(.system(size: 15))
                    Group {
                        if active, let until = game.save.luckUntil {
                            Text(Countdown.text(until.timeIntervalSince(now)))
                                .monospacedDigit()
                        } else if ready {
                            Text("x2")
                            if !game.hasPro { Image(systemName: "play.rectangle.fill").font(.system(size: 11, weight: .bold)) }
                        } else {
                            Text(Countdown.text((game.save.luckReadyAt ?? now).timeIntervalSince(now)))
                                .monospacedDigit()
                                .opacity(0.8)
                        }
                    }
                    .font(.game(12))
                    .foregroundStyle(.white)
                    .outlined(Palette.outline, width: 1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .woodPill(radius: 13, tint: active ? ButtonTone.green.base : Palette.wood)
            }
            .buttonStyle(.press)
        case .wide:
            Button {
                if ready { watch() }
            } label: {
                HStack(spacing: 10) {
                    Text("🍀").font(.system(size: 24))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("luck.title")).font(.game(16))
                        if active, let until = game.save.luckUntil {
                            Text(tr("luck.active", Countdown.text(until.timeIntervalSince(now)))).font(.game(12, .semibold))
                        } else if ready {
                            Text(game.hasPro ? tr("luck.ready.pro") : tr("luck.ready")).font(.game(12, .semibold))
                        } else {
                            Text(tr("luck.cooldown", Countdown.text((game.save.luckReadyAt ?? now).timeIntervalSince(now)))).font(.game(12, .semibold))
                        }
                    }
                    Spacer()
                    if ready && !game.hasPro { Image(systemName: "play.rectangle.fill").font(.game(19)) }
                }
            }
            .buttonStyle(.game(.green, wide: true))
            .disabled(!ready)
        }
    }

    private func watch() {
        ads.show {
            withAnimation(.spring(duration: 0.4)) { game.activateLuck(fromAd: !game.hasPro) }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

struct WardrobeView: View {
    @Environment(GameState.self) private var game

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 12) {
                ForEach(Skin.allCases) { skin in
                    SkinTile(skin: skin)
                }
            }
            .padding(16)
        }
        .sheetChrome(tr("wardrobe.title"), coins: game.save.coins)
    }
}

private struct SkinTile: View {
    @Environment(GameState.self) private var game
    let skin: Skin

    private var lockText: String {
        switch skin.unlock {
        case .free: return ""
        case .level(let level): return tr("common.lvl", level)
        case .product(let product): return product.title
        case .constellation(let c): return "✨ " + c.name
        case .event(let e): return e.emoji + " " + tr("skin.event", e.name)
        }
    }

    var body: some View {
        let unlocked = game.isSkinUnlocked(skin)
        let selected = game.currentSkin == skin
        Button {
            withAnimation(.spring(duration: 0.3)) { game.selectSkin(skin) }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            VStack(spacing: 6) {
                SkinIcon(skin: skin, size: 52)
                    .grayscale(unlocked ? 0 : 1)
                    .opacity(unlocked ? 1 : 0.45)
                Text(skin.name)
                    .font(.game(12))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if !unlocked {
                    Label(lockText, systemImage: "lock.fill")
                        .font(.game(10, .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(.secondary)
                } else if selected {
                    Image(systemName: "checkmark.circle.fill").font(.game(16)).foregroundStyle(Palette.good)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected ? Color(hex: 0xDDEFC8) : Palette.parchmentLight)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? Palette.outline : Palette.woodDark.opacity(0.4), lineWidth: selected ? 2.5 : 1.5)
            )
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.woodDark.opacity(0.25)).offset(y: 3))
        }
        .buttonStyle(.press)
        .disabled(!unlocked)
    }
}

/// Всплывающее предложение стартового набора.
struct OfferPopup: View {
    @Environment(GameState.self) private var game
    let onOpenShop: () -> Void

    var body: some View {
        ZStack {
            Palette.dim.ignoresSafeArea()
                .onTapGesture { close() }
            VStack(spacing: 14) {
                Text("🎁").font(.system(size: 54))
                    .padding(.top, 14)
                Text(tr("offer.text"))
                    .font(.game(14, .semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 14) {
                    Text("🦁").font(.system(size: 34))
                    CoinIcon(size: 34)
                    Text("🎒").font(.system(size: 30))
                    Text("🤖").font(.system(size: 34))
                }
                BuyButton(product: .starter, tone: .red)
                Button(tr("offer.later")) { close() }
                    .buttonStyle(.game(.wood, small: true))
            }
            .foregroundStyle(Palette.ink)
            .padding(22)
            .frame(maxWidth: 360)
            .gamePanel()
            .overlay(alignment: .top) {
                RibbonTitle(text: ProductID.starter.title, tone: .red, size: 20)
                    .padding(.horizontal, 20)
                    .offset(y: -18)
            }
            .padding(24)
        }
        .onChange(of: game.owns(.starter)) { _, owned in
            if owned { close() }
        }
    }

    private func close() {
        withAnimation(.spring(duration: 0.3)) { game.offerPopup = false }
    }
}

/// Образ персонажа: пиксельный портрет, а если спрайтов нет, эмодзи.
struct SkinIcon: View {
    let skin: Skin
    let size: CGFloat

    var body: some View {
        if let image = Sprites.portrait(skin) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Text(skin.emoji)
                .font(.system(size: size * 0.82))
        }
    }
}
