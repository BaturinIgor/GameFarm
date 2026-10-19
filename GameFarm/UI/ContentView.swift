import SpriteKit
import SwiftUI

struct ContentView: View {
    @Environment(GameState.self) private var game
    @State private var scene = GameScene(size: CGSize(width: 390, height: 844))
    @State private var sheet: GameSheet?

    var body: some View {
        ZStack {
            SpriteView(scene: scene, preferredFramesPerSecond: 60, options: [.ignoresSiblingOrder])
                .ignoresSafeArea()

            HUDView(scene: scene, sheet: $sheet)

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
        .animation(.spring(duration: 0.35), value: game.levelUp)
        .animation(.spring(duration: 0.35), value: game.offlineReport)
        .sheet(item: $sheet) { which in
            Group {
                switch which {
                case .storage: StorageView()
                case .workshop: WorkshopView()
                case .talents: TalentsView()
                case .animals: AnimalsView()
                case .map: MapView { sheet = nil }
                case .level: LevelView()
                }
            }
            .environment(game)
            .presentationDragIndicator(.visible)
        }
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
                        .stroke(Color.white.opacity(0.3), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: game.levelProgress)
                        .stroke(Color.yellow, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(game.save.level)")
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .contentTransition(.numericText())
                }
                .frame(width: 46, height: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(game.save.current.spec.emoji) \(game.save.current.spec.name)")
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)
                    Text(game.save.level >= GameRules.maxLevel ? "Максимальный уровень" : "\(Fmt.n(game.save.xp)) / \(Fmt.n(game.xpToNext)) опыта")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .padding(.trailing, 6)
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
                Capsule().fill(color).frame(width: 54 * fraction)
            }
            .frame(width: 54, height: 7)
            Text("\(count)/\(capacity)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(fraction >= 1 ? Color.red : Color.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .glassEffect(.regular, in: .capsule)
        .scaleEffect(game.backpackFull ? 1.06 : 1)
        .animation(.spring(duration: 0.3), value: game.backpackFull)
    }

    private var bottomBar: some View {
        HStack(spacing: 7) {
            HUDButton(icon: "📦", title: "Склад") { sheet = .storage }
            HUDButton(icon: "🔨", title: "Мастерская", badge: workshopBadge) { sheet = .workshop }
            HUDButton(icon: "🌟", title: "Таланты", badge: game.talentPointsFree) { sheet = .talents }
            HUDButton(icon: "🐾", title: "Звери") { sheet = .animals }
            HUDButton(icon: "🗺️", title: "Карта", badge: mapBadge) { sheet = .map }
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
                Text(icon).font(.system(size: 25))
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
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
            Text("Как играть").font(.headline)
            Label("Веди пальцем по экрану, чтобы бегать", systemImage: "hand.draw")
            Label("Подойди к ресурсу, и персонаж начнёт добывать сам", systemImage: "hammer")
            Label("Полный рюкзак отнеси на склад 📦 в центре площадки", systemImage: "shippingbox")
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
                Text(spec.effects.first?.text(multiplier: AnimalSpec.starMultiplier(max(1, stars + 1))) ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if let cost, stars < AnimalSpec.maxStars {
                    CostView(cost: cost)
                }
            }
            Spacer(minLength: 0)
            if stars >= AnimalSpec.maxStars {
                Text("Максимум").font(.caption.bold()).foregroundStyle(.secondary)
            } else {
                Button(stars > 0 ? "Ещё ★" : "Приручить", action: onTame)
                    .buttonStyle(.glassProminent)
                    .disabled(cost.map { !game.canAfford($0) } ?? true)
            }
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }
}
