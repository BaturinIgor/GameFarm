import SwiftUI

enum GameSheet: String, Identifiable {
    case storage, workshop, talents, animals, quests, map, level, shop, wardrobe
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
                chip(icon: AnyView(CoinIcon(size: 16)),
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
                .font(.game(13, .bold))
                .monospacedDigit()
                .foregroundStyle(ok ? Palette.good : Palette.bad)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(ok ? Color(hex: 0xDDEFC8) : Color(hex: 0xF6D3C8))
        )
        .overlay(Capsule().strokeBorder((ok ? Palette.good : Palette.bad).opacity(0.55), lineWidth: 1.5))
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
                Image(systemName: "star.fill")
                    .font(.system(size: size, weight: .black))
                    .foregroundStyle(i < stars ? Palette.gold : Palette.inkSoft.opacity(0.3))
                    .outlined(i < stars ? Palette.goldDark : .clear, width: 0.8)
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
                .font(.game(12, .bold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Palette.parchmentDeep))
        .overlay(Capsule().strokeBorder(Palette.woodDark.opacity(0.35), lineWidth: 1))
        .opacity(dimmed ? 0.5 : 1)
    }
}

/// Карточка в списках меню: светлый пергамент с тонкой рамкой.
struct Card<Content: View>: View {
    var tint: Color = .clear
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(Palette.parchmentLight))
        .overlay(shape.strokeBorder(tint == .clear ? Palette.woodDark.opacity(0.45) : tint, lineWidth: tint == .clear ? 1.5 : 2.5))
        .background(shape.fill(Palette.woodDark.opacity(0.25)).offset(y: 3))
    }
}

/// Заголовок раздела внутри окна.
struct SectionTitle: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Rectangle().fill(Palette.woodDark.opacity(0.35)).frame(height: 2)
            Text(text)
                .font(.game(14))
                .foregroundStyle(Palette.inkSoft)
                .textCase(.uppercase)
                .lineLimit(1)
                .fixedSize()
            Rectangle().fill(Palette.woodDark.opacity(0.35)).frame(height: 2)
        }
    }
}

struct CoinsBadge: View {
    let coins: Int

    var body: some View {
        HStack(spacing: 5) {
            CoinIcon(size: 18)
            Text(Fmt.n(coins))
                .font(.game(15))
                .foregroundStyle(.white)
                .outlined(Palette.outline, width: 1)
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
                .contentTransition(.numericText())
        }
        .padding(.leading, 6)
        .padding(.trailing, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Palette.woodDark))
        .overlay(Capsule().strokeBorder(Palette.outline, lineWidth: 2))
    }
}

extension View {
    /// Оформление окна меню: деревянная шапка и пергамент вместо системной панели.
    func sheetChrome(_ title: String, coins: Int) -> some View {
        self
            .toolbar(.hidden, for: .navigationBar)
            .scrollContentBackground(.hidden)
            .background(Palette.parchment)
            .safeAreaInset(edge: .top, spacing: 0) {
                WindowHeader(title: title, coins: coins)
            }
    }
}
