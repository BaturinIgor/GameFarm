import SwiftUI

struct WorkshopView: View {
    @Environment(GameState.self) private var game

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Text("Чем лучше инструмент, тем сильнее удар и тем более ценные ресурсы можно добыть.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(ToolKind.upgradable) { tool in
                        ToolCard(tool: tool)
                    }
                    Card {
                        HStack(spacing: 10) {
                            Text("✋").font(.system(size: 30))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Руки").font(.headline)
                                Text("Ягоды, яблоки, грибы и морковь собираются без инструмента. Сила сбора растёт с уровнем и талантом \"Крепкие руки\".")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .sheetChrome("Мастерская", coins: game.save.coins)
        }
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
                Text(tool.emoji)
                    .font(.system(size: 34))
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(color.opacity(0.25)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(ToolTier.name(tool, tier: tier))
                        .font(.headline)
                    Text("Ступень \(tier) из \(ToolTier.maxTier)  ·  сила \(String(format: "%.1f", ToolTier.power(tier)).replacingOccurrences(of: ".", with: ","))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(tool.purpose)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            let available = nodes(for: tier, exact: false)
            if !available.isEmpty {
                Text("Добывает").font(.caption.bold()).foregroundStyle(.secondary)
                FlowLayout(spacing: 6) {
                    ForEach(available, id: \.self) { NodeChip(type: $0) }
                }
            }

            if next <= ToolTier.maxTier, let cost = game.nextToolCost(tool) {
                Divider()
                let needLevel = ToolTier.requiredLevel(tool, tier: next)
                let levelOK = game.save.level >= needLevel
                HStack {
                    Text("Дальше: \(ToolTier.name(tool, tier: next))")
                        .font(.subheadline.bold())
                    Spacer()
                    Text("Ур. \(needLevel)")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(levelOK ? Color.green.opacity(0.18) : Color.red.opacity(0.15)))
                        .foregroundStyle(levelOK ? Color.primary : Color.red)
                }
                let opens = nodes(for: next, exact: true)
                if !opens.isEmpty {
                    HStack(spacing: 6) {
                        Text("Откроет:").font(.caption).foregroundStyle(.secondary)
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
                    Text(levelOK ? "Улучшить" : "Нужен уровень \(needLevel)")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(!levelOK || !game.canAfford(cost))
            } else {
                Divider()
                Label("Максимальная ступень", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)
            }
        }
    }
}
