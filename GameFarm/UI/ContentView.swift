import SpriteKit
import SwiftUI

struct ContentView: View {
    @Environment(GameState.self) private var game
    @State private var scene = GameScene(size: CGSize(width: 390, height: 844))
    @State private var sheet: GameSheet?

    var body: some View {
        ZStack {
            SpriteView(scene: scene, preferredFramesPerSecond: 120, options: [.ignoresSiblingOrder])
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

            if game.offerPopup && game.starterAvailable && game.levelUp == nil {
                OfferPopup { sheet = .shop }
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                    .zIndex(11)
            }

            if let info = game.levelUp {
                LevelUpOverlay(info: info) {
                    withAnimation(.spring(duration: 0.3)) { game.levelUp = nil }
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))
                .zIndex(10)
            } else if let report = game.offlineReport {
                OfflineOverlay(report: report) {
                    withAnimation(.spring(duration: 0.3)) { game.offlineReport = nil }
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))
                .zIndex(9)
            }
        }
        .animation(.spring(duration: 0.4, bounce: 0.35), value: game.banner)
        .animation(.spring(duration: 0.4, bounce: 0.4), value: game.treasureFound)
        .animation(.spring(duration: 0.35), value: game.levelUp)
        .animation(.spring(duration: 0.35), value: game.offlineReport)
        .animation(.spring(duration: 0.35), value: game.offerPopup)
        .sheet(item: $sheet) { which in
            Group {
                switch which {
                case .storage: StorageView()
                case .workshop: WorkshopView()
                case .talents: TalentsView()
                case .animals: AnimalsView()
                case .quests: QuestsView()
                case .map: MapView { sheet = nil }
                case .level: LevelView()
                case .shop: ShopView()
                case .wardrobe: WardrobeView()
                }
            }
            .environment(game)
            .environment(Store.shared)
            .environment(Ads.shared)
            .presentationDragIndicator(.visible)
        }
    }
}

struct LocationBanner: View {
    let id: LocationID

    var body: some View {
        let spec = id.spec
        VStack(spacing: 4) {
            Text(spec.emoji).font(.system(size: 46))
            Text(spec.name)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
            Text(spec.blurb)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .frame(maxWidth: 320)
        .glassEffect(.regular.tint(Color(uiColor: spec.ground).opacity(0.35)), in: .rect(cornerRadius: 28))
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 150)
    }
}

struct TreasureCard: View {
    let treasure: Treasure

    var body: some View {
        VStack(spacing: 8) {
            Text(tr("treasure.title"))
                .font(.system(size: 22, weight: .heavy, design: .rounded))
            HStack(spacing: 10) {
                HStack(spacing: 3) {
                    Text("🪙")
                    Text("+\(Fmt.n(treasure.coins))").font(.system(size: 16, weight: .bold, design: .rounded))
                }
                ForEach(treasure.items) { item in
                    HStack(spacing: 3) {
                        ResourceIcon(kind: item.kind, size: 22)
                        Text("+\(Fmt.n(item.amount))").font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .glassEffect(.regular.tint(Color.yellow.opacity(0.3)), in: .rect(cornerRadius: 24))
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 170)
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
            }

            bottomBar
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 4)
        .animation(.spring(duration: 0.35), value: game.encounter)
        .animation(.spring(duration: 0.35), value: game.toasts)
        .animation(.easeInOut(duration: 0.3), value: game.save.tutorialDone)
    }

    private var levelBadge: some View {
        Button {
            sheet = .level
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Color.orange.opacity(0.9), Color.pink.opacity(0.85)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .padding(4)
                    Circle()
                        .stroke(Color.white.opacity(0.35), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: game.levelProgress)
                        .stroke(AngularGradient(colors: [.yellow, .orange, .yellow], center: .center),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.4), value: game.levelProgress)
                    Text("\(game.save.level)")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                        .contentTransition(.numericText())
                }
                .frame(width: 46, height: 46)
                .overlay(alignment: .topTrailing) {
                    if game.hasPro {
                        Text("👑").font(.system(size: 14)).offset(x: 5, y: -7)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(game.save.current.spec.emoji) \(game.save.current.spec.name)")
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.12))
                        Capsule()
                            .fill(LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(4, 110 * game.levelProgress))
                            .animation(.easeOut(duration: 0.4), value: game.levelProgress)
                    }
                    .frame(width: 110, height: 5)
                    Text(game.save.level >= GameRules.maxLevel ? tr("level.max") : tr("hud.xp", Fmt.n(game.save.xp), Fmt.n(game.xpToNext)))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                .padding(.trailing, 8)
            }
            .padding(5)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    private var coinsPill: some View {
        HStack(spacing: 5) {
            Text("🪙").font(.system(size: 16))
            Text(Fmt.n(game.save.coins))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy, value: game.save.coins)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .glassEffect(.regular, in: .capsule)
    }

    private var backpackPill: some View {
        let count = game.backpackCount
        let capacity = game.stats.capacity
        let fraction = min(1, Double(count) / Double(max(1, capacity)))
        let color: Color = fraction >= 1 ? .red : (fraction > 0.8 ? .orange : .green)
        return HStack(spacing: 6) {
            Text("🎒").font(.system(size: 15))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.15))
                Capsule().fill(color.gradient).frame(width: 54 * fraction)
                    .animation(.easeOut(duration: 0.25), value: fraction)
            }
            .frame(width: 54, height: 7)
            Text("\(count)/\(capacity)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(fraction >= 1 ? Color.red : Color.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .glassEffect(.regular, in: .capsule)
        .scaleEffect(game.backpackFull ? 1.07 : 1)
        .animation(.spring(duration: 0.3, bounce: 0.5), value: game.backpackFull)
    }

    private var shopPill: some View {
        Button {
            sheet = .shop
        } label: {
            HStack(spacing: 5) {
                Text(game.starterAvailable ? "🎁" : "🛍️").font(.system(size: 15))
                if game.starterAvailable, let until = game.save.starterOfferUntil {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(Countdown.text(until.timeIntervalSince(context.date)))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.orange)
                    }
                } else {
                    Text(tr("shop.short")).font(.system(size: 12, weight: .bold))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
        .glassEffect(game.starterAvailable ? .regular.tint(Color.orange.opacity(0.35)).interactive() : .regular.interactive(), in: .capsule)
    }

    private var bottomBar: some View {
        HStack(spacing: 6) {
            HUDButton(icon: "📦", title: tr("hud.storage")) { sheet = .storage }
            HUDButton(icon: "🔨", title: tr("hud.workshop"), badge: workshopBadge) { sheet = .workshop }
            HUDButton(icon: "🌟", title: tr("hud.talents"), badge: game.talentPointsFree) { sheet = .talents }
            HUDButton(icon: "🐾", title: tr("hud.animals")) { sheet = .animals }
            HUDButton(icon: "📜", title: tr("hud.quests"), badge: game.claimableQuests + game.claimableAchievements) { sheet = .quests }
            HUDButton(icon: "🗺️", title: tr("hud.map"), badge: mapBadge) { sheet = .map }
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
        LocationID.allCases.filter { id in
            !game.isUnlocked(id) && game.save.level >= id.spec.level && game.canAfford(game.unlockCost(id))
        }.count
    }
}

struct HUDButton: View {
    let icon: String
    let title: String
    var badge: Int = 0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text(icon).font(.system(size: 24))
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
        .overlay(alignment: .topTrailing) {
            if badge > 0 {
                Text("\(badge)")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.red))
                    .offset(x: 3, y: -4)
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
                .font(.system(size: 13, weight: .semibold))
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .glassEffect(.regular, in: .capsule)
    }
}

struct TutorialCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(tr("tutorial.title")).font(.headline)
            Label(tr("tutorial.move"), systemImage: "hand.draw")
            Label(tr("tutorial.gather"), systemImage: "hammer")
            Label(tr("tutorial.deposit"), systemImage: "shippingbox")
        }
        .font(.system(size: 13, weight: .medium))
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
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
            Text(spec.emoji).font(.system(size: 44))
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(spec.name).font(.headline)
                    if stars > 0 { StarsView(stars: stars) }
                }
                Text(spec.effects.first?.text(multiplier: game.stats.starMultiplier(max(1, stars + 1)) * game.stats.animalMult) ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if let cost, stars < AnimalSpec.maxStars {
                    CostView(cost: cost)
                }
            }
            Spacer(minLength: 0)
            if stars >= AnimalSpec.maxStars {
                Text(tr("common.max")).font(.caption.bold()).foregroundStyle(.secondary)
            } else {
                Button(stars > 0 ? tr("tame.more") : tr("tame.action"), action: onTame)
                    .buttonStyle(.glassProminent)
                    .disabled(cost.map { !game.canAfford($0) } ?? true)
            }
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }
}
