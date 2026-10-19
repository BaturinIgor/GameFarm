import SwiftUI

enum GameSheet: String, Identifiable {
    case storage, workshop, talents, animals, quests, map, level
    var id: String { rawValue }
}

struct ResourceIcon: View {
    let kind: ResourceKind
    var size: CGFloat = 24

    var body: some View {
        Image(uiImage: Art.icon(kind))
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

/// Стоимость: у каждого ресурса видно, сколько есть и сколько нужно.
struct CostView: View {
    @Environment(GameState.self) private var game
    let cost: Cost

    var body: some View {
        FlowLayout(spacing: 6) {
            if cost.coins > 0 {
                chip(icon: AnyView(Text("🪙").font(.system(size: 15))),
                     text: Fmt.n(cost.coins), ok: game.save.coins >= cost.coins)
            }
            ForEach(cost.items) { item in
                let have = game.amount(item.kind)
                chip(icon: AnyView(ResourceIcon(kind: item.kind, size: 18)),
                     text: "\(Fmt.n(min(have, item.amount)))/\(Fmt.n(item.amount))",
                     ok: have >= item.amount)
            }
        }
    }

    private func chip(icon: AnyView, text: String, ok: Bool) -> some View {
        HStack(spacing: 4) {
            icon
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ok ? Color.primary : Color.red)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(ok ? Color.green.opacity(0.14) : Color.red.opacity(0.12))
        )
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for view in subviews {
            let s = view.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let s = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + s.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
    }
}

struct StarsView: View {
    let stars: Int
    var size: CGFloat = 11

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<AnimalSpec.maxStars, id: \.self) { i in
                Image(systemName: i < stars ? "star.fill" : "star")
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(i < stars ? Color.yellow : Color.secondary.opacity(0.5))
            }
        }
    }
}

struct NodeChip: View {
    let type: NodeType
    var dimmed = false

    var body: some View {
        HStack(spacing: 4) {
            ResourceIcon(kind: type.spec.mainResource, size: 16)
            Text(type.spec.name)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.secondary.opacity(0.12)))
        .opacity(dimmed ? 0.5 : 1)
    }
}

/// Карточка в списках меню.
struct Card<Content: View>: View {
    var tint: Color = .clear
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(tint.opacity(0.35), lineWidth: tint == .clear ? 0 : 1.5)
        )
    }
}

struct CoinsBadge: View {
    let coins: Int

    var body: some View {
        HStack(spacing: 4) {
            Text("🪙")
            Text(Fmt.n(coins))
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.yellow.opacity(0.18)))
    }
}

struct SheetCloseButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
        }
        .accessibilityLabel("Закрыть")
    }
}

extension View {
    func sheetChrome(_ title: String, coins: Int) -> some View {
        self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { CoinsBadge(coins: coins) }
                ToolbarItem(placement: .topBarTrailing) { SheetCloseButton() }
            }
            .background(Color(uiColor: .systemGroupedBackground))
    }
}
