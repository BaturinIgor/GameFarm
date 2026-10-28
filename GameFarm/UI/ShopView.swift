import SwiftUI

/// Магазин: одно главное предложение крупно, остальные наборы плитками, билеты и бесплатная удача.
/// Подробности о наборе открываются по нажатию на плитку, чтобы экран не был перегружен текстом.
struct ShopView: View {
    @Environment(GameState.self) private var game
    @Environment(Store.self) private var store
    @State private var detail: ProductID?

    /// Что показать крупно: стартовый набор, пока действует, потом пропуск ивента, Pro и сад.
    private var featured: ProductID? {
        if game.starterAvailable && !game.owns(.starter) { return .starter }
        if game.eventsOpen && !game.hasVip { return .eventPass }
        if !game.owns(.pro) { return .pro }
        if !game.owns(.garden) { return .garden }
        return nil
    }

    private var bundles: [ProductID] {
        var list: [ProductID] = [.pro, .garden, .skins]
        if game.starterAvailable || game.owns(.starter) { list.insert(.starter, at: 0) }
        if game.eventsOpen { list.append(.eventPass) }
        let rest = list.filter { $0 != featured }
        // купленное уходит в конец
        return rest.filter { !owned($0) } + rest.filter { owned($0) }
    }

    private func owned(_ product: ProductID) -> Bool {
        product == .eventPass ? game.hasVip : game.owns(product)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if Store.testMode {
                    Label(tr("shop.testMode"), systemImage: "testtube.2")
                        .font(.game(12))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let featured {
                    FeaturedOffer(product: featured) { detail = featured }
                }
                SectionTitle(text: tr("shop.section.bundles"))
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(bundles) { product in
                        OfferTile(product: product, owned: owned(product)) { detail = product }
                    }
                }
                SectionTitle(text: tr("shop.section.tickets"))
                TicketsRow()
                SectionTitle(text: tr("free.title"))
                Text(game.hasPro ? tr("free.subtitle.pro") : tr("free.subtitle"))
                    .font(.game(12, .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                LuckButton(style: .wide)
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
        .overlay {
            if let detail {
                OfferDetail(product: detail) { withAnimation(.spring(duration: 0.3)) { self.detail = nil } }
                    .transition(.opacity)
            }
        }
        .animation(.spring(duration: 0.3), value: detail)
        .sheetChrome(tr("shop.title"), coins: game.save.coins)
        .onChange(of: store.errorMessage) { _, message in
            guard let message else { return }
            Dialogs.shared.info(tr("shop.error"), message: message)
            store.errorMessage = nil
        }
    }
}

/// Строка преимущества: иконка и текст.
struct ShopPerk: Identifiable {
    let icon: String
    let text: String
    var id: String { icon + text }
}

/// Описание наборов для магазина: цвет, короткая строка и список преимуществ.
@MainActor
enum Offers {
    static func tone(_ product: ProductID) -> ButtonTone {
        switch product {
        case .starter: .red
        case .pro: .purple
        case .garden: .orange
        case .skins: .green
        case .tickets: .blue
        case .eventPass: .gold
        }
    }

    static func tagline(_ product: ProductID) -> String {
        switch product {
        case .skins: tr("offer.tag.skins", Skin.collection.count)
        case .tickets: tr("offer.tag.tickets", Expedition.ticketPack)
        default: tr("offer.tag.\(product.key)")
        }
    }

    static func perks(_ product: ProductID) -> [ShopPerk] {
        switch product {
        case .starter:
            [ShopPerk(icon: "an:duckHat", text: tr("starter.duck")),
             ShopPerk(icon: "🪙", text: tr("starter.coins", Fmt.n(Premium.starterCoins))),
             ShopPerk(icon: "px:bag", text: tr("starter.backpack", Premium.starterBackpack)),
             ShopPerk(icon: "skin:robot", text: tr("starter.skin"))]
        case .pro:
            [ShopPerk(icon: "px:no_ads", text: tr("pro.noAds")),
             ShopPerk(icon: "px:moon", text: tr("pro.offline", Int(Premium.proOfflineHours))),
             ShopPerk(icon: "px:portal", text: tr("pro.autoDeposit")),
             ShopPerk(icon: "px:quest", text: tr("pro.quest")),
             ShopPerk(icon: "px:chest", text: tr("pro.treasure")),
             ShopPerk(icon: "px:ticket", text: tr("pro.tickets")),
             ShopPerk(icon: "skin:genie", text: tr("pro.skin"))]
        case .garden:
            [ShopPerk(icon: "px:apples", text: tr("garden.trees")),
             ShopPerk(icon: "px:honey", text: tr("garden.bees")),
             ShopPerk(icon: "px:chest_gold", text: tr("garden.chest")),
             ShopPerk(icon: "px:basket", text: tr("garden.capybara", Fmt.pct(RoyalGarden.capybaraYield))),
             ShopPerk(icon: "skin:knight", text: tr("garden.skin"))]
        case .skins:
            [ShopPerk(icon: "px:wardrobe", text: tr("skins.subtitle", Skin.collection.count))]
        case .tickets:
            [ShopPerk(icon: "px:ticket", text: tr("tickets.subtitle", Expedition.ticketPack))]
        case .eventPass:
            [ShopPerk(icon: "skin:" + Events.current.event.skin.rawValue, text: tr("event.vip.desc", Events.current.event.skin.name))]
        }
    }
}

/// Крупная картинка набора.
struct OfferArt: View {
    let product: ProductID
    let size: CGFloat

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            switch product {
            case .starter:
                PixelIcon(name: "chest_gold", size: size * 0.9)
                AnimalIcon(id: .duckHat, size: size * 0.5).offset(x: size * 0.1, y: size * 0.05)
            case .pro:
                SkinIcon(skin: .genie, size: size)
                PixelIcon(name: "crown", size: size * 0.42).offset(x: size * 0.08, y: size * 0.04)
            case .garden:
                SkinIcon(skin: .knight, size: size)
                PixelIcon(name: "goldenApple", size: size * 0.42).offset(x: size * 0.08, y: size * 0.04)
            case .skins:
                SkinIcon(skin: .wizard, size: size)
                PixelIcon(name: "wardrobe", size: size * 0.42).offset(x: size * 0.08, y: size * 0.04)
            case .tickets:
                TicketIcon(size: size * 0.85)
            case .eventPass:
                SkinIcon(skin: Events.current.event.skin, size: size)
                PixelIcon(name: "star", size: size * 0.42).offset(x: size * 0.08, y: size * 0.04)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Главное предложение: цветной баннер, до четырёх преимуществ и покупка.
struct FeaturedOffer: View {
    @Environment(GameState.self) private var game
    let product: ProductID
    let onMore: () -> Void

    var body: some View {
        let tone = Offers.tone(product)
        let perks = Offers.perks(product)
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                OfferArt(product: product, size: 76)
                    .padding(8)
                    .background(Circle().fill(Color.white.opacity(0.85)))
                    .overlay(Circle().strokeBorder(Palette.outline, lineWidth: 2.5))
                VStack(alignment: .leading, spacing: 4) {
                    badge(tone)
                    Text(product.title)
                        .gameTitle(21)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Text(Offers.tagline(product))
                        .font(.game(12, .semibold))
                        .foregroundStyle(.white)
                        .outlined(tone.lip, width: 1)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 7) {
                ForEach(perks.prefix(4)) { perk in
                    HStack(spacing: 10) {
                        IconView(icon: perk.icon, size: 24).frame(width: 28)
                        Text(perk.text)
                            .font(.game(13, .semibold))
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
                if perks.count > 4 {
                    Button(action: onMore) {
                        Text(tr("shop.morePerks", perks.count - 4))
                            .font(.game(12))
                            .foregroundStyle(tone.lip)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.parchmentLight))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.outline.opacity(0.6), lineWidth: 2))
            BuyButton(product: product, tone: tone == .gold ? .orange : tone)
        }
        .padding(16)
        .background(shape.fill(LinearGradient(colors: [tone.top, tone.base], startPoint: .top, endPoint: .bottom)))
        .overlay(shape.strokeBorder(Palette.outline, lineWidth: 3))
        .background(shape.fill(tone.lip).offset(y: 5))
    }

    @ViewBuilder
    private func badge(_ tone: ButtonTone) -> some View {
        if product == .starter, let until = game.save.starterOfferUntil {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                chip(tr("shop.endsIn", Countdown.text(until.timeIntervalSince(context.date))), icon: "clock")
            }
        } else if product == .eventPass {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                chip(tr("shop.endsIn", Countdown.long(Events.current.end.timeIntervalSince(context.date))), icon: "clock")
            }
        } else {
            chip(tr("shop.bestValue"), icon: "sparkles")
        }
    }

    private func chip(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.game(11, .heavy))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Palette.gold))
            .overlay(Capsule().strokeBorder(Palette.outline, lineWidth: 1.5))
    }
}

/// Плитка набора: картинка, название, одна строка и цена. Нажатие открывает подробности.
struct OfferTile: View {
    @Environment(Store.self) private var store
    let product: ProductID
    let owned: Bool
    let onOpen: () -> Void

    var body: some View {
        let tone = Offers.tone(product)
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        Button(action: onOpen) {
            VStack(spacing: 6) {
                OfferArt(product: product, size: 54)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(LinearGradient(colors: [tone.top, tone.base], startPoint: .top, endPoint: .bottom))
                Text(product.title)
                    .font(.game(14))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 6)
                Text(Offers.tagline(product))
                    .font(.game(11, .semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 6)
                Spacer(minLength: 0)
                Group {
                    if owned {
                        Label(tr("shop.owned"), systemImage: "checkmark.seal.fill")
                            .foregroundStyle(Palette.good)
                    } else {
                        Text(store.price(product))
                            .foregroundStyle(.white)
                            .outlined(tone.lip, width: 1)
                    }
                }
                .font(.game(13))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(owned ? AnyShapeStyle(Palette.parchmentDeep) : AnyShapeStyle(tone.base))
            }
            .frame(maxWidth: .infinity, minHeight: 190)
            .background(Palette.parchmentLight)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Palette.outline, lineWidth: 2))
            .background(shape.fill(Palette.woodDark.opacity(0.3)).offset(y: 3))
            .opacity(owned ? 0.75 : 1)
        }
        .buttonStyle(.press)
    }
}

/// Подробности набора поверх магазина.
struct OfferDetail: View {
    @Environment(GameState.self) private var game
    @Environment(\.gameActions) private var actions
    let product: ProductID
    let onClose: () -> Void

    var body: some View {
        let tone = Offers.tone(product)
        ZStack {
            Palette.dim.ignoresSafeArea().onTapGesture(perform: onClose)
            VStack(spacing: 12) {
                OfferArt(product: product, size: 70)
                    .padding(.top, 18)
                Text(Offers.tagline(product))
                    .font(.game(13, .semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if product == .skins {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
                        ForEach(Skin.collection) { skin in
                            SkinIcon(skin: skin, size: 34)
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.parchmentDeep.opacity(0.7)))
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Offers.perks(product)) { perk in
                            HStack(alignment: .top, spacing: 10) {
                                IconView(icon: perk.icon, size: 24).frame(width: 28)
                                Text(perk.text)
                                    .font(.game(13, .semibold))
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
                BuyButton(product: product, tone: tone == .gold ? .orange : tone)
                HStack(spacing: 8) {
                    if product == .skins {
                        Button {
                            onClose()
                            actions.open(.wardrobe)
                        } label: {
                            Label(tr("wardrobe.open"), systemImage: "tshirt")
                        }
                        .buttonStyle(.game(.wood, small: true))
                    }
                    Button(tr("common.close"), action: onClose)
                        .buttonStyle(.game(.wood, small: true))
                }
            }
            .foregroundStyle(Palette.ink)
            .padding(18)
            .frame(maxWidth: 380)
            .gamePanel(fill: Palette.parchmentLight, frame: tone.base)
            .overlay(alignment: .top) {
                RibbonTitle(text: product.title, tone: tone, size: 19)
                    .padding(.horizontal, 24)
                    .offset(y: -18)
            }
            .padding(24)
            .popIn()
        }
    }
}

/// Билеты в экспедиции: сколько есть и покупка пачки.
struct TicketsRow: View {
    @Environment(GameState.self) private var game
    @Environment(Store.self) private var store

    var body: some View {
        HStack(spacing: 12) {
            TicketIcon(size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(tr("offer.tag.tickets", Expedition.ticketPack)).font(.game(15))
                Text(tr("tickets.have", game.save.tickets))
                    .font(.game(12, .semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Button {
                Task { await store.buy(.tickets) }
            } label: {
                if store.busy == .tickets {
                    Image(systemName: "hourglass")
                } else {
                    Text(store.price(.tickets))
                }
            }
            .buttonStyle(.game(.blue, small: true))
            .disabled(store.busy != nil)
        }
        .padding(12)
        .listBox()
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
                    PixelIcon(name: "clover", size: 16)
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
                    PixelIcon(name: "clover", size: 28)
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
        case .constellation(let c): return c.name
        case .event(let e): return tr("skin.event", e.name)
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
                OfferArt(product: .starter, size: 70)
                    .padding(.top, 14)
                Text(tr("offer.text"))
                    .font(.game(14, .semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 14) {
                    AnimalIcon(id: .duckHat, size: 34)
                    CoinIcon(size: 34)
                    PixelIcon(name: "bag", size: 32)
                    SkinIcon(skin: .robot, size: 34)
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
            .popIn()
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
