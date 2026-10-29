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
        ScrollView {
            VStack(spacing: 14) {
                slots
                GameTabs(selection: $tab, items: Tab.allCases.map { ($0, $0.title) })

                switch tab {
                case .mine:
                    if owned.isEmpty {
                        Card {
                            Text(tr("animals.empty")).font(.game(16))
                            Text(tr("animals.empty.hint"))
                                .font(.game(14, .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    ForEach(owned) { AnimalRow(id: $0, mode: .mine) }
                case .shop:
                    ForEach(shopAnimals) { AnimalRow(id: $0, mode: .shop) }
                case .wild:
                    Text(tr("animals.wild.hint"))
                        .font(.game(14, .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(wildAnimals) { AnimalRow(id: $0, mode: .wild) }
                }
            }
            .padding(16)
        }
        .sheetChrome(tr("hud.animals"), coins: game.save.coins)
    }

    private var slots: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tr("animals.withYou", game.save.active.count, game.maxActive))
                .font(.game(14, .semibold).bold())
            HStack(spacing: 8) {
                ForEach(0..<game.maxActive, id: \.self) { i in
                    let id = i < game.save.active.count ? game.save.active[i] : nil
                    Button {
                        if let id {
                            withAnimation(.spring(duration: 0.3)) { _ = game.toggleActive(id) }
                        }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(id == nil ? Palette.parchmentDeep.opacity(0.6) : Color(hex: 0xDDEFC8))
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(id == nil ? Palette.woodDark.opacity(0.4) : Palette.outline,
                                              style: StrokeStyle(lineWidth: id == nil ? 1.5 : 2, dash: id == nil ? [5, 4] : []))
                            if let id {
                                AnimalIcon(id: id, size: 40)
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .black))
                                    .foregroundStyle(.white)
                                    .frame(width: 16, height: 16)
                                    .background(Circle().fill(ButtonTone.red.base))
                                    .overlay(Circle().strokeBorder(Palette.outline, lineWidth: 1.5))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                    .padding(4)
                            } else {
                                Image(systemName: "plus")
                                    .font(.game(16))
                                    .foregroundStyle(Palette.woodDark.opacity(0.5))
                            }
                        }
                        .frame(height: 58)
                    }
                    .buttonStyle(.press)
                    .disabled(id == nil)
                }
            }
            Text(tr("animals.slots.hint"))
                .font(.game(12, .semibold))
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
        Card(tint: game.isActive(id) ? ButtonTone.green.base : .clear) {
            HStack(alignment: .top, spacing: 12) {
                AnimalIcon(id: id, size: 46)
                    .frame(width: 58, height: 58)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.parchmentDeep.opacity(0.7)))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.woodDark.opacity(0.4), lineWidth: 1.5))
                    .opacity(stars == 0 && mode == .wild ? 0.6 : 1)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(spec.name).font(.game(16))
                        if game.isShiny(id) { PixelIcon(name: "rainbow", size: 16) }
                        Text(spec.role)
                            .font(.game(10, .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Palette.parchmentDeep))
                            .overlay(Capsule().strokeBorder(Palette.woodDark.opacity(0.35), lineWidth: 1))
                    }
                    if stars > 0 {
                        HStack(spacing: 6) {
                            StarsView(stars: stars)
                            if game.awakenLevel(id) > 0 {
                                Text(Awakening.title(game.awakenLevel(id)))
                                    .font(.game(10))
                                    .foregroundStyle(Palette.ink)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(Color(hex: Awakening.colorHex(game.awakenLevel(id)))))
                                    .overlay(Capsule().strokeBorder(Palette.outline, lineWidth: 1))
                            }
                        }
                    }
                    ForEach(Array(spec.effects.enumerated()), id: \.offset) { item in
                        Text(item.element.text(multiplier: multiplier))
                            .font(.game(12, .semibold))
                            .foregroundStyle(.secondary)
                    }
                    if let location = spec.wildLocation {
                        Text(tr("animals.where", "", location.spec.name).replacingOccurrences(of: "  ", with: " "))
                            .font(.game(12, .semibold).bold())
                            .foregroundStyle(game.isUnlocked(location) ? Palette.ink : ButtonTone.orange.lip)
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
            if let cost = game.awakenCost(id) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(tr("awaken.next", Awakening.title(game.awakenLevel(id) + 1)))
                        .font(.game(12))
                        .foregroundStyle(ButtonTone.purple.lip)
                    CostView(cost: cost)
                    Button {
                        withAnimation(.spring(duration: 0.35)) { game.awakenAnimal(id) }
                    } label: {
                        Label(tr("awaken.action"), systemImage: "sparkles")
                    }
                    .buttonStyle(.game(.purple, small: true, wide: true))
                    .disabled(!game.canAwaken(id))
                }
            }
            let active = game.isActive(id)
            let full = game.save.active.count >= game.maxActive
            Button {
                withAnimation(.spring(duration: 0.3)) { _ = game.toggleActive(id) }
            } label: {
                Text(active ? tr("animals.remove") : (full ? tr("animals.full") : tr("animals.take")))
            }
            .buttonStyle(.game(active ? .red : .green, small: true, wide: true))
            .disabled(!active && full)
        case .shop:
            if let level = spec.shopLevel {
                if stars >= AnimalSpec.maxStars {
                    Label(tr("animals.maxStars"), systemImage: "checkmark.seal.fill")
                        .font(.game(14))
                        .foregroundStyle(Palette.good)
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
                            CoinIcon(size: 18)
                            Text(Fmt.n(price)).monospacedDigit()
                        }
                    }
                    .buttonStyle(.game(.green, wide: true))
                    .disabled(!levelOK || game.save.coins < price)
                }
            }
        case .wild:
            if stars >= AnimalSpec.maxStars {
                Label(tr("animals.maxStars"), systemImage: "checkmark.seal.fill")
                    .font(.game(14))
                    .foregroundStyle(Palette.good)
            } else if let cost = game.tameCost(id) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(stars > 0 ? tr("animals.nextStarCost") : tr("animals.tameCost"))
                        .font(.game(12, .semibold))
                        .foregroundStyle(.secondary)
                    CostView(cost: cost)
                }
            }
        }
    }
}
