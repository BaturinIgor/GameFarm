import SwiftUI

/// Карта мира: локации и проходы между ними, экспедиции и королевский сад.
struct MapView: View {
    @Environment(GameState.self) private var game
    let onTravel: () -> Void
    var onShop: () -> Void = {}
    @State private var selected: LocationID?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    WorldMapGraph(selected: $selected)
                    if let id = selected ?? Optional(game.save.current), id.spec.kind == .world {
                        LocationCard(id: id, onTravel: onTravel)
                            .id(id)
                            .transition(.opacity)
                    }
                    ExpeditionsCard(onTravel: onTravel)
                    GardenMapCard(onTravel: onTravel, onShop: onShop)
                }
                .padding(16)
                .animation(.spring(duration: 0.3), value: selected)
            }
            .sheetChrome(tr("hud.map"), coins: game.save.coins)
        }
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
                    .stroke(open ? Color.green.opacity(0.75) : Color.secondary.opacity(known ? 0.55 : 0.2),
                            style: StrokeStyle(lineWidth: open ? 6 : 3, lineCap: .round, dash: open ? [] : [6, 7]))
                    if !open && known {
                        let a = center(gate.a, in: size), b = center(gate.b, in: size)
                        Text(game.canOpenGate(gate) ? "🔓" : "🔒")
                            .font(.system(size: 13))
                            .padding(4)
                            .background(Circle().fill(Color(uiColor: .systemBackground)))
                            .position(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
                    }
                }
                ForEach(LocationID.world) { id in
                    node(id)
                        .position(center(id, in: size))
                }
            }
        }
        .frame(height: 420)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [Color.green.opacity(0.16), Color.blue.opacity(0.12), Color.purple.opacity(0.12)],
                                     startPoint: .bottom, endPoint: .top))
        )
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
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .fill(Color(uiColor: spec.ground).gradient)
                        .overlay(Circle().strokeBorder(here ? Color.yellow : (isSelected ? Color.white : Color.black.opacity(0.25)),
                                                       lineWidth: here || isSelected ? 3 : 1.5))
                        .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                    Text(spec.emoji).font(.system(size: 28))
                        .saturation(unlocked ? 1 : 0)
                        .opacity(unlocked ? 1 : 0.55)
                    if !unlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(5)
                            .background(Circle().fill(Color.black.opacity(0.55)))
                            .offset(x: 20, y: 20)
                    }
                }
                .frame(width: 60, height: 60)
                Text(spec.name)
                    .font(.system(size: 11, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: 96)
                    .foregroundStyle(unlocked ? Color.primary : Color.secondary)
            }
        }
        .buttonStyle(.plain)
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
                        Text(spec.name).font(.headline)
                        if !unlocked { Image(systemName: "lock.fill").font(.system(size: 12, weight: .bold)) }
                    }
                    Text(spec.blurb)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            FlowLayout(spacing: 5) {
                ForEach(spec.resources) { kind in
                    ResourceIcon(kind: kind, size: 22)
                        .padding(4)
                        .background(Circle().fill(Color.secondary.opacity(0.12)))
                }
                ForEach(spec.wild) { animal in
                    AnimalIcon(id: animal, size: 22)
                        .padding(4)
                        .background(Circle().fill(Color.pink.opacity(0.14)))
                        .opacity(game.stars(animal) > 0 ? 1 : 0.55)
                }
            }

            if here {
                Label(tr("map.here"), systemImage: "mappin.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)
            } else if unlocked {
                Button {
                    game.travel(to: id)
                    onTravel()
                } label: {
                    Text(tr("map.go")).font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(game.save.expedition != nil)
            }

            // Проходы этой локации
            let gates = WorldGraph.gates(of: id).filter { !$0.royal }
            ForEach(gates, id: \.id) { gate in
                GateRow(gate: gate, from: id)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(here ? Color.green.opacity(0.6) : ground.opacity(0.6), lineWidth: here ? 2 : 1.5)
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
            Divider()
            HStack(spacing: 6) {
                Text(open ? "🚪" : "🔒")
                Text(tr("gate.to", other.spec.emoji + " " + other.spec.name)).font(.subheadline.bold())
                Spacer()
                if open {
                    Text(tr("gate.open.done")).font(.caption.bold()).foregroundStyle(.green)
                } else {
                    let levelOK = game.save.level >= gate.level
                    Text(tr("common.lvl", gate.level))
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(levelOK ? Color.green.opacity(0.18) : Color.red.opacity(0.15)))
                        .foregroundStyle(levelOK ? Color.primary : Color.red)
                }
            }
            if !open && known {
                if gate.group != nil {
                    let names = WorldGraph.bundle(gate).map { "\($0.a.spec.emoji)↔\($0.b.spec.emoji)" }.joined(separator: "  ")
                    Text(tr("gate.bundle", names)).font(.caption).foregroundStyle(.secondary)
                }
                if game.reachable.contains(gate.a) && game.reachable.contains(gate.b) {
                    Text(tr("gate.shortcut")).font(.caption).foregroundStyle(.secondary)
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
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .disabled(!game.canOpenGate(gate))
            } else if !open {
                Text(tr("gate.far")).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

/// Экспедиции по билетам.
struct ExpeditionsCard: View {
    @Environment(GameState.self) private var game
    let onTravel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🧭 " + tr("exp.title")).font(.title3.bold())
                Spacer()
                HStack(spacing: 4) {
                    TicketIcon(size: 20)
                    Text("\(game.save.tickets)").font(.headline).monospacedDigit()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.yellow.opacity(0.2)))
            }
            Text(tr("exp.subtitle", Int(Expedition.duration / 60)))
                .font(.caption)
                .foregroundStyle(.secondary)
            if game.freeTicketReady {
                Button {
                    game.claimFreeTicket()
                } label: {
                    Label(tr("exp.freeTicket"), systemImage: "gift.fill").font(.subheadline.bold()).frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(.orange)
            } else if let next = game.nextFreeTicket {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Label(tr("exp.nextTicket", Countdown.text(next.timeIntervalSince(context.date))), systemImage: "clock")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(LocationID.expeditions) { id in
                HStack(spacing: 12) {
                    Text(id.spec.emoji).font(.system(size: 34))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(id.spec.name).font(.subheadline.bold())
                        Text(Expedition.perk(id)).font(.caption).foregroundStyle(.secondary)
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
                        .font(.subheadline.bold())
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(game.save.tickets <= 0 || game.save.expedition != nil)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.secondary.opacity(0.08)))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [Color.yellow.opacity(0.18), Color.orange.opacity(0.1)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
    }
}

/// Королевский сад: переход или предложение купить.
struct GardenMapCard: View {
    @Environment(GameState.self) private var game
    let onTravel: () -> Void
    let onShop: () -> Void

    var body: some View {
        let owned = game.owns(.garden)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("🏰").font(.system(size: 36))
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocationID.garden.spec.name).font(.headline)
                    Text(LocationID.garden.spec.blurb).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if owned {
                if game.gardenChestReady {
                    Label(tr("garden.chestReady"), systemImage: "crown.fill").font(.caption.bold()).foregroundStyle(.orange)
                } else if let at = game.save.gardenChestAt {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Label(tr("garden.chestIn", Countdown.text(at.timeIntervalSince(context.date))), systemImage: "clock")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                }
                if game.save.current == .garden {
                    Label(tr("map.here"), systemImage: "mappin.circle.fill").font(.subheadline.bold()).foregroundStyle(.green)
                } else {
                    Button {
                        game.travel(to: .garden)
                        onTravel()
                    } label: {
                        Text(tr("map.go")).font(.headline).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.orange)
                    .disabled(game.save.expedition != nil)
                }
            } else {
                Button(action: onShop) {
                    Text(tr("garden.more")).font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(.orange)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [Color.yellow.opacity(0.25), Color.green.opacity(0.15)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.orange.opacity(0.5), lineWidth: 1.5))
    }
}
