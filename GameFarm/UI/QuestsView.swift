import SwiftUI

struct QuestsView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case quests, hunts, achievements
        var id: String { rawValue }
    }

    @Environment(GameState.self) private var game
    @State private var tab: Tab = .quests

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                GameTabs(selection: $tab, items: [(Tab.quests, tr("hud.quests")), (Tab.hunts, tr("hunt.tab")),
                                                  (Tab.achievements, tr("quests.achievements"))])

                switch tab {
                case .quests: questsList
                case .hunts: HuntList()
                case .achievements: achievementsList
                }
            }
            .padding(16)
            .animation(.spring(duration: 0.35), value: game.save.quests)
        }
        .sheetChrome(tr("hud.quests"), coins: game.save.coins)
    }

    private var questsList: some View {
        VStack(spacing: 12) {
            HStack {
                Text(tr("quests.done", game.save.questsDone))
                    .font(.game(14, .semibold).bold())
                Spacer()
            }
            ForEach(game.save.quests) { quest in
                QuestCard(quest: quest)
                    .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
            }
            Text(tr("quests.hint"))
                .font(.game(12, .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var achievementsList: some View {
        let all = Achievement.all
        let ready = all.filter { game.canClaim($0) }
        let open = all.filter { !game.isClaimed($0) && !game.canClaim($0) }
        let done = all.filter { game.isClaimed($0) }
        return VStack(spacing: 10) {
            HStack {
                Text(tr("achievements.count", done.count, all.count))
                    .font(.game(14, .semibold).bold())
                Spacer()
                Text(tr("achievements.points", game.save.bonusTalentPoints))
                    .font(.game(12, .semibold).bold())
                    .foregroundStyle(.secondary)
            }
            ForEach(ready) { AchievementRow(achievement: $0) }
            ForEach(open) { AchievementRow(achievement: $0) }
            ForEach(done) { AchievementRow(achievement: $0) }
        }
    }
}

struct QuestCard: View {
    @Environment(GameState.self) private var game
    let quest: Quest

    var body: some View {
        let done = quest.done
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(done ? Color(hex: 0xDDEFC8) : Color(hex: 0xFBE3C2))
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Palette.outline.opacity(0.7), lineWidth: 2)
                    if quest.type == .gather, let kind = quest.kind {
                        ResourceIcon(kind: kind, size: 30)
                    } else {
                        Text(quest.icon).font(.system(size: 26))
                    }
                }
                .frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 3) {
                    Text(quest.title)
                        .font(.game(16))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        RewardTag(icon: AnyView(CoinIcon(size: 15)), text: Fmt.n(quest.coins))
                        RewardTag(icon: AnyView(Text("✨").font(.system(size: 13))), text: Fmt.n(quest.xp))
                    }
                }
                Spacer(minLength: 0)
            }
            GameBar(value: quest.fraction, tone: done ? .green : .orange, height: 16,
                    label: "\(Fmt.n(quest.progress)) / \(Fmt.n(quest.target))")
                .animation(.easeOut(duration: 0.4), value: quest.fraction)
            if done {
                Button {
                    withAnimation(.spring(duration: 0.4)) { game.claimQuest(quest.id) }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: {
                    Text(tr("quests.claim"))
                }
                .buttonStyle(.game(.green, wide: true))
            } else {
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.spring(duration: 0.4)) { game.rerollQuest(quest.id) }
                    } label: {
                        Label(tr("quests.reroll", Fmt.n(game.rerollCost)), systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.game(.wood, small: true, wide: true))
                    .disabled(game.save.coins < game.rerollCost)
                    Button {
                        let id = quest.id
                        Ads.shared.show {
                            withAnimation(.spring(duration: 0.4)) { game.rerollQuest(id, free: true) }
                        }
                    } label: {
                        Label(tr("quests.rerollFree"), systemImage: game.hasPro ? "crown.fill" : "play.rectangle.fill")
                    }
                    .buttonStyle(.game(.blue, small: true, wide: true))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Palette.parchmentLight)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(done ? ButtonTone.green.base : Palette.woodDark.opacity(0.45), lineWidth: done ? 2.5 : 1.5)
        )
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.woodDark.opacity(0.25)).offset(y: 3))
    }
}

struct RewardTag: View {
    let icon: AnyView
    let text: String

    var body: some View {
        HStack(spacing: 3) {
            icon
            Text(text)
                .font(.game(13, .bold))
                .monospacedDigit()
        }
    }
}

struct AchievementRow: View {
    @Environment(GameState.self) private var game
    let achievement: Achievement

    var body: some View {
        let progress = game.progress(achievement)
        let claimed = game.isClaimed(achievement)
        let ready = game.canClaim(achievement)
        let fraction = min(1, Double(progress) / Double(max(1, achievement.target)))
        HStack(spacing: 12) {
            Text(achievement.icon)
                .font(.system(size: 28))
                .frame(width: 48, height: 48)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(ready ? Palette.gold.opacity(0.5) : Palette.parchmentDeep.opacity(0.7)))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.outline.opacity(ready ? 0.8 : 0.3), lineWidth: 2))
                .grayscale(claimed || ready ? 0 : 0.8)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(achievement.title).font(.game(14, .semibold).bold())
                    Spacer()
                    HStack(spacing: 6) {
                        RewardTag(icon: AnyView(CoinIcon(size: 14)), text: Fmt.n(achievement.coins))
                        if achievement.talentPoints > 0 { Text("🌟 +\(achievement.talentPoints)") }
                    }
                    .font(.game(12, .semibold).bold())
                    .foregroundStyle(.secondary)
                }
                Text(achievement.detail)
                    .font(.game(12, .semibold))
                    .foregroundStyle(.secondary)
                if claimed {
                    Label(tr("achievements.earned"), systemImage: "checkmark.seal.fill")
                        .font(.game(12))
                        .foregroundStyle(Palette.good)
                } else if ready {
                    Button {
                        withAnimation(.spring(duration: 0.35)) { game.claim(achievement) }
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } label: {
                        Text(tr("achievements.claim"))
                    }
                    .buttonStyle(.game(.orange, small: true, wide: true))
                } else {
                    GameBar(value: fraction, tone: .orange, height: 14,
                            label: "\(Fmt.n(min(progress, achievement.target))) / \(Fmt.n(achievement.target))")
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Palette.parchmentLight)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(ready ? ButtonTone.orange.base : Palette.woodDark.opacity(0.4), lineWidth: ready ? 2.5 : 1.5)
        )
        .opacity(claimed ? 0.7 : 1)
    }
}
