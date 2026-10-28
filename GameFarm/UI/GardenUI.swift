import SwiftUI

/// Карточка у грядок: какие семена сажать и что уже созрело.
struct BedsCard: View {
    @Environment(GameState.self) private var game
    let onShop: () -> Void

    var body: some View {
        let owned = CropID.allCases.filter { game.seeds($0) > 0 }
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("🌱 " + tr("beds.title")).font(.game(15))
                Spacer(minLength: 4)
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    HStack(spacing: 6) {
                        Text(tr("beds.count", game.bedCount, Garden.maxBeds))
                        if game.ripeBeds > 0 {
                            Text(tr("beds.ripe", game.ripeBeds)).foregroundStyle(Palette.good)
                        }
                    }
                    .font(.game(12))
                }
            }
            if owned.isEmpty {
                Text(tr("beds.noSeeds"))
                    .font(.game(12, .semibold))
                    .foregroundStyle(ButtonTone.orange.lip)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(owned) { crop in
                            let selected = game.save.selectedSeed == crop
                            Button {
                                game.selectSeed(crop)
                                UISelectionFeedbackGenerator().selectionChanged()
                            } label: {
                                HStack(spacing: 3) {
                                    PixelIcon(name: crop.seedIcon, size: 22, fallback: "🌱")
                                    Text("\(game.seeds(crop))").font(.game(13)).monospacedDigit()
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(selected ? Palette.gold : Palette.parchmentLight))
                                .overlay(Capsule().strokeBorder(selected ? Palette.outline : Palette.woodDark.opacity(0.4),
                                                                lineWidth: selected ? 2 : 1.5))
                            }
                            .buttonStyle(.press)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            HStack(spacing: 8) {
                Text(tr("beds.hint"))
                    .font(.game(11, .semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button(action: onShop) {
                    Label(tr("beds.shop"), systemImage: "cart.fill")
                }
                .buttonStyle(.game(.green, small: true))
            }
        }
        .foregroundStyle(Palette.ink)
        .padding(12)
        .gamePanel(radius: 18, border: 3)
    }
}

/// Карточка рядом с торговцем.
struct TraderCard: View {
    let kind: TraderKind
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            NPCPortrait(name: kind == .stall ? "merchant" : "wanderer", size: 52)
            Text(kind == .stall ? tr("trader.near") : tr("wanderer.near"))
                .font(.game(14))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button(action: onOpen) {
                Text(tr("trader.open"))
            }
            .buttonStyle(.game(kind == .stall ? .orange : .purple))
        }
        .foregroundStyle(Palette.ink)
        .padding(12)
        .gamePanel(radius: 18, border: 3)
    }
}
