import SwiftUI

struct AnimalsView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case mine, shop, wild
        var id: String { rawValue }
        var title: String {
            switch self {
            case .mine: tr("animals.tab.mine")
            case .shop: tr("animals.tab.shop")
            case .wild: tr("animals.tab.wild")
            }
        }
    }

    @Environment(GameState.self) private var game
    @State private var tab: Tab = .mine

    private var owned: [AnimalID] { AnimalID.allCases.filter { game.stars($0) > 0 } }
    private var shopAnimals: [AnimalID] {
        AnimalID.allCases.filter { $0.spec.shopLevel != nil }
    }
    private var wildAnimals: [AnimalID] {
        AnimalID.allCases.filter { $0.spec.wildLocation != nil }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    slots
                    Picker(tr("common.section"), selection: $tab) {
                        ForEach(Tab.allCases) { t in Text(t.title).tag(t) }
                    }
                    .pickerStyle(.segmented)

                    switch tab {
                    case .mine:
                        if owned.isEmpty {
                            Card {
                                Text(tr("animals.empty")).font(.headline)
                                Text(tr("animals.empty.hint"))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        ForEach(owned) { AnimalRow(id: $0, mode: .mine) }
                    case .shop:
                        ForEach(shopAnimals) { AnimalRow(id: $0, mode: .shop) }
                    case .wild:
                        Text(tr("animals.wild.hint"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(wildAnimals) { AnimalRow(id: $0, mode: .wild) }
                    }
                }
                .padding(16)
            }
            .sheetChrome(tr("hud.animals"), coins: game.save.coins)
        }
    }

    private var slots: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tr("animals.withYou", game.save.active.count, GameRules.maxActiveAnimals))
                .font(.subheadline.bold())
            HStack(spacing: 8) {
                ForEach(0..<GameRules.maxActiveAnimals, id: \.self) { i in
                    let id = i < game.save.active.count ? game.save.active[i] : nil
                    Button {
                        if let id {
                            withAnimation(.spring(duration: 0.3)) { _ = game.toggleActive(id) }
                        }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(id == nil ? Color.secondary.opacity(0.1) : Color.green.opacity(0.18))
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(id == nil ? Color.secondary.opacity(0.3) : Color.green.opacity(0.6),
                                              style: StrokeStyle(lineWidth: 1.5, dash: id == nil ? [5, 4] : []))
                            if let id {
                                Text(id.spec.emoji).font(.system(size: 30))
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                    .padding(3)
                            } else {
                                Image(systemName: "plus")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(height: 58)
                    }
                    .buttonStyle(.plain)
                    .disabled(id == nil)
                }
            }
            Text(tr("animals.slots.hint"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct AnimalRow: View {
    enum Mode { case mine, shop, wild }

    @Environment(GameState.self) private var game
    let id: AnimalID
    let mode: Mode

    var body: some View {
        let spec = id.spec
        let stars = game.stars(id)
        let multiplier = game.stats.starMultiplier(max(1, stars)) * game.stats.animalMult
        Card(tint: game.isActive(id) ? .green : .clear) {
            HStack(alignment: .top, spacing: 12) {
                Text(spec.emoji)
                    .font(.system(size: 38))
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(Color.secondary.opacity(0.1)))
                    .opacity(stars == 0 && mode == .wild ? 0.6 : 1)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(spec.name).font(.headline)
                        Text(spec.role)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.secondary.opacity(0.15)))
                    }
                    if stars > 0 { StarsView(stars: stars) }
                    ForEach(Array(spec.effects.enumerated()), id: \.offset) { item in
                        Text(item.element.text(multiplier: multiplier))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let location = spec.wildLocation {
                        Text(tr("animals.where", location.spec.emoji, location.spec.name))
                            .font(.caption.bold())
                            .foregroundStyle(game.isUnlocked(location) ? Color.primary : Color.orange)
                    }
                }
                Spacer(minLength: 0)
            }
            actions(spec: spec, stars: stars)
        }
    }

    @ViewBuilder
    private func actions(spec: AnimalSpec, stars: Int) -> some View {
        switch mode {
        case .mine:
            let active = game.isActive(id)
            let full = game.save.active.count >= GameRules.maxActiveAnimals
            Button {
                withAnimation(.spring(duration: 0.3)) { _ = game.toggleActive(id) }
            } label: {
                Text(active ? tr("animals.remove") : (full ? tr("animals.full") : tr("animals.take")))
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(active ? .red : .green)
            .disabled(!active && full)
        case .shop:
            if let level = spec.shopLevel {
                if stars >= AnimalSpec.maxStars {
                    Label(tr("animals.maxStars"), systemImage: "checkmark.seal.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.green)
                } else if let price = game.shopPrice(id) {
                    let levelOK = game.save.level >= level
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            if game.buyAnimal(id) {
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            }
                        }
                    } label: {
                        HStack {
                            Text(!levelOK ? tr("common.needLevel", level) : (stars > 0 ? tr("animals.moreStar") : tr("common.buy")))
                            Spacer()
                            Text("🪙 \(Fmt.n(price))").monospacedDigit()
                        }
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(!levelOK || game.save.coins < price)
                }
            }
        case .wild:
            if stars >= AnimalSpec.maxStars {
                Label(tr("animals.maxStars"), systemImage: "checkmark.seal.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)
            } else if let cost = game.tameCost(id) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(stars > 0 ? tr("animals.nextStarCost") : tr("animals.tameCost"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    CostView(cost: cost)
                }
            }
        }
    }
}
