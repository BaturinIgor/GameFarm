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
                Image(uiImage: MiniMap.image(target, framed: false))
                    .resizable()
                    .interpolation(.medium)
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(Text(target.spec.emoji).font(.system(size: 24)))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.outline, lineWidth: 2))
                VStack(alignment: .leading, spacing: 6) {
                    Text(tr("gate.to", target.spec.name)).font(.game(16))
                    if gate.royal {
                        Text(tr("gate.royal")).font(.game(12, .semibold)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button(action: onShop) {
                            Text(tr("garden.more"))
                        }
                        .buttonStyle(.game(.orange, small: true, wide: true))
                    } else {
                        if gate.group != nil {
                            Text(tr("gate.bundle.short")).font(.game(12)).foregroundStyle(ButtonTone.orange.lip)
                        }
                        let levelOK = game.save.level >= gate.level
                        if !levelOK {
                            Text(tr("common.needLevel", gate.level)).font(.game(12)).foregroundStyle(Palette.bad)
                        }
                        CostView(cost: game.gateCost(gate))
                        Button {
                            withAnimation(.spring(duration: 0.4)) {
                                if game.openGate(gate.id) {
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                }
                            }
                        } label: {
                            Text(tr("gate.open"))
                        }
                        .buttonStyle(.game(.green, small: true, wide: true))
                        .disabled(!game.canOpenGate(gate))
                    }
                }
            }
            .foregroundStyle(Palette.ink)
            .padding(12)
            .gamePanel(radius: 18, border: 3)
        }
    }
}

/// Таймер экспедиции сверху экрана.
struct ExpeditionPill: View {
    @Environment(GameState.self) private var game

    var body: some View {
        if let run = game.save.expedition, run.id == game.save.current {
            HStack(spacing: 8) {
                Text(run.id?.spec.emoji ?? "🧭").font(.system(size: 18))
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let left = max(0, run.endsAt.timeIntervalSince(context.date))
                    Text(Countdown.text(left))
                        .font(.game(16))
                        .monospacedDigit()
                        .foregroundStyle(left < 30 ? Color(hex: 0xFF8A7A) : .white)
                        .outlined(Palette.outline, width: 1)
                }
                Button {
                    Dialogs.shared.confirm(tr("exp.leave.confirm"), icon: "🧭", confirm: tr("exp.leave"), tone: .red) {
                        game.finishExpedition()
                    }
                } label: {
                    Text(tr("exp.leave"))
                }
                .buttonStyle(.game(.red, small: true))
            }
            .padding(.leading, 12)
            .padding(.trailing, 6)
            .padding(.vertical, 5)
            .woodPill(radius: 16)
        }
    }
}

/// Итог экспедиции.
struct ExpeditionReportOverlay: View {
    let report: ExpeditionReport
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Palette.dim.ignoresSafeArea()
                .onTapGesture(perform: onClose)
            ConfettiView()
                .ignoresSafeArea()
                .allowsHitTesting(false)
            VStack(spacing: 14) {
                Text(report.location.spec.emoji).font(.system(size: 50))
                    .padding(.top, 12)
                Text(report.location.spec.name).font(.game(15)).foregroundStyle(.secondary)
                if report.items.isEmpty && report.coins == 0 {
                    Text(tr("exp.empty")).font(.game(14, .semibold)).foregroundStyle(.secondary)
                } else {
                    FlowLayout(spacing: 8) {
                        if report.coins > 0 {
                            RewardChip(text: "+\(Fmt.n(report.coins))") { CoinIcon(size: 22) }
                        }
                        ForEach(report.items) { item in
                            RewardChip(text: "+\(Fmt.n(item.amount))") { ResourceIcon(kind: item.kind, size: 24) }
                        }
                    }
                    Text(tr("offline.inStorage")).font(.game(12, .semibold)).foregroundStyle(.secondary)
                }
                Button(tr("common.great"), action: onClose)
                    .buttonStyle(.game(.green, wide: true))
            }
            .foregroundStyle(Palette.ink)
            .padding(22)
            .frame(maxWidth: 360)
            .gamePanel()
            .overlay(alignment: .top) {
                RibbonTitle(text: tr("exp.done"), tone: .blue, size: 20)
                    .padding(.horizontal, 20)
                    .offset(y: -18)
            }
            .padding(24)
        }
    }
}

/// Королевский сундук открыт.
struct RoyalChestCard: View {
    let treasure: Treasure

    var body: some View {
        VStack(spacing: 8) {
            FlowLayout(spacing: 10) {
                HStack(spacing: 3) {
                    CoinIcon(size: 20)
                    Text("+\(Fmt.n(treasure.coins))").font(.game(16, .bold))
                }
                ForEach(treasure.items) { item in
                    HStack(spacing: 3) {
                        ResourceIcon(kind: item.kind, size: 22)
                        Text("+\(Fmt.n(item.amount))").font(.game(16, .bold))
                    }
                }
                HStack(spacing: 3) {
                    TicketIcon(size: 20)
                    Text("+1").font(.game(16, .bold))
                }
            }
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 14)
        .frame(maxWidth: 340)
        .gamePanel(fill: Palette.parchmentLight, frame: Palette.gold, radius: 18, border: 3)
        .overlay(alignment: .top) {
            RibbonTitle(text: "👑 " + tr("garden.chestTitle"), tone: .gold, size: 17).offset(y: -16)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 180)
    }
}

/// Крупная карта текущей локации: форма, ресурсы, склад, проходы и где стоит персонаж.
struct BigMapOverlay: View {
    @Environment(GameState.self) private var game
    let player: CGPoint
    let onWorldMap: () -> Void
    let onClose: () -> Void

    private struct LegendItem: Identifiable {
        let type: NodeType
        let kind: ResourceKind
        var id: ResourceKind { kind }
    }

    /// Ресурсы локации по цвету точки на карте (без повторов).
    private var legend: [LegendItem] {
        var seen = Set<ResourceKind>()
        var out: [LegendItem] = []
        for type in game.save.current.layout.nodeTypes {
            let kind = type.spec.mainResource
            if seen.insert(kind).inserted { out.append(LegendItem(type: type, kind: kind)) }
        }
        return out
    }

    var body: some View {
        let id = game.save.current
        let layout = id.layout
        let aspect = CGFloat(layout.cols) / CGFloat(max(1, layout.rows))
        ZStack {
            Palette.dim.ignoresSafeArea()
                .onTapGesture(perform: onClose)
            VStack(spacing: 12) {
                GeometryReader { geo in
                    let w = min(geo.size.width, geo.size.height * aspect)
                    let h = w / aspect
                    ZStack(alignment: .topLeading) {
                        Image(uiImage: MiniMap.image(id, framed: false))
                            .resizable()
                            .interpolation(.none)
                            .frame(width: w, height: h)
                        SkinIcon(skin: game.currentSkin, size: 24)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Palette.parchmentLight))
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(Palette.outline, lineWidth: 2))
                            .position(x: player.x / max(1, layout.size.width) * w,
                                      y: (1 - player.y / max(1, layout.size.height)) * h - 10)
                    }
                    .frame(width: w, height: h)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.outline, lineWidth: 2.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: 400)
                .padding(.top, 14)

                FlowLayout(spacing: 6) {
                    ForEach(legend) { item in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(uiColor: MiniMap.dotColor(item.type)))
                                .overlay(Circle().strokeBorder(Palette.outline, lineWidth: 1.5))
                                .frame(width: 11, height: 11)
                            ResourceIcon(kind: item.kind, size: 20)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Palette.parchmentLight))
                        .overlay(Capsule().strokeBorder(Palette.woodDark.opacity(0.35), lineWidth: 1))
                    }
                    HStack(spacing: 4) {
                        Text("🏠").font(.system(size: 14))
                        Text(tr("hud.storage")).font(.game(12))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Palette.parchmentLight))
                    .overlay(Capsule().strokeBorder(Palette.woodDark.opacity(0.35), lineWidth: 1))
                    HStack(spacing: 4) {
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Palette.gold)
                            .outlined(Palette.outline, width: 1)
                        Text("🚪").font(.system(size: 14))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Palette.parchmentLight))
                    .overlay(Capsule().strokeBorder(Palette.woodDark.opacity(0.35), lineWidth: 1))
                }
                .foregroundStyle(Palette.ink)

                HStack(spacing: 10) {
                    Button(action: onClose) {
                        Text(tr("common.close"))
                    }
                    .buttonStyle(.game(.wood, wide: true))
                    Button(action: onWorldMap) {
                        Label(tr("hud.map"), systemImage: "globe.europe.africa.fill")
                    }
                    .buttonStyle(.game(.blue, wide: true))
                }
            }
            .padding(16)
            .frame(maxWidth: 400)
            .gamePanel()
            .overlay(alignment: .top) {
                RibbonTitle(text: "\(id.spec.emoji) \(id.spec.name)", tone: .green, size: 18)
                    .padding(.horizontal, 24)
                    .offset(y: -18)
            }
            .padding(20)
        }
    }
}
