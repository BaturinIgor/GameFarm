import SwiftUI

struct TalentsView: View {
    @Environment(GameState.self) private var game
    @State private var branch: TalentBranch = .mining
    @State private var selected: TalentID?
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
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
            .confirmationDialog(tr("talents.reset.confirm"), isPresented: $confirmReset, titleVisibility: .visible) {
                Button(tr("talents.reset.action", Fmt.n(game.respecCost)), role: .destructive) {
                    game.resetTalents()
                    selected = nil
                }
            } message: {
                Text(tr("talents.reset.message"))
            }
        }
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
                            .font(.system(size: 11, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("\(game.pointsSpent(in: b))")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(active ? Color.white : Color.secondary)
                            .padding(.horizontal, 6)
                            .background(Capsule().fill(active ? b.color : Color.secondary.opacity(0.15)))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(active ? b.color.opacity(0.22) : Color(uiColor: .secondarySystemGroupedBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(active ? b.color : Color.clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tr("talents.free", game.talentPointsFree))
                    .font(.headline)
                Text(tr("talents.hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                confirmReset = true
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 15, weight: .bold))
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
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

    var body: some View {
        let talents = branch.talents
        let height = top + CGFloat(TalentSpec.tierLevels.count - 1) * rowHeight + 70
        ZStack(alignment: .topLeading) {
            ForEach(Array(TalentSpec.tierLevels.enumerated()), id: \.offset) { item in
                let reached = game.save.level >= item.element
                Text(tr("talents.rowLevel", item.element))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(reached ? Color.primary : Color.secondary)
                    .frame(width: 40)
                    .position(x: 26, y: top + CGFloat(item.offset) * rowHeight)
                Rectangle()
                    .fill(Color.secondary.opacity(0.08))
                    .frame(width: max(0, width - 60), height: 1)
                    .position(x: 30 + (width - 60) / 2 + 12, y: top + CGFloat(item.offset) * rowHeight + rowHeight / 2)
            }

            ForEach(talents) { id in
                ForEach(id.spec.parents, id: \.self) { parent in
                    let active = game.rank(parent) > 0
                    Path { path in
                        path.move(to: position(parent.spec))
                        path.addLine(to: position(id.spec))
                    }
                    .stroke(active ? branch.color : Color.secondary.opacity(0.3),
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

    var body: some View {
        let spec = id.spec
        let rank = game.rank(id)
        let available = game.talentAvailable(id)
        let learnable = game.canLearn(id)
        let maxed = rank >= spec.maxRank
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(rank > 0 ? color.opacity(0.25) : Color(uiColor: .secondarySystemGroupedBackground))
                    Circle()
                        .strokeBorder(rank > 0 ? color : Color.secondary.opacity(0.35), lineWidth: isSelected ? 4 : 2.5)
                    Text(spec.emoji)
                        .font(.system(size: 26))
                        .grayscale(available ? 0 : 1)
                    if !available {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Circle().fill(Color.black.opacity(0.55)))
                            .offset(x: 20, y: -20)
                    } else if learnable {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Circle().fill(Color.green))
                            .offset(x: 20, y: -20)
                    }
                }
                .frame(width: 60, height: 60)
                .shadow(color: rank > 0 ? color.opacity(0.4) : .clear, radius: 8)

                Text("\(rank)/\(spec.maxRank)")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(maxed ? color : Color.secondary.opacity(0.18)))
                    .foregroundStyle(maxed ? Color.white : Color.primary)
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
                    Text(spec.name).font(.headline)
                    Text(tr("talents.rank", rank, spec.maxRank))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            if rank > 0 {
                Text(tr("talents.now", spec.effect(at: rank)))
                    .font(.subheadline)
            }
            if !maxed {
                Text(rank > 0 ? tr("talents.next", spec.effect(at: rank + 1)) : spec.effect(at: 1))
                    .font(.subheadline)
                    .foregroundStyle(rank > 0 ? Color.secondary : Color.primary)
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
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(!game.canLearn(id))
            }
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
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
            .font(.caption.bold())
            .foregroundStyle(.orange)
        }
    }
}
