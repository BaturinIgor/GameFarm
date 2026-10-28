import SwiftUI

/// Коллекция карт: семь созвездий по пять карт. Копии поднимают звёзды карты,
/// полное созвездие даёт вечный бонус и новый образ героя.
struct CollectionView: View {
    @Environment(GameState.self) private var game

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 10) {
                    summary("px:cards", tr("collection.cards", game.cardsOwned, CardID.allCases.count))
                    summary("px:spark", tr("collection.done", ConstellationID.allCases.filter { game.isComplete($0) }.count,
                                    ConstellationID.allCases.count))
                }
                CollectionGuide()
                ForEach(ConstellationID.allCases) { ConstellationCard(constellation: $0) }
            }
            .padding(16)
        }
        .sheetChrome(tr("collection.title"), coins: game.save.coins)
    }

    private func summary(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            IconView(icon: icon, size: 22)
            Text(text).font(.game(14))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .listBox(radius: 12)
    }
}

private struct ConstellationCard: View {
    @Environment(GameState.self) private var game
    let constellation: ConstellationID

    var body: some View {
        let complete = game.isComplete(constellation)
        let bonus = ConstellationID.bonus(minStars: max(1, game.minStars(constellation)))
        VStack(alignment: .leading, spacing: 10) {
            sky(complete: complete)
            HStack(spacing: 6) {
                ForEach(constellation.cards) { CardTile(card: $0) }
            }
            HStack(spacing: 10) {
                SkinIcon(skin: constellation.skin, size: 34)
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Palette.parchmentDeep))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.outline.opacity(0.6), lineWidth: 1.5))
                    .grayscale(complete ? 0 : 1)
                    .opacity(complete ? 1 : 0.6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(constellation.bonusText(complete ? ConstellationID.bonus(minStars: game.minStars(constellation)) : bonus))
                        .font(.game(12))
                        .foregroundStyle(complete ? Palette.good : Palette.inkSoft)
                    Group {
                        if !complete {
                            let missing = constellation.cards.filter { game.cardCount($0) == 0 }.count
                            Text(tr("collection.missing", missing))
                        } else if game.minStars(constellation) < Cards.thresholds.count {
                            Text(tr("collection.nextStar", Fmt.pct(ConstellationID.bonus(minStars: game.minStars(constellation) + 1))))
                        } else {
                            Text(tr("collection.maxed"))
                        }
                    }
                    .font(.game(11, .semibold))
                    .foregroundStyle(.secondary)
                    Text(tr("collection.skin", constellation.skin.name))
                        .font(.game(11, .semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if complete {
                    Image(systemName: "checkmark.seal.fill").font(.game(20)).foregroundStyle(Palette.good)
                }
            }
        }
        .padding(12)
        .listBox(radius: 18)
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(complete ? Palette.gold : .clear, lineWidth: 2.5))
    }

    /// Ночное небо со звёздами созвездия: собранные карты горят золотом.
    private func sky(complete: Bool) -> some View {
        let cards = constellation.cards
        let shape = constellation.shape
        return GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [Color(hex: 0x10163A), Color(hex: 0x2A1F5A)], startPoint: .top, endPoint: .bottom)
                // Фоновые звёздочки (одни и те же для каждого созвездия)
                ForEach(0..<18, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(0.35))
                        .frame(width: 2, height: 2)
                        .position(x: w * CGFloat((i * 37 + 11) % 100) / 100, y: h * CGFloat((i * 53 + 7) % 100) / 100)
                }
                Path { path in
                    for i in 1..<shape.count {
                        let a = shape[i - 1], b = shape[i]
                        path.move(to: CGPoint(x: w * CGFloat(a.0), y: h * CGFloat(a.1)))
                        path.addLine(to: CGPoint(x: w * CGFloat(b.0), y: h * CGFloat(b.1)))
                    }
                }
                .stroke(complete ? Palette.gold.opacity(0.8) : Color.white.opacity(0.22),
                        style: StrokeStyle(lineWidth: complete ? 2 : 1.2, dash: complete ? [] : [4, 4]))
                ForEach(Array(cards.enumerated()), id: \.offset) { i, card in
                    let owned = game.cardCount(card) > 0
                    let p = shape[min(i, shape.count - 1)]
                    Image(systemName: "star.fill")
                        .font(.system(size: owned ? 14 + CGFloat(game.cardStars(card)) * 1.5 : 10, weight: .black))
                        .foregroundStyle(owned ? Palette.gold : Color.white.opacity(0.3))
                        .position(x: w * CGFloat(p.0), y: h * CGFloat(p.1))
                }
                Text(constellation.name)
                    .font(.game(15))
                    .foregroundStyle(.white)
                    .outlined(Color(hex: 0x10163A), width: 1)
                    .padding(8)
            }
        }
        .frame(height: 110)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.outline, lineWidth: 2))
    }
}

/// Одна карта: картинка, звёзды и сколько копий до следующей звезды.
struct CardTile: View {
    @Environment(GameState.self) private var game
    let card: CardID

    var body: some View {
        let count = game.cardCount(card)
        let stars = game.cardStars(card)
        VStack(spacing: 3) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(LinearGradient(colors: count > 0 ? [Color(hex: 0x3A4FA0), Color(hex: 0x23306A)] : [Color(hex: 0x5A5560), Color(hex: 0x3A3640)],
                                         startPoint: .top, endPoint: .bottom))
                art
                    .opacity(count > 0 ? 1 : 0.25)
                    .grayscale(count > 0 ? 0 : 1)
                if count == 0 {
                    Text("?").font(.game(18)).foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(height: 62)
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(count > 0 ? Palette.gold : Palette.outline.opacity(0.6), lineWidth: count > 0 ? 2 : 1.5))
            StarsView(stars: stars, size: 6.5)
            Text(count == 0 ? card.name : (Cards.next(count: count).map { "\(count)/\($0)" } ?? tr("common.max")))
                .font(.game(9))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var art: some View {
        switch card.art {
        case .resource(let kind): ResourceIcon(kind: kind, size: 32)
        case .animal(let id): AnimalIcon(id: id, size: 34)
        case .monster(let kind): MonsterIcon(kind: kind, size: 34)
        }
    }
}


/// Как работают карты и созвездия: раскрывается по нажатию.
struct CollectionGuide: View {
    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.snappy) { open.toggle() }
            } label: {
                HStack(spacing: 8) {
                    PixelIcon(name: "book", size: 22)
                    Text(tr("collection.guide")).font(.game(14))
                    Spacer()
                    Image(systemName: open ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.inkSoft)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if open {
                row("cards", tr("collection.guide.drop"))
                row("star", tr("collection.guide.stars"))
                HStack(spacing: 6) {
                    ForEach(Array(Cards.thresholds.enumerated()), id: \.offset) { i, n in
                        VStack(spacing: 2) {
                            StarsView(stars: i + 1, size: 6)
                            Text(tr("collection.copies", n)).font(.game(10)).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Palette.parchmentDeep))
                    }
                }
                row("spark", tr("collection.guide.complete"))
                row("coins", tr("collection.guide.bonus"))
            }
        }
        .padding(12)
        .listBox(radius: 14)
    }

    private func row(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            PixelIcon(name: icon, size: 20).frame(width: 24)
            Text(text)
                .font(.game(12, .semibold))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
