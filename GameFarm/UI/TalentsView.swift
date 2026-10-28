import SwiftUI

struct TalentsView: View {
    @Environment(GameState.self) private var game
    @State private var branch: TalentBranch = .mining
    @State private var selected: TalentID?

    var body: some View {
        VStack(spacing: 0) {
            header
            branchPicker
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            GeometryReader { geo in
                ScrollView {
                    TalentTreeCanvas(branch: branch, width: geo.size.width, selected: $selected)
                        .padding(.bottom, 20)
                        .id(branch)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
                .background(
                    LinearGradient(colors: [branch.color.opacity(0.10), Color.clear],
                                   startPoint: .top, endPoint: .bottom)
                )
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let id = selected {
                TalentDetail(id: id)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: selected)
        .onChange(of: branch) { _, _ in selected = nil }
        .sheetChrome(tr("hud.talents"), coins: game.save.coins)
    }

    private var branchPicker: some View {
        HStack(spacing: 6) {
            ForEach(TalentBranch.allCases) { b in
                let active = b == branch
                Button {
                    withAnimation(.spring(duration: 0.3)) { branch = b }
                } label: {
                    VStack(spacing: 2) {
                        Text(b.emoji).font(.system(size: 20))
                        Text(b.title)
                            .font(.game(11, .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("\(game.pointsSpent(in: b))")
                            .font(.game(10, .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .background(Capsule().fill(active ? Palette.woodDark : Palette.inkSoft.opacity(0.6)))
                    }
                    .foregroundStyle(active ? Color.white : Palette.ink)
                    .outlined(active ? Palette.outline : .clear, width: 1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(active ? b.color : Palette.parchmentLight)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(active ? Palette.outline : Palette.woodDark.opacity(0.4), lineWidth: active ? 2 : 1.5)
                    )
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.woodDark.opacity(0.3)).offset(y: 3))
                }
                .buttonStyle(.press)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tr("talents.free", game.talentPointsFree))
                    .font(.game(16))
                Text(tr("talents.hint"))
                    .font(.game(12, .semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Dialogs.shared.confirm(tr("talents.reset.confirm"), message: tr("talents.reset.message"), icon: "🔄",
                                       confirm: tr("talents.reset.action", Fmt.n(game.respecCost)), tone: .orange) {
                    game.resetTalents()
                    selected = nil
                }
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.game(15, .black))
            }
            .buttonStyle(.game(.wood, small: true))
            .disabled(game.talentPointsSpent == 0 || game.save.coins < game.respecCost)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

/// Дерево ветки: узлы по рядам и линии от родителей к детям.
struct TalentTreeCanvas: View {
    @Environment(GameState.self) private var game
    let branch: TalentBranch
    let width: CGFloat
    @Binding var selected: TalentID?

    private let rowHeight: CGFloat = 112
    private let top: CGFloat = 50
    private let left: CGFloat = 54

    private func position(_ spec: TalentSpec) -> CGPoint {
        let columnWidth = (width - left - 12) / 3
        return CGPoint(x: left + columnWidth * (CGFloat(spec.column) + 0.5), y: top + CGFloat(spec.tier) * rowHeight)
    }

    /// Линия между талантами идёт от края круга до края круга, а не через центр.
    private func edgePoints(from a: CGPoint, to b: CGPoint) -> (CGPoint, CGPoint) {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let d = max(hypot(dx, dy), 1)
        let r = TalentNode.radius + 3
        guard d > r * 2 else { return (a, a) }
        let ux = dx / d
        let uy = dy / d
        return (CGPoint(x: a.x + ux * r, y: a.y + uy * r), CGPoint(x: b.x - ux * r, y: b.y - uy * r))
    }

    var body: some View {
        let talents = branch.talents
        let height = top + CGFloat(TalentSpec.tierLevels.count - 1) * rowHeight + 70
        ZStack(alignment: .topLeading) {
            ForEach(Array(TalentSpec.tierLevels.enumerated()), id: \.offset) { item in
                let reached = game.save.level >= item.element
                Text(tr("talents.rowLevel", item.element))
                    .font(.game(11, .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(reached ? Palette.ink : Palette.inkSoft)
                    .frame(width: 40)
                    .position(x: 26, y: top + CGFloat(item.offset) * rowHeight)
                Rectangle()
                    .fill(Palette.inkSoft.opacity(0.08))
                    .frame(width: max(0, width - 60), height: 1)
                    .position(x: 30 + (width - 60) / 2 + 12, y: top + CGFloat(item.offset) * rowHeight + rowHeight / 2)
            }

            ForEach(talents) { id in
                ForEach(id.spec.parents, id: \.self) { parent in
                    let active = game.rank(parent) > 0
                    let ends = edgePoints(from: position(parent.spec), to: position(id.spec))
                    Path { path in
                        path.move(to: ends.0)
                        path.addLine(to: ends.1)
                    }
                    .stroke(active ? branch.color : Palette.inkSoft.opacity(0.3),
                            style: StrokeStyle(lineWidth: active ? 4 : 3, lineCap: .round, dash: active ? [] : [6, 6]))
                }
            }

            ForEach(talents) { id in
                TalentNode(id: id, color: branch.color, isSelected: selected == id) {
                    selected = selected == id ? nil : id
                }
                .position(position(id.spec))
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
    }
}

struct TalentNode: View {
    @Environment(GameState.self) private var game
    let id: TalentID
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    static let radius: CGFloat = 30

    var body: some View {
        let spec = id.spec
        let rank = game.rank(id)
        let available = game.talentAvailable(id)
        let learnable = game.canLearn(id)
        let maxed = rank >= spec.maxRank
        Button(action: action) {
            // Центр круга совпадает с точкой узла, подпись ранга висит под кругом и не сдвигает его.
            ZStack {
                    Circle()
                        .fill(Palette.woodDark.opacity(0.35))
                        .offset(y: 3)
                    Circle()
                        .fill(rank > 0 ? color.mix(with: .white, by: 0.55) : Palette.parchmentLight)
                    Circle()
                        .strokeBorder(rank > 0 ? color : Palette.woodDark.opacity(0.35), lineWidth: 4)
                        .padding(2)
                    Circle()
                        .strokeBorder(isSelected ? Palette.gold : Palette.outline, lineWidth: isSelected ? 3 : 2)
                    Text(spec.emoji)
                        .font(.system(size: 26))
                        .grayscale(available ? 0 : 1)
                    if !available {
                        Image(systemName: "lock.fill")
                            .font(.game(11, .bold))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Circle().fill(Palette.woodDark))
                            .overlay(Circle().strokeBorder(Palette.outline, lineWidth: 1.5))
                            .offset(x: 20, y: -20)
                    } else if learnable {
                        Image(systemName: "plus")
                            .font(.game(11, .heavy))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Circle().fill(ButtonTone.green.base))
                            .overlay(Circle().strokeBorder(Palette.outline, lineWidth: 1.5))
                            .offset(x: 20, y: -20)
                    }
                }
                .frame(width: Self.radius * 2, height: Self.radius * 2)
                .overlay(alignment: .bottom) {
                    Text("\(rank)/\(spec.maxRank)")
                        .font(.game(11, .heavy))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(maxed ? color : Palette.parchmentLight))
                        .overlay(Capsule().strokeBorder(Palette.outline, lineWidth: 1.5))
                        .foregroundStyle(maxed ? Color.white : Palette.ink)
                        .fixedSize()
                        .offset(y: 20)
                }
            .opacity(available ? 1 : 0.55)
        }
        .buttonStyle(.plain)
    }
}

struct TalentDetail: View {
    @Environment(GameState.self) private var game
    let id: TalentID

    var body: some View {
        let spec = id.spec
        let rank = game.rank(id)
        let maxed = rank >= spec.maxRank
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(spec.emoji).font(.system(size: 30))
                VStack(alignment: .leading, spacing: 1) {
                    Text(spec.name).font(.game(16))
                    Text(tr("talents.rank", rank, spec.maxRank))
                        .font(.game(12, .semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            if rank > 0 {
                Text(tr("talents.now", spec.effect(at: rank)))
                    .font(.game(14, .semibold))
            }
            if !maxed {
                Text(rank > 0 ? tr("talents.next", spec.effect(at: rank + 1)) : spec.effect(at: 1))
                    .font(.game(14, .semibold))
                    .foregroundStyle(rank > 0 ? Palette.inkSoft : Palette.ink)
            }
            requirements(spec)
            if !maxed {
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        if game.learn(id) {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                    }
                } label: {
                    Text(game.talentPointsFree > 0 ? tr("talents.learn") : tr("talents.noPoints"))
                }
                .buttonStyle(.game(.green, wide: true))
                .disabled(!game.canLearn(id))
            }
        }
        .padding(16)
        .gamePanel(fill: Palette.parchmentLight, radius: 18, border: 3)
    }

    @ViewBuilder
    private func requirements(_ spec: TalentSpec) -> some View {
        let levelOK = game.save.level >= spec.requiredLevel
        let missing = spec.parents.filter { game.rank($0) == 0 }
        if !levelOK || !missing.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                if !levelOK {
                    Label(tr("common.needLevel", spec.requiredLevel), systemImage: "lock.fill")
                }
                ForEach(missing, id: \.self) { parent in
                    Label(tr("talents.needParent", parent.spec.name), systemImage: "arrow.up.circle")
                }
            }
            .font(.game(12))
            .foregroundStyle(ButtonTone.orange.lip)
        }
    }
}
