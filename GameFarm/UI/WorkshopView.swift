import SwiftUI

struct WorkshopView: View {
    @Environment(GameState.self) private var game

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text(tr("workshop.hint"))
                    .font(.game(14, .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(ToolKind.upgradable) { tool in
                    ToolCard(tool: tool)
                }
                Card {
                    HStack(spacing: 10) {
                        Text("✋").font(.system(size: 30))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tr("tool.hand")).font(.game(16))
                            Text(tr("workshop.hands"))
                                .font(.game(12, .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(16)
        }
        .sheetChrome(tr("hud.workshop"), coins: game.save.coins)
    }
}

struct ToolCard: View {
    @Environment(GameState.self) private var game
    let tool: ToolKind

    private func nodes(for tier: Int, exact: Bool) -> [NodeType] {
        NodeType.allCases.filter { type in
            let spec = type.spec
            guard spec.tool == tool else { return false }
            return exact ? spec.tier == tier : spec.tier <= tier
        }
    }

    var body: some View {
        let tier = game.tier(tool)
        let next = tier + 1
        let color = Color(uiColor: ToolTier.color(tier))
        Card(tint: color) {
            HStack(spacing: 12) {
                PixelIcon(name: "tool_\(tool.rawValue)", size: 36, fallback: tool.emoji)
                    .frame(width: 58, height: 58)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(color.opacity(0.25)))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.outline.opacity(0.7), lineWidth: 2))
                VStack(alignment: .leading, spacing: 3) {
                    Text(ToolTier.name(tool, tier: tier))
                        .font(.game(16))
                    Text(tr("workshop.tier", tier, ToolTier.maxTier, Fmt.decimal(ToolTier.power(tier), digits: 1)))
                        .font(.game(12, .semibold))
                        .foregroundStyle(.secondary)
                    Text(tool.purpose)
                        .font(.game(12, .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            let available = nodes(for: tier, exact: false)
            if !available.isEmpty {
                Text(tr("workshop.gathers")).font(.game(12)).foregroundStyle(.secondary)
                FlowLayout(spacing: 6) {
                    ForEach(available, id: \.self) { NodeChip(type: $0) }
                }
            }

            if next <= ToolTier.maxTier, let cost = game.nextToolCost(tool) {
                PaperDivider()
                let needLevel = ToolTier.requiredLevel(tool, tier: next)
                let levelOK = game.save.level >= needLevel
                HStack {
                    Text(tr("talents.next", ToolTier.name(tool, tier: next)))
                        .font(.game(14, .semibold).bold())
                    Spacer()
                    LevelTag(level: needLevel, ok: levelOK)
                }
                let opens = nodes(for: next, exact: true)
                if !opens.isEmpty {
                    HStack(spacing: 6) {
                        Text(tr("workshop.opens")).font(.game(12, .semibold)).foregroundStyle(.secondary)
                        FlowLayout(spacing: 6) {
                            ForEach(opens, id: \.self) { NodeChip(type: $0) }
                        }
                    }
                }
                CostView(cost: cost)
                Button {
                    withAnimation(.spring(duration: 0.4)) {
                        if game.upgradeTool(tool) {
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    }
                } label: {
                    Text(levelOK ? tr("workshop.upgrade") : tr("common.needLevel", needLevel))
                }
                .buttonStyle(.game(.green, wide: true))
                .disabled(!levelOK || !game.canAfford(cost))
            } else {
                PaperDivider()
                Label(tr("workshop.maxTier"), systemImage: "checkmark.seal.fill")
                    .font(.game(14))
                    .foregroundStyle(Palette.good)
            }
        }
    }
}
