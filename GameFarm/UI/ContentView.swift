import SpriteKit
import SwiftUI

struct ContentView: View {
    @Environment(GameState.self) private var game
    @State private var scene = GameScene(size: CGSize(width: 390, height: 844))
    @State private var sheet: GameSheet?
    /// Окно, в которое вернёт крестик (гардероб из магазина или профиля).
    @State private var returnTo: GameSheet?
    private let dialogs = Dialogs.shared

    var body: some View {
        ZStack {
            // Пока открыто окно, мир почти не виден: рисуем его реже, чтобы телефон не грелся.
            SpriteView(scene: scene, preferredFramesPerSecond: sheet == nil ? 60 : 30,
                       options: [.ignoresSiblingOrder, .shouldCullNonVisibleNodes])
                .ignoresSafeArea()

            HUDView(scene: scene, sheet: $sheet)

            if let id = game.banner {
                LocationBanner(id: id)
                    .transition(.asymmetric(insertion: .scale(scale: 0.7).combined(with: .opacity),
                                            removal: .opacity.combined(with: .move(edge: .top))))
                    .allowsHitTesting(false)
                    .zIndex(5)
            }

            if let treasure = game.treasureFound {
                TreasureCard(treasure: treasure)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .allowsHitTesting(false)
                    .zIndex(6)
                    .task(id: treasure) {
                        try? await Task.sleep(for: .seconds(2.6))
                        withAnimation(.easeOut(duration: 0.3)) { game.treasureFound = nil }
                    }
            }

            if let chest = game.gardenChestFound {
                RoyalChestCard(treasure: chest)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .allowsHitTesting(false)
                    .zIndex(6)
                    .task(id: chest) {
                        try? await Task.sleep(for: .seconds(3))
                        withAnimation(.easeOut(duration: 0.3)) { game.gardenChestFound = nil }
                    }
            }

            if game.offerPopup && game.starterAvailable && game.levelUp == nil {
                OfferPopup { open(.shop) }
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                    .zIndex(11)
            }

            if game.bigMap {
                BigMapOverlay(player: scene.playerPosition,
                              onWorldMap: { game.bigMap = false; open(.map) },
                              onClose: { game.bigMap = false })
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                    .zIndex(14)
            }

            if let which = sheet {
                Palette.dim
                    .ignoresSafeArea()
                    .onTapGesture { closeAll() }
                    .transition(.opacity)
                    .zIndex(15)
                window(which)
                    .modifier(GameWindowFrame())
                    .padding(.top, 34)
                    .transition(.move(edge: .bottom))
                    .zIndex(16)
                    .id(which)
            }

            if let report = game.expeditionReport, game.levelUp == nil {
                ExpeditionReportOverlay(report: report) {
                    withAnimation(.spring(duration: 0.3)) { game.expeditionReport = nil }
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))
                .zIndex(18)
            }

            if let info = game.levelUp {
                LevelUpOverlay(info: info) {
                    withAnimation(.spring(duration: 0.3)) { game.levelUp = nil }
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))
                .zIndex(20)
            } else if let report = game.offlineReport {
                OfflineOverlay(report: report) {
                    withAnimation(.spring(duration: 0.3)) { game.offlineReport = nil }
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))
                .zIndex(19)
            }

            if let item = dialogs.current {
                DialogView(item: item) {
                    withAnimation(.spring(duration: 0.25)) { dialogs.current = nil }
                }
                .transition(.scale(scale: 0.9).combined(with: .opacity))
                .zIndex(30)
                .id(item.id)
            }
        }
        .environment(\.gameActions, GameActions(close: { close() }, open: { open($0) }))
        .animation(.spring(duration: 0.4, bounce: 0.35), value: game.banner)
        .animation(.spring(duration: 0.4, bounce: 0.4), value: game.treasureFound)
        .animation(.spring(duration: 0.35), value: game.levelUp)
        .animation(.spring(duration: 0.35), value: game.offlineReport)
        .animation(.spring(duration: 0.35), value: game.offerPopup)
        .animation(.spring(duration: 0.35), value: game.expeditionReport)
        .animation(.spring(duration: 0.4, bounce: 0.4), value: game.gardenChestFound)
        .animation(.spring(duration: 0.32, bounce: 0.12), value: sheet)
        .animation(.spring(duration: 0.3), value: game.bigMap)
        .animation(.spring(duration: 0.25), value: dialogs.current?.id)
        .onChange(of: sheet) { old, new in
            if new != nil && old == nil { Sound.shared.play(.open) }
            if new == nil && old != nil { Sound.shared.play(.close) }
            scene.view?.preferredFramesPerSecond = new == nil ? 60 : 30
        }
    }

    @ViewBuilder
    private func window(_ which: GameSheet) -> some View {
        Group {
            switch which {
            case .storage: StorageView()
            case .workshop: WorkshopView()
            case .talents: TalentsView()
            case .animals: AnimalsView()
            case .quests: QuestsView()
            case .map: MapView(onTravel: { closeAll() }, onShop: { open(.shop) })
            case .level: LevelView()
            case .shop: ShopView()
            case .wardrobe: WardrobeView()
            case .legacy: LegacyView()
            }
        }
        .environment(game)
        .environment(Store.shared)
        .environment(Ads.shared)
    }

    private func open(_ which: GameSheet) {
        returnTo = which == .wardrobe || which == .legacy ? sheet : nil
        sheet = which
    }

    private func close() {
        sheet = returnTo
        returnTo = nil
    }

    private func closeAll() {
        returnTo = nil
        sheet = nil
    }
}

struct LocationBanner: View {
    let id: LocationID

    var body: some View {
        let spec = id.spec
        VStack(spacing: 6) {
            Text(spec.emoji).font(.system(size: 40))
            RibbonTitle(text: spec.name, tone: .green, size: 24)
            Text(spec.blurb)
                .font(.game(13, .bold))
                .foregroundStyle(.white)
                .outlined(Palette.outline, width: 1)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .frame(maxWidth: 340)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 150)
    }
}

struct TreasureCard: View {
    let treasure: Treasure

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    CoinIcon(size: 22)
                    Text("+\(Fmt.n(treasure.coins))").font(.game(17))
                }
                ForEach(treasure.items) { item in
                    HStack(spacing: 4) {
                        ResourceIcon(kind: item.kind, size: 24)
                        Text("+\(Fmt.n(item.amount))").font(.game(17))
                    }
                }
            }
            .foregroundStyle(Palette.ink)
            .padding(.top, 22)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
        .gamePanel(fill: Palette.parchmentLight, frame: Palette.gold, radius: 18, border: 3)
        .overlay(alignment: .top) {
            RibbonTitle(text: tr("treasure.title"), tone: .gold, size: 17).offset(y: -16)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 180)
    }
}

struct HUDView: View {
    @Environment(GameState.self) private var game
    let scene: GameScene
    @Binding var sheet: GameSheet?

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                levelBadge
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 6) {
                    coinsPill
                    backpackPill
                    HStack(spacing: 6) {
                        LuckButton(style: .pill)
                        shopPill
                    }
                }
            }

            ExpeditionPill()

            ForEach(game.toasts) { toast in
                ToastView(toast: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer(minLength: 0)

            if !game.save.tutorialDone {
                TutorialCard()
                    .transition(.opacity)
            }

            if let encounter = game.encounter {
                EncounterCard(encounter: encounter) { scene.tameNearby() }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if let gate = game.gatePrompt {
                GateCard(gateID: gate) { sheet = .shop }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            bottomBar
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 4)
        .animation(.spring(duration: 0.35), value: game.encounter)
        .animation(.spring(duration: 0.35), value: game.gatePrompt)
        .animation(.spring(duration: 0.35), value: game.toasts)
        .animation(.easeInOut(duration: 0.3), value: game.save.tutorialDone)
    }

    private var levelBadge: some View {
        Button {
            sheet = .level
        } label: {
            HStack(spacing: 9) {
                ZStack(alignment: .bottomLeading) {
                    SkinIcon(skin: game.currentSkin, size: 40)
                        .frame(width: 46, height: 46)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.parchment))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Palette.outline, lineWidth: 2))
                    Text("\(game.save.level)")
                        .font(.game(13))
                        .foregroundStyle(.white)
                        .outlined(Palette.outline, width: 1)
                        .contentTransition(.numericText())
                        .padding(.horizontal, 4)
                        .frame(minWidth: 24, minHeight: 24)
                        .background(Capsule().fill(LinearGradient(colors: [ButtonTone.orange.top, ButtonTone.orange.base],
                                                                  startPoint: .top, endPoint: .bottom)))
                        .overlay(Capsule().strokeBorder(Palette.outline, lineWidth: 2))
                        .offset(x: -7, y: 7)
                }
                .overlay(alignment: .topTrailing) {
                    if game.hasPro {
                        Text("👑").font(.system(size: 14)).offset(x: 6, y: -8)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(game.save.current.spec.emoji) \(game.save.current.spec.name)")
                        .font(.game(13))
                        .foregroundStyle(.white)
                        .outlined(Palette.outline, width: 1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    GameBar(value: game.levelProgress, tone: .gold, height: 14,
                            label: game.save.level >= GameRules.maxLevel ? tr("level.max")
                                : "\(Fmt.n(game.save.xp))/\(Fmt.n(game.xpToNext))")
                        .frame(width: 118)
                        .animation(.easeOut(duration: 0.4), value: game.levelProgress)
                }
                .padding(.trailing, 6)
            }
            .padding(6)
            .woodPill(radius: 16)
        }
        .buttonStyle(.press)
    }

    private var coinsPill: some View {
        HStack(spacing: 5) {
            CoinIcon(size: 20)
            Text(Fmt.n(game.save.coins))
                .font(.game(15))
                .foregroundStyle(.white)
                .outlined(Palette.outline, width: 1)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy, value: game.save.coins)
        }
        .padding(.leading, 7)
        .padding(.trailing, 11)
        .padding(.vertical, 5)
        .woodPill(radius: 13)
    }

    private var backpackPill: some View {
        let count = game.backpackCount
        let capacity = game.stats.capacity
        let fraction = min(1, Double(count) / Double(max(1, capacity)))
        let tone: ButtonTone = fraction >= 1 ? .red : (fraction > 0.8 ? .orange : .green)
        return HStack(spacing: 6) {
            PixelIcon(name: "bag", size: 20, fallback: "🎒")
            GameBar(value: fraction, tone: tone, height: 14, label: "\(count)/\(capacity)")
                .frame(width: 76)
                .animation(.easeOut(duration: 0.25), value: fraction)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .woodPill(radius: 13)
        .scaleEffect(game.backpackFull ? 1.07 : 1)
        .animation(.spring(duration: 0.3, bounce: 0.5), value: game.backpackFull)
    }

    private var shopPill: some View {
        Button {
            sheet = .shop
        } label: {
            HStack(spacing: 5) {
                PixelIcon(name: game.starterAvailable ? "chest_gold" : "chest", size: 20, fallback: "🛍️")
                if game.starterAvailable, let until = game.save.starterOfferUntil {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(Countdown.text(until.timeIntervalSince(context.date)))
                            .font(.game(12))
                            .foregroundStyle(Palette.gold)
                            .outlined(Palette.outline, width: 1)
                            .monospacedDigit()
                    }
                } else {
                    Text(tr("shop.short"))
                        .font(.game(12))
                        .foregroundStyle(.white)
                        .outlined(Palette.outline, width: 1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .woodPill(radius: 13, tint: game.starterAvailable ? ButtonTone.orange.base : Palette.wood)
        }
        .buttonStyle(.press)
    }

    private var bottomBar: some View {
        HStack(spacing: 6) {
            HUDButton(icon: "chest", fallback: "📦", title: tr("hud.storage")) { sheet = .storage }
            HUDButton(icon: "tool_hammer", fallback: "🔨", title: tr("hud.workshop"), badge: workshopBadge) { sheet = .workshop }
            HUDButton(icon: "stardust", fallback: "🌟", title: tr("hud.talents"), badge: game.talentPointsFree) { sheet = .talents }
            HUDButton(icon: "paw", fallback: "🐾", title: tr("hud.animals")) { sheet = .animals }
            HUDButton(icon: "scroll", fallback: "📜", title: tr("hud.quests"), badge: game.claimableQuests + game.claimableAchievements) { sheet = .quests }
            HUDButton(icon: "map", fallback: "🗺️", title: tr("hud.map"), badge: mapBadge) { sheet = .map }
        }
    }

    private var workshopBadge: Int {
        ToolKind.upgradable.filter { tool in
            let next = game.tier(tool) + 1
            guard next <= ToolTier.maxTier, game.save.level >= ToolTier.requiredLevel(tool, tier: next),
                  let cost = game.nextToolCost(tool) else { return false }
            return game.canAfford(cost)
        }.count
    }

    private var mapBadge: Int {
        game.openableGates + (game.freeTicketReady ? 1 : 0)
    }
}

struct HUDButton: View {
    let icon: String
    var fallback: String = ""
    let title: String
    var badge: Int = 0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                PixelIcon(name: icon, size: 30, fallback: fallback)
                Text(title)
                    .font(.game(10))
                    .foregroundStyle(.white)
                    .outlined(Palette.outline, width: 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .woodPill(radius: 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .overlay(alignment: .topTrailing) {
            if badge > 0 {
                CountBadge(count: badge).offset(x: 4, y: -7)
            }
        }
    }
}

struct ToastView: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: 8) {
            Text(toast.icon).font(.system(size: 18))
            Text(toast.text)
                .font(.game(13, .bold))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(Palette.parchmentLight))
        .overlay(Capsule().strokeBorder(Palette.outline, lineWidth: 2))
        .background(Capsule().fill(Palette.outline.opacity(0.4)).offset(y: 3))
    }
}

struct TutorialCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(tr("tutorial.title")).font(.game(16))
            Label(tr("tutorial.move"), systemImage: "hand.draw")
            Label(tr("tutorial.gather"), systemImage: "hammer")
            Label(tr("tutorial.deposit"), systemImage: "shippingbox")
        }
        .font(.game(13, .semibold))
        .foregroundStyle(Palette.ink)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .gamePanel(radius: 16, border: 3)
    }
}

struct EncounterCard: View {
    @Environment(GameState.self) private var game
    let encounter: Encounter
    let onTame: () -> Void

    var body: some View {
        let spec = encounter.animal.spec
        let stars = game.stars(encounter.animal)
        let cost = game.tameCost(encounter.animal)
        HStack(spacing: 12) {
            AnimalIcon(id: encounter.animal, size: 52)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(spec.name).font(.game(16))
                    if stars > 0 { StarsView(stars: stars) }
                }
                Text(spec.effects.first?.text(multiplier: game.stats.starMultiplier(max(1, stars + 1)) * game.stats.animalMult) ?? "")
                    .font(.game(12, .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if let cost, stars < AnimalSpec.maxStars {
                    CostView(cost: cost)
                }
            }
            Spacer(minLength: 0)
            if stars >= AnimalSpec.maxStars {
                Text(tr("common.max")).font(.game(13)).foregroundStyle(Palette.inkSoft)
            } else {
                Button(stars > 0 ? tr("tame.more") : tr("tame.action"), action: onTame)
                    .buttonStyle(.game(.green))
                    .disabled(cost.map { !game.canAfford($0) } ?? true)
            }
        }
        .foregroundStyle(Palette.ink)
        .padding(12)
        .gamePanel(radius: 18, border: 3)
    }
}
