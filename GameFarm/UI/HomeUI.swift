import SwiftUI

/// Карточка внизу экрана в доме: станция, недостроенный этаж или место для украшения.
struct HomeCard: View {
    @Environment(GameState.self) private var game
    let prompt: HomePrompt
    let open: (GameSheet) -> Void
    let pickDecor: (String) -> Void

    var body: some View {
        HStack(spacing: 12) {
            content
        }
        .foregroundStyle(Palette.ink)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .gamePanel(radius: 18, border: 3)
    }

    @ViewBuilder
    private var content: some View {
        switch prompt {
        case .station(let station):
            PixelIcon(name: station.icon, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(station.title).font(.game(15))
                Text(station.hint)
                    .font(.game(11, .semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            stationButton(station)
        case .build(let floor):
            PixelIcon(name: "stairs", size: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(tr("home.build.title", floor.title)).font(.game(15))
                Text(floor.perk)
                    .font(.game(11, .semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if game.save.level >= floor.level {
                    CostView(cost: floor.cost)
                }
            }
            Spacer(minLength: 4)
            Button {
                if game.build(floor) { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            } label: {
                Text(game.save.level >= floor.level ? tr("house.build") : tr("common.needLevel", floor.level))
            }
            .buttonStyle(.game(.green, small: true))
            .disabled(!game.canBuild(floor))
        case .slot(let slot):
            if let decor = game.decor(at: slot) {
                PixelSprite(name: decor.sprite, scale: 1.2)
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(decor.name).font(.game(15))
                    Text(tr("decor.comfort", decor.comfort)).font(.game(11)).foregroundStyle(Palette.good)
                }
                Spacer(minLength: 4)
                Button {
                    Dialogs.shared.confirm(tr("decor.remove", decor.name), message: tr("decor.remove.message"), icon: "px:plan",
                                           confirm: tr("decor.remove.action"), tone: .red) {
                        game.removeDecor(at: slot)
                    }
                } label: {
                    Text(tr("decor.remove.action"))
                }
                .buttonStyle(.game(.red, small: true))
            } else {
                PixelIcon(name: "plan", size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("home.slot")).font(.game(15))
                    Text(tr("home.slot.hint", game.comfort))
                        .font(.game(11, .semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Button {
                    pickDecor(slot)
                } label: {
                    Text(tr("home.slot.action"))
                }
                .buttonStyle(.game(.green, small: true))
            }
        }
    }

    @ViewBuilder
    private func stationButton(_ station: HomeStation) -> some View {
        switch station {
        case .bed:
            Button {
                game.rest()
            } label: {
                Text(tr("home.bed.action"))
            }
            .buttonStyle(.game(.blue, small: true))
            .disabled(game.hpFraction >= 0.999)
        case .chest:
            if game.freeTicketReady {
                Button {
                    game.claimFreeTicket()
                } label: {
                    Text(tr("home.chest.action"))
                }
                .buttonStyle(.game(.orange, small: true))
            } else if let next = game.nextFreeTicket {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(Countdown.text(next.timeIntervalSince(context.date)))
                        .font(.game(13))
                        .monospacedDigit()
                        .foregroundStyle(Palette.inkSoft)
                }
            }
        default:
            Button {
                if let sheet = sheet(for: station) { open(sheet) }
            } label: {
                Text(tr("home.open"))
            }
            .buttonStyle(.game(.green, small: true))
        }
    }

    private func sheet(for station: HomeStation) -> GameSheet? {
        switch station {
        case .stove: .kitchen
        case .calendar: .calendar
        case .trophies: .trophies
        case .plan: .house
        case .wardrobe: .wardrobe
        case .desk: .talents
        case .lectern: .legacy
        case .pantry: .storage
        case .workbench, .anvil: .workshop
        case .telescope: .collection
        case .map: .map
        case .compost: .garden
        case .seedlings: .trader
        default: nil
        }
    }
}

/// Стена трофеев: какие уже висят и как получить остальные.
struct TrophyView: View {
    @Environment(GameState.self) private var game

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(Trophy.allCases) { trophy in
                    let earned = game.isEarned(trophy)
                    let progress = min(game.trophyProgress(trophy), trophy.target)
                    Card(tint: earned ? Palette.goldDark : .clear) {
                        HStack(spacing: 12) {
                            PixelSprite(name: trophy.sprite, scale: 2)
                                .frame(width: 52, height: 48)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.parchmentDeep.opacity(0.7)))
                                .opacity(earned ? 1 : 0.35)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(trophy.name).font(.game(15))
                                Text(trophy.condition).font(.game(11, .semibold)).foregroundStyle(.secondary)
                                if !earned {
                                    GameBar(value: Double(progress) / Double(trophy.target), tone: .orange, height: 12,
                                            label: "\(progress) / \(trophy.target)")
                                }
                            }
                            Spacer(minLength: 0)
                            if earned {
                                Image(systemName: "checkmark.seal.fill").font(.system(size: 22)).foregroundStyle(Palette.good)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .sheetChrome(tr("trophy.title"), coins: game.save.coins)
    }
}

/// Огородная мастерская: лейка и удобрения.
struct GardenShedView: View {
    @Environment(GameState.self) private var game

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                canCard
                SectionTitle(text: tr("fert.title"))
                ForEach(FertilizerID.allCases) { FertilizerRow(id: $0) }
                if game.isBuilt(.greenhouse) {
                    Label(tr("garden.greenhouse"), systemImage: "leaf.fill")
                        .font(.game(12, .semibold))
                        .foregroundStyle(Palette.good)
                } else {
                    Text(tr("garden.greenhouse.locked", HouseFloor.greenhouse.level))
                        .font(.game(11, .semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(16)
        }
        .sheetChrome(tr("garden.title"), coins: game.save.coins)
    }

    private var canCard: some View {
        let level = game.save.canLevel
        return Card(tint: ButtonTone.blue.base.opacity(0.7)) {
            HStack(spacing: 12) {
                PixelIcon(name: "watering_can", size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("can.title", level, WateringCan.maxLevel)).font(.game(15))
                    Text(tr("can.effect", Fmt.pct(WateringCan.boost(level))))
                        .font(.game(12, .semibold))
                        .foregroundStyle(.secondary)
                    if WateringCan.waterAll(level) {
                        Text(tr("can.all")).font(.game(11, .semibold)).foregroundStyle(Palette.good)
                    }
                }
                Spacer(minLength: 0)
            }
            if let cost = game.nextCanCost {
                let need = WateringCan.requiredLevel(level + 1)
                Text(tr("can.next", Fmt.pct(WateringCan.boost(level + 1))) + (WateringCan.waterAll(level + 1) && !WateringCan.waterAll(level) ? " " + tr("can.next.all") : ""))
                    .font(.game(11, .semibold))
                    .foregroundStyle(Palette.inkSoft)
                CostView(cost: cost)
                Button {
                    game.upgradeCan()
                } label: {
                    Text(game.save.level >= need ? tr("common.upgrade") : tr("common.needLevel", need))
                }
                .buttonStyle(.game(.blue, small: true, wide: true))
                .disabled(!game.canUpgradeCan())
            }
        }
    }
}

private struct FertilizerRow: View {
    @Environment(GameState.self) private var game
    let id: FertilizerID

    var body: some View {
        let open = game.save.level >= id.level
        Card {
            HStack(spacing: 12) {
                PixelIcon(name: id.icon, size: 40)
                    .opacity(open ? 1 : 0.4)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(id.name).font(.game(15))
                        Text("x\(game.fertilizers(id))").font(.game(13)).foregroundStyle(Palette.inkSoft)
                    }
                    Text(id.effectText).font(.game(11, .semibold)).foregroundStyle(Palette.good)
                }
                Spacer(minLength: 0)
            }
            if open {
                CostView(cost: id.recipe)
                HStack(spacing: 8) {
                    Button {
                        game.craft(id)
                    } label: {
                        Text(tr("fert.make", 1))
                    }
                    .buttonStyle(.game(.green, small: true, wide: true))
                    .disabled(!game.canCraft(id))
                    Button {
                        game.craft(id, count: 5)
                    } label: {
                        Text(tr("fert.make", 5))
                    }
                    .buttonStyle(.game(.green, small: true, wide: true))
                    .disabled(!game.canCraft(id, count: 5))
                }
            } else {
                Label(tr("common.needLevel", id.level), systemImage: "lock.fill")
                    .font(.game(12, .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
