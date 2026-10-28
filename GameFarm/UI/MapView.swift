import SwiftUI

/// Карта мира: локации и проходы между ними, экспедиции и королевский сад.
struct MapView: View {
    @Environment(GameState.self) private var game
    @Environment(\.gameActions) private var actions
    let onTravel: () -> Void
    var onShop: () -> Void = {}
    @State private var selected: LocationID?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                WorldMapGraph(selected: $selected)
                if let id = selected ?? Optional(game.save.current), id.spec.kind == .world {
                    LocationCard(id: id, onTravel: onTravel)
                        .id(id)
                        .transition(.opacity)
                }
                EventMapCard(onTravel: onTravel, onOpen: { actions.open(.events) })
                ExpeditionsCard(onTravel: onTravel)
                GardenMapCard(onTravel: onTravel, onShop: onShop)
            }
            .padding(16)
            .animation(.spring(duration: 0.3), value: selected)
        }
        .sheetChrome(tr("hud.map"), coins: game.save.coins)
    }
}

/// Схема мира: кружки локаций и дорожки проходов.
struct WorldMapGraph: View {
    @Environment(GameState.self) private var game
    @Binding var selected: LocationID?

    private let cols = 3
    private let rows = 4

    private func center(_ id: LocationID, in size: CGSize) -> CGPoint {
        let spec = id.spec
        let cw = size.width / CGFloat(cols)
        let rh = size.height / CGFloat(rows)
        return CGPoint(x: (CGFloat(spec.mapX) + 0.5) * cw, y: size.height - (CGFloat(spec.mapY) + 0.5) * rh)
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                ForEach(WorldGraph.gates.filter { !$0.royal }, id: \.id) { gate in
                    let open = game.isGateOpen(gate.id)
                    let known = game.reachable.contains(gate.a) || game.reachable.contains(gate.b)
                    Path { path in
                        path.move(to: center(gate.a, in: size))
                        path.addLine(to: center(gate.b, in: size))
                    }
                    .stroke(open ? Palette.outline : Palette.woodDark.opacity(known ? 0.5 : 0.18),
                            style: StrokeStyle(lineWidth: open ? 9 : 3, lineCap: .round, dash: open ? [] : [5, 7]))
                    if open {
                        Path { path in
                            path.move(to: center(gate.a, in: size))
                            path.addLine(to: center(gate.b, in: size))
                        }
                        .stroke(Color(hex: 0xE2B77A), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    }
                    if !open && known {
                        let a = center(gate.a, in: size), b = center(gate.b, in: size)
                        Image(systemName: game.canOpenGate(gate) ? "lock.open.fill" : "lock.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(game.canOpenGate(gate) ? Palette.good : Palette.woodDark)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(game.canOpenGate(gate) ? Palette.gold : Palette.parchmentLight))
                            .overlay(Circle().strokeBorder(Palette.outline, lineWidth: 1.5))
                            .position(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
                    }
                }
                ForEach(LocationID.world) { id in
                    node(id)
                        .position(center(id, in: size))
                }
            }
        }
        .frame(height: 440)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Palette.parchmentDeep)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Palette.woodDark.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                .padding(6)
        )
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.outline, lineWidth: 2))
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.woodDark.opacity(0.3)).offset(y: 3))
    }

    private func node(_ id: LocationID) -> some View {
        let spec = id.spec
        let unlocked = game.isUnlocked(id)
        let here = game.save.current == id
        let isSelected = (selected ?? game.save.current) == id
        return Button {
            withAnimation(.spring(duration: 0.3)) { selected = id }
            SoundFX.play(.tap)
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Palette.outline.opacity(0.45))
                        .offset(y: 3)
                    Image(uiImage: MiniMap.image(id, framed: false))
                        .resizable()
                        .interpolation(.medium)
                        .scaledToFill()
                        .frame(width: 58, height: 58)
                        .saturation(unlocked ? 1 : 0)
                        .opacity(unlocked ? 1 : 0.6)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Text(spec.emoji).font(.system(size: 24))
                        .saturation(unlocked ? 1 : 0)
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(here ? Palette.gold : (isSelected ? Color.white : Palette.outline),
                                      lineWidth: here || isSelected ? 3.5 : 2)
                    if here || isSelected {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Palette.outline, lineWidth: 1.5)
                            .padding(-2)
                    }
                    if !unlocked {
                        Image(systemName: "lock.fill")
                            .font(.game(11, .bold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Palette.woodDark))
                            .overlay(Circle().strokeBorder(Palette.outline, lineWidth: 1.5))
                            .offset(x: 24, y: 24)
                    }
                    if here {
                        SkinIcon(skin: game.currentSkin, size: 24)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Palette.parchmentLight))
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(Palette.outline, lineWidth: 2))
                            .offset(x: 24, y: -26)
                    }
                }
                .frame(width: 58, height: 58)
                Text(spec.name)
                    .font(.game(11))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(unlocked ? Palette.parchmentLight : Palette.parchmentDeep))
                    .overlay(Capsule().strokeBorder(Palette.woodDark.opacity(0.5), lineWidth: 1))
                    .frame(maxWidth: 104)
                    .foregroundStyle(unlocked ? Palette.ink : Palette.inkSoft)
            }
        }
        .buttonStyle(.press)
    }
}

struct LocationCard: View {
    @Environment(GameState.self) private var game
    let id: LocationID
    let onTravel: () -> Void

    var body: some View {
        let spec = id.spec
        let unlocked = game.isUnlocked(id)
        let here = game.save.current == id
        let ground = Color(uiColor: spec.ground)

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(spec.emoji).font(.system(size: 40))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(spec.name).font(.game(16))
                        if !unlocked { Image(systemName: "lock.fill").font(.game(12, .bold)) }
                    }
                    Text(spec.blurb)
                        .font(.game(12, .semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            FlowLayout(spacing: 5) {
                ForEach(spec.resources) { kind in
                    ResourceIcon(kind: kind, size: 22)
                        .padding(4)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Palette.parchmentDeep.opacity(0.7)))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Palette.woodDark.opacity(0.3), lineWidth: 1))
                }
                ForEach(spec.wild) { animal in
                    AnimalIcon(id: animal, size: 22)
                        .padding(4)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(hex: 0xF6D9E0)))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Palette.woodDark.opacity(0.3), lineWidth: 1))
                        .opacity(game.stars(animal) > 0 ? 1 : 0.55)
                }
            }

            if here {
                Label(tr("map.here"), systemImage: "mappin.circle.fill")
                    .font(.game(14))
                    .foregroundStyle(Palette.good)
            } else if unlocked {
                Button {
                    game.travel(to: id)
                    onTravel()
                } label: {
                    Text(tr("map.go"))
                }
                .buttonStyle(.game(.green, wide: true))
                .disabled(game.save.expedition != nil)
            }

            // Проходы этой локации
            let gates = WorldGraph.gates(of: id).filter { !$0.royal }
            ForEach(gates, id: \.id) { gate in
                GateRow(gate: gate, from: id)
            }
        }
        .padding(14)
        .listBox(radius: 18)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(here ? ButtonTone.green.base : ground, lineWidth: 2.5)
        )
    }
}

/// Строка прохода: куда ведёт, открыт ли, сколько стоит.
struct GateRow: View {
    @Environment(GameState.self) private var game
    let gate: GateSpec
    let from: LocationID

    var body: some View {
        let other = gate.other(from)
        let open = game.isGateOpen(gate.id)
        let known = game.reachable.contains(gate.a) || game.reachable.contains(gate.b)
        VStack(alignment: .leading, spacing: 8) {
            PaperDivider()
            HStack(spacing: 6) {
                if open { PixelIcon(name: "door", size: 18) } else { Image(systemName: "lock.fill").foregroundStyle(Palette.woodDark) }
                Text(tr("gate.to", other.spec.name)).font(.game(14))
                Spacer()
                if open {
                    Text(tr("gate.open.done")).font(.game(12)).foregroundStyle(Palette.good)
                } else {
                    LevelTag(level: gate.level, ok: game.save.level >= gate.level)
                }
            }
            if !open && known {
                if gate.group != nil {
                    let names = WorldGraph.bundle(gate).map { "\($0.a.spec.emoji)↔\($0.b.spec.emoji)" }.joined(separator: "  ")
                    Text(tr("gate.bundle", names)).font(.game(12, .semibold)).foregroundStyle(.secondary)
                }
                if game.reachable.contains(gate.a) && game.reachable.contains(gate.b) {
                    Text(tr("gate.shortcut")).font(.game(12, .semibold)).foregroundStyle(.secondary)
                }
                CostView(cost: game.gateCost(gate))
                Button {
                    withAnimation(.spring(duration: 0.4)) {
                        if game.openGate(gate.id) {
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    }
                } label: {
                    Text(game.save.level >= gate.level ? tr("gate.open") : tr("common.needLevel", gate.level))
                }
                .buttonStyle(.game(.green, wide: true))
                .disabled(!game.canOpenGate(gate))
            } else if !open {
                Text(tr("gate.far")).font(.game(12, .semibold)).foregroundStyle(.secondary)
            }
        }
    }
}

/// Экспедиции по билетам.
struct ExpeditionsCard: View {
    @Environment(GameState.self) private var game
    let onTravel: () -> Void

    var body: some View {
        ShopCard(title: tr("exp.title"), tone: .blue) {
            HStack(alignment: .top) {
                Text(tr("exp.subtitle", Int(Expedition.duration / 60)))
                    .font(.game(12, .semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                HStack(spacing: 4) {
                    TicketIcon(size: 20)
                    Text("\(game.save.tickets)").font(.game(16)).monospacedDigit()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Palette.parchmentDeep))
                .overlay(Capsule().strokeBorder(Palette.woodDark.opacity(0.5), lineWidth: 1.5))
            }
            if game.freeTicketReady {
                Button {
                    game.claimFreeTicket()
                } label: {
                    Label(tr("exp.freeTicket"), systemImage: "gift.fill")
                }
                .buttonStyle(.game(.orange, wide: true))
            } else if let next = game.nextFreeTicket {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Label(tr("exp.nextTicket", Countdown.text(next.timeIntervalSince(context.date))), systemImage: "clock")
                        .font(.game(12, .semibold).bold())
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(LocationID.expeditions) { id in
                HStack(spacing: 12) {
                    Text(id.spec.emoji).font(.system(size: 34))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(id.spec.name).font(.game(14, .semibold).bold())
                        Text(Expedition.perk(id)).font(.game(12, .semibold)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Button {
                        if game.startExpedition(id) { onTravel() }
                    } label: {
                        HStack(spacing: 3) {
                            Text(tr("exp.go"))
                            TicketIcon(size: 14)
                        }
                    }
                    .buttonStyle(.game(.green, small: true))
                    .disabled(game.save.tickets <= 0 || game.save.expedition != nil)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.parchmentDeep.opacity(0.55)))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.woodDark.opacity(0.3), lineWidth: 1))
            }
        }
    }
}

/// Королевский сад: переход или предложение купить.
struct GardenMapCard: View {
    @Environment(GameState.self) private var game
    let onTravel: () -> Void
    let onShop: () -> Void

    var body: some View {
        let owned = game.owns(.garden)
        ShopCard(title: LocationID.garden.spec.name, tone: .gold) {
            Text(LocationID.garden.spec.blurb).font(.game(12, .semibold)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if owned {
                if game.gardenChestReady {
                    Label(tr("garden.chestReady"), systemImage: "crown.fill").font(.game(12)).foregroundStyle(ButtonTone.orange.lip)
                } else if let at = game.save.gardenChestAt {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Label(tr("garden.chestIn", Countdown.text(at.timeIntervalSince(context.date))), systemImage: "clock")
                            .font(.game(12, .semibold).bold())
                            .foregroundStyle(.secondary)
                    }
                }
                if game.save.current == .garden {
                    Label(tr("map.here"), systemImage: "mappin.circle.fill").font(.game(14)).foregroundStyle(Palette.good)
                } else {
                    Button {
                        game.travel(to: .garden)
                        onTravel()
                    } label: {
                        Text(tr("map.go"))
                    }
                    .buttonStyle(.game(.orange, wide: true))
                    .disabled(game.save.expedition != nil)
                }
            } else {
                Button(action: onShop) {
                    Text(tr("garden.more"))
                }
                .buttonStyle(.game(.orange, wide: true))
            }
        }
    }
}
