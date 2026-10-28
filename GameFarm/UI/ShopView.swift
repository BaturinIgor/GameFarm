import SwiftUI

struct ShopView: View {
    @Environment(GameState.self) private var game
    @Environment(Store.self) private var store
    @State private var showWardrobe = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if Store.testMode {
                        Label(tr("shop.testMode"), systemImage: "testtube.2")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if game.starterAvailable || game.owns(.starter) {
                        StarterCard()
                    }
                    ProCard()
                    SkinsCard(showWardrobe: $showWardrobe)
                    FreeCard()
                    Button {
                        Task { await store.restore() }
                    } label: {
                        Label(tr("shop.restore"), systemImage: "arrow.clockwise")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    Text(tr("shop.footer"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(16)
            }
            .sheetChrome(tr("shop.title"), coins: game.save.coins)
            .sheet(isPresented: $showWardrobe) {
                WardrobeView().environment(game)
            }
            .alert(tr("shop.error"), isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                Button(tr("common.ok"), role: .cancel) {}
            } message: {
                Text(store.errorMessage ?? "")
            }
        }
    }
}

/// Кнопка покупки с ценой и индикатором ожидания.
struct BuyButton: View {
    @Environment(GameState.self) private var game
    @Environment(Store.self) private var store
    let product: ProductID
    var tint: Color = .orange

    var body: some View {
        let owned = game.owns(product)
        Button {
            Task { await store.buy(product) }
        } label: {
            HStack {
                if store.busy == product {
                    ProgressView().tint(.white)
                } else if owned {
                    Label(tr("shop.owned"), systemImage: "checkmark.seal.fill")
                } else {
                    Text(tr("shop.buyFor", store.price(product)))
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .tint(owned ? .green : tint)
        .controlSize(.large)
        .disabled(owned || store.busy != nil)
    }
}

private struct Perk: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(icon).font(.system(size: 18)).frame(width: 26)
            Text(text).font(.subheadline)
            Spacer(minLength: 0)
        }
    }
}

struct StarterCard: View {
    @Environment(GameState.self) private var game

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("🎁 " + ProductID.starter.title)
                        .font(.title3.bold())
                    if game.starterAvailable, let until = game.save.starterOfferUntil {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Label(tr("shop.endsIn", Countdown.text(until.timeIntervalSince(context.date))), systemImage: "clock")
                                .font(.caption.bold())
                                .foregroundStyle(.orange)
                        }
                    }
                }
                Spacer()
                Text(tr("shop.bestValue"))
                    .font(.system(size: 11, weight: .heavy))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.red))
                    .foregroundStyle(.white)
            }
            Perk(icon: "🦁", text: tr("starter.lion"))
            Perk(icon: "🪙", text: tr("starter.coins", Fmt.n(Premium.starterCoins)))
            Perk(icon: "🎒", text: tr("starter.backpack", Premium.starterBackpack))
            Perk(icon: "🤖", text: tr("starter.skin"))
            BuyButton(product: .starter, tint: .red)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [Color.orange.opacity(0.28), Color.pink.opacity(0.22)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.orange.opacity(0.6), lineWidth: 2))
    }
}

struct ProCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("👑 " + ProductID.pro.title)
                .font(.title3.bold())
            Text(tr("pro.subtitle"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Perk(icon: "🌙", text: tr("pro.offline", Int(Premium.proOfflineHours)))
            Perk(icon: "🌀", text: tr("pro.autoDeposit"))
            Perk(icon: "📜", text: tr("pro.quest"))
            Perk(icon: "🎁", text: tr("pro.treasure"))
            Perk(icon: "📺", text: tr("pro.noAds"))
            Perk(icon: "🧞", text: tr("pro.skin"))
            BuyButton(product: .pro, tint: .purple)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [Color.purple.opacity(0.25), Color.indigo.opacity(0.2)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.purple.opacity(0.5), lineWidth: 2))
    }
}

struct SkinsCard: View {
    @Binding var showWardrobe: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🎭 " + ProductID.skins.title)
                .font(.title3.bold())
            Text(tr("skins.subtitle", Skin.collection.count))
                .font(.caption)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
                ForEach(Skin.collection) { skin in
                    SkinIcon(skin: skin, size: 36)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.secondary.opacity(0.12)))
                }
            }
            BuyButton(product: .skins, tint: .teal)
            Button {
                showWardrobe = true
            } label: {
                Label(tr("wardrobe.open"), systemImage: "tshirt")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(uiColor: .secondarySystemGroupedBackground)))
    }
}

/// Бесплатные бонусы за просмотр рекламы.
struct FreeCard: View {
    @Environment(GameState.self) private var game

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tr("free.title")).font(.title3.bold())
            Text(game.hasPro ? tr("free.subtitle.pro") : tr("free.subtitle"))
                .font(.caption)
                .foregroundStyle(.secondary)
            LuckButton(style: .wide)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(uiColor: .secondarySystemGroupedBackground)))
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
                    if active, let until = game.save.luckUntil {
                        Text(Countdown.text(until.timeIntervalSince(now)))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.green)
                    } else if ready {
                        Text("x2").font(.system(size: 13, weight: .heavy, design: .rounded))
                        if !game.hasPro { Image(systemName: "play.rectangle.fill").font(.system(size: 11)) }
                    } else {
                        Text(Countdown.text((game.save.luckReadyAt ?? now).timeIntervalSince(now)))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
            }
            .buttonStyle(.plain)
            .glassEffect(active ? .regular.tint(Color.green.opacity(0.35)) : .regular.interactive(), in: .capsule)
        case .wide:
            Button {
                if ready { watch() }
            } label: {
                HStack(spacing: 10) {
                    Text("🍀").font(.system(size: 24))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("luck.title")).font(.headline)
                        if active, let until = game.save.luckUntil {
                            Text(tr("luck.active", Countdown.text(until.timeIntervalSince(now)))).font(.caption)
                        } else if ready {
                            Text(game.hasPro ? tr("luck.ready.pro") : tr("luck.ready")).font(.caption)
                        } else {
                            Text(tr("luck.cooldown", Countdown.text((game.save.luckReadyAt ?? now).timeIntervalSince(now)))).font(.caption)
                        }
                    }
                    Spacer()
                    if ready && !game.hasPro { Image(systemName: "play.rectangle.fill").font(.title3) }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.green)
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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(Skin.allCases) { skin in
                        SkinTile(skin: skin)
                    }
                }
                .padding(16)
            }
            .navigationTitle(tr("wardrobe.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { SheetCloseButton() }
            }
            .background(Color(uiColor: .systemGroupedBackground))
        }
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
                    .font(.caption.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if !unlocked {
                    Label(lockText, systemImage: "lock.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(.secondary)
                } else if selected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(selected ? Color.green.opacity(0.18) : Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(selected ? Color.green : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
    }
}

/// Всплывающее предложение стартового набора.
struct OfferPopup: View {
    @Environment(GameState.self) private var game
    let onOpenShop: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
                .onTapGesture { close() }
            VStack(spacing: 14) {
                Text("🎁").font(.system(size: 54))
                Text(ProductID.starter.title)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                Text(tr("offer.text"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 14) {
                    Text("🦁").font(.system(size: 34))
                    Text("🪙").font(.system(size: 30))
                    Text("🎒").font(.system(size: 30))
                    Text("🤖").font(.system(size: 34))
                }
                BuyButton(product: .starter, tint: .red)
                Button(tr("offer.later")) { close() }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(22)
            .frame(maxWidth: 360)
            .glassEffect(.regular, in: .rect(cornerRadius: 28))
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
