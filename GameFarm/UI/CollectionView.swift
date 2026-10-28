import SwiftUI

/// Коллекция карт: семь созвездий по пять карт. Копии поднимают звёзды карты,
/// полное созвездие даёт вечный бонус и новый образ героя.
struct CollectionView: View {
    @Environment(GameState.self) private var game

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 10) {
                    summary("🃏", tr("collection.cards", game.cardsOwned, CardID.allCases.count))
                    summary("✨", tr("collection.done", ConstellationID.allCases.filter { game.isComplete($0) }.count,
                                    ConstellationID.allCases.count))
                }
                Text(tr("collection.hint"))
                    .font(.game(12, .semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                ForEach(ConstellationID.allCases) { ConstellationCard(constellation: $0) }
            }
            .padding(16)
        }
        .sheetChrome(tr("collection.title"), coins: game.save.coins)
    }

    private func summary(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Text(icon).font(.system(size: 20))
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
