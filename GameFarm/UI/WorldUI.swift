import SwiftUI

/// Иконка зверя: пиксельный кадр из пака или эмодзи.
struct AnimalIcon: View {
    let id: AnimalID
    var size: CGFloat = 32

    var body: some View {
        if let image = Sprites.animalImage(id) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Text(id.spec.emoji).font(.system(size: size * 0.85))
        }
    }
}

/// Билет в экспедицию.
struct TicketIcon: View {
    var size: CGFloat = 20

    var body: some View {
        if let image = Sprites.icon(named: "ticket") {
            Image(uiImage: image)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Text("🎟️").font(.system(size: size * 0.85))
        }
    }
}

/// Карточка у закрытых ворот: куда ведут и что нужно, чтобы открыть.
struct GateCard: View {
    @Environment(GameState.self) private var game
    let gateID: String
    let onShop: () -> Void

    var body: some View {
        if let gate = WorldGraph.gate(gateID) {
            let target = gate.other(game.save.current)
            HStack(alignment: .top, spacing: 12) {
                Text(target.spec.emoji).font(.system(size: 40))
                VStack(alignment: .leading, spacing: 6) {
                    Text(tr("gate.to", target.spec.name)).font(.headline)
                    if gate.royal {
                        Text(tr("gate.royal")).font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button(action: onShop) {
                            Text(tr("garden.more")).font(.subheadline.bold()).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.orange)
                    } else {
                        if gate.group != nil {
                            Text(tr("gate.bundle.short")).font(.caption).foregroundStyle(.orange)
                        }
                        let levelOK = game.save.level >= gate.level
                        if !levelOK {
                            Text(tr("common.needLevel", gate.level)).font(.caption.bold()).foregroundStyle(.red)
                        }
                        CostView(cost: game.gateCost(gate))
                        Button {
                            withAnimation(.spring(duration: 0.4)) {
                                if game.openGate(gate.id) {
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                }
                            }
                        } label: {
                            Text(tr("gate.open")).font(.subheadline.bold()).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(!game.canOpenGate(gate))
                    }
                }
            }
            .padding(12)
            .glassEffect(.regular, in: .rect(cornerRadius: 22))
        }
    }
}

/// Таймер экспедиции сверху экрана.
struct ExpeditionPill: View {
    @Environment(GameState.self) private var game
    @State private var confirm = false

    var body: some View {
        if let run = game.save.expedition, run.id == game.save.current {
            HStack(spacing: 8) {
                Text(run.id?.spec.emoji ?? "🧭").font(.system(size: 18))
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let left = max(0, run.endsAt.timeIntervalSince(context.date))
                    Text(Countdown.text(left))
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(left < 30 ? Color.red : Color.primary)
                }
                Button {
                    confirm = true
                } label: {
                    Text(tr("exp.leave")).font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .glassEffect(.regular.tint(Color.yellow.opacity(0.25)), in: .capsule)
            .confirmationDialog(tr("exp.leave.confirm"), isPresented: $confirm, titleVisibility: .visible) {
                Button(tr("exp.leave"), role: .destructive) { game.finishExpedition() }
                Button(tr("common.cancel"), role: .cancel) {}
            }
        }
    }
}

/// Итог экспедиции.
struct ExpeditionReportOverlay: View {
    let report: ExpeditionReport
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
                .onTapGesture(perform: onClose)
            ConfettiView()
                .ignoresSafeArea()
                .allowsHitTesting(false)
            VStack(spacing: 14) {
                Text(report.location.spec.emoji).font(.system(size: 50))
                Text(tr("exp.done"))
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                Text(report.location.spec.name).font(.subheadline).foregroundStyle(.secondary)
                if report.items.isEmpty && report.coins == 0 {
                    Text(tr("exp.empty")).font(.subheadline).foregroundStyle(.secondary)
                } else {
                    FlowLayout(spacing: 8) {
                        if report.coins > 0 {
                            HStack(spacing: 5) {
                                Text("🪙")
                                Text("+\(Fmt.n(report.coins))").font(.system(size: 16, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.yellow.opacity(0.2)))
                        }
                        ForEach(report.items) { item in
                            HStack(spacing: 5) {
                                ResourceIcon(kind: item.kind, size: 24)
                                Text("+\(Fmt.n(item.amount))").font(.system(size: 16, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.green.opacity(0.15)))
                        }
                    }
                    Text(tr("offline.inStorage")).font(.caption).foregroundStyle(.secondary)
                }
                Button(tr("common.great"), action: onClose)
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
            }
            .padding(22)
            .frame(maxWidth: 360)
            .glassEffect(.regular, in: .rect(cornerRadius: 28))
            .padding(24)
        }
    }
}

/// Королевский сундук открыт.
struct RoyalChestCard: View {
    let treasure: Treasure

    var body: some View {
        VStack(spacing: 8) {
            Text("👑 " + tr("garden.chestTitle"))
                .font(.system(size: 22, weight: .heavy, design: .rounded))
            FlowLayout(spacing: 10) {
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
                HStack(spacing: 3) {
                    TicketIcon(size: 20)
                    Text("+1").font(.system(size: 16, weight: .bold, design: .rounded))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: 340)
        .glassEffect(.regular.tint(Color.orange.opacity(0.3)), in: .rect(cornerRadius: 24))
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 170)
    }
}
