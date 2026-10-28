import SwiftUI

/// Карточка у грядок: все грядки, выбор семян и кнопки "посадить" и "собрать".
struct BedsCard: View {
    @Environment(GameState.self) private var game
    let onShop: () -> Void
    var onShed: () -> Void = {}

    var body: some View {
        let owned = CropID.allCases.filter { game.seeds($0) > 0 }
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                PixelIcon(name: "seed_wheat", size: 20, fallback: "🌱")
                Text(tr("beds.title")).font(.game(15))
                Spacer(minLength: 4)
                Text(tr("beds.count", game.bedCount, Garden.maxBeds)).font(.game(12))
            }
            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack(spacing: 3) {
                    ForEach(0..<Garden.maxBeds, id: \.self) { i in
                        BedTile(index: i, now: context.date)
                    }
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
                            let selected = game.chosenSeed == crop
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
                Text(game.chosenSeed.map { tr("beds.chosen", $0.name, Fmt.seconds($0.spec.growTime)) } ?? tr("beds.pick"))
                    .font(.game(11, .semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            let ferts = FertilizerID.allCases.filter { game.fertilizers($0) > 0 }
            if !ferts.isEmpty {
                HStack(spacing: 6) {
                    ForEach(ferts) { id in
                        let selected = game.chosenFertilizer == id
                        Button {
                            game.selectFertilizer(selected ? nil : id)
                            UISelectionFeedbackGenerator().selectionChanged()
                        } label: {
                            HStack(spacing: 3) {
                                PixelIcon(name: id.icon, size: 20)
                                Text("\(game.fertilizers(id))").font(.game(13)).monospacedDigit()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(selected ? Color(hex: 0xC8EBA0) : Palette.parchmentLight))
                            .overlay(Capsule().strokeBorder(selected ? Palette.outline : Palette.woodDark.opacity(0.4),
                                                            lineWidth: selected ? 2 : 1.5))
                        }
                        .buttonStyle(.press)
                    }
                    Spacer(minLength: 0)
                    if game.chosenFertilizer != nil {
                        Button {
                            game.fertilizeAll()
                        } label: {
                            Text(tr("beds.fertAll", game.fertilizableBeds))
                        }
                        .buttonStyle(.game(.purple, small: true))
                        .disabled(game.fertilizableBeds == 0)
                    }
                }
            }
            HStack(spacing: 8) {
                let empty = game.emptyBeds
                let can = game.chosenSeed.map { min(empty, game.seeds($0)) } ?? 0
                Button {
                    game.plantAll()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Text(tr("beds.plantAll", can))
                }
                .buttonStyle(.game(.green, small: true, wide: true))
                .disabled(can == 0)
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    let ripe = game.ripeBeds
                    Button {
                        game.harvestAll()
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } label: {
                        Text(tr("beds.harvestAll", ripe))
                    }
                    .buttonStyle(.game(.orange, small: true, wide: true))
                    .disabled(ripe == 0)
                }
                Button(action: onShed) {
                    PixelIcon(name: "watering_can", size: 18)
                }
                .buttonStyle(.game(.blue, small: true))
                Button(action: onShop) {
                    Image(systemName: "cart.fill")
                }
                .buttonStyle(.game(.wood, small: true))
            }
        }
        .foregroundStyle(Palette.ink)
        .padding(12)
        .gamePanel(radius: 18, border: 3)
    }
}

/// Маленькая клетка грядки: пусто, растёт, созрело или закрыто.
private struct BedTile: View {
    @Environment(GameState.self) private var game
    let index: Int
    let now: Date

    var body: some View {
        let bed = game.bed(index)
        let locked = index >= game.bedCount
        let ripe = bed.isRipe(at: now)
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        Button {
            if ripe {
                if game.harvestOne(index) { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
            } else if !bed.isEmpty, game.chosenFertilizer != nil {
                if game.fertilize(index) { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
            } else if bed.isEmpty, !locked {
                if game.plant(index) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } else {
                    game.toast("px:sprout", tr(game.totalSeeds == 0 ? "toast.noSeeds" : "beds.pick"))
                }
            }
        } label: {
            ZStack(alignment: .bottom) {
                shape.fill(locked ? Palette.parchmentDeep.opacity(0.5) : (ripe ? Color(hex: 0xC8EBA0) : Color(hex: 0xC99A6E)))
                if locked {
                    Image(systemName: "lock.fill").font(.system(size: 8, weight: .bold)).foregroundStyle(Palette.woodDark.opacity(0.5))
                        .frame(maxHeight: .infinity)
                } else if let crop = bed.crop {
                    Group {
                        if ripe {
                            ResourceIcon(kind: crop.spec.produce, size: 18)
                        } else {
                            PixelIcon(name: crop.seedIcon, size: 18, fallback: "🌱")
                        }
                    }
                    .frame(maxHeight: .infinity)
                    if bed.fertilized == true && !ripe {
                        Circle().fill(ButtonTone.purple.top).frame(width: 6, height: 6)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .padding(3)
                    }
                    if !ripe {
                        GeometryReader { geo in
                            Rectangle().fill(ButtonTone.green.base)
                                .frame(width: geo.size.width * bed.progress(at: now), height: 3)
                        }
                        .frame(height: 3)
                    }
                } else {
                    Image(systemName: "plus").font(.system(size: 9, weight: .black)).foregroundStyle(.white.opacity(0.85))
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .clipShape(shape)
            .overlay(shape.strokeBorder(ripe ? ButtonTone.green.base : Palette.outline.opacity(locked ? 0.25 : 0.6), lineWidth: ripe ? 2 : 1.2))
        }
        .buttonStyle(.press)
        .disabled(locked)
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
