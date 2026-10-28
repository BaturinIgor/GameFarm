import SwiftUI

/// Перерождение и вечные бонусы наследия.
struct LegacyView: View {
    @Environment(GameState.self) private var game
    @Environment(\.gameActions) private var actions

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                rebirthCard
                SectionTitle(text: tr("legacy.title"))
                ForEach(LegacyPerk.allCases) { perk in
                    LegacyRow(perk: perk)
                }
                Text(tr("legacy.hint"))
                    .font(.game(12, .semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(16)
        }
        .sheetChrome(tr("rebirth.title"), coins: game.save.coins)
    }

    private var rebirthCard: some View {
        let reward = game.rebirthReward
        return ShopCard(title: tr("rebirth.title"), tone: .purple) {
            HStack {
                Text(tr("rebirth.count", game.save.rebirths))
                    .font(.game(14))
                Spacer()
                SparkBadge(sparks: game.save.sparks)
            }
            Text(tr("rebirth.text"))
                .font(.game(13, .semibold))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 4) {
                Label(tr("rebirth.keep"), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Palette.good)
                Label(tr("rebirth.lose"), systemImage: "arrow.counterclockwise.circle.fill")
                    .foregroundStyle(ButtonTone.red.lip)
            }
            .font(.game(12))
            .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                if game.save.level >= Rebirth.minLevel {
                    Text(tr("rebirth.reward")).font(.game(14))
                    Spacer()
                    PixelIcon(name: "spark", size: 22, fallback: "✨")
                    Text("+\(Fmt.n(reward))").font(.game(18)).monospacedDigit()
                } else {
                    Label(tr("rebirth.locked", Rebirth.minLevel), systemImage: "lock.fill")
                        .font(.game(13))
                        .foregroundStyle(ButtonTone.orange.lip)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(hex: 0xEDE2FA)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(ButtonTone.purple.base.opacity(0.5), lineWidth: 1.5))
            Button {
                Dialogs.shared.confirm(tr("rebirth.confirm"), message: tr("rebirth.confirm.message", reward),
                                       icon: "px:spark", confirm: tr("rebirth.action"), tone: .purple) {
                    actions.close()
                    game.rebirth()
                }
            } label: {
                Text(tr("rebirth.action"))
            }
            .buttonStyle(.game(.purple, wide: true))
        }
    }
}

/// Строка бонуса наследия: что даёт сейчас, что даст следующий ранг и цена в искрах.
struct LegacyRow: View {
    @Environment(GameState.self) private var game
    let perk: LegacyPerk

    var body: some View {
        let rank = game.legacyRank(perk)
        let maxed = rank >= perk.maxRank
        Card(tint: rank > 0 ? ButtonTone.purple.base.opacity(0.7) : .clear) {
            HStack(spacing: 12) {
                PixelIcon(name: perk.icon, size: 30)
                    .frame(width: 50, height: 50)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(rank > 0 ? Color(hex: 0xEDE2FA) : Palette.parchmentDeep.opacity(0.7)))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.outline.opacity(0.6), lineWidth: 2))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(perk.name).font(.game(15))
                        Text("\(rank)/\(perk.maxRank)")
                            .font(.game(11))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Palette.parchmentDeep))
                            .overlay(Capsule().strokeBorder(Palette.woodDark.opacity(0.4), lineWidth: 1))
                    }
                    if rank > 0 {
                        Text(tr("legacy.now", perk.effect(rank)))
                            .font(.game(12, .semibold))
                    }
                    if !maxed {
                        Text(tr("legacy.next", perk.effect(rank + 1)))
                            .font(.game(12, .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 4)
                if maxed {
                    Text(tr("common.max")).font(.game(12)).foregroundStyle(Palette.good)
                } else {
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            if game.buyLegacy(perk) {
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            PixelIcon(name: "spark", size: 16, fallback: "✨")
                            Text(Fmt.n(perk.cost(rank: rank))).monospacedDigit()
                        }
                    }
                    .buttonStyle(.game(.purple, small: true))
                    .disabled(!game.canBuyLegacy(perk))
                }
            }
        }
    }
}

/// Сколько искр у игрока.
struct SparkBadge: View {
    let sparks: Int

    var body: some View {
        HStack(spacing: 4) {
            PixelIcon(name: "spark", size: 18, fallback: "✨")
            Text(Fmt.n(sparks))
                .font(.game(15))
                .foregroundStyle(.white)
                .outlined(ButtonTone.purple.lip, width: 1)
                .monospacedDigit()
        }
        .padding(.leading, 6)
        .padding(.trailing, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(ButtonTone.purple.base))
        .overlay(Capsule().strokeBorder(Palette.outline, lineWidth: 2))
    }
}
