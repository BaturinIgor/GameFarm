import SwiftUI

struct QuestsView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case quests, achievements
        var id: String { rawValue }
    }

    @Environment(GameState.self) private var game
    @State private var tab: Tab = .quests

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Picker(tr("common.section"), selection: $tab) {
                        Text(tr("hud.quests")).tag(Tab.quests)
                        Text(tr("quests.achievements")).tag(Tab.achievements)
                    }
                    .pickerStyle(.segmented)

                    switch tab {
                    case .quests: questsList
                    case .achievements: achievementsList
                    }
                }
                .padding(16)
                .animation(.spring(duration: 0.35), value: game.save.quests)
            }
            .sheetChrome(tr("hud.quests"), coins: game.save.coins)
        }
    }

    private var questsList: some View {
        VStack(spacing: 12) {
            HStack {
                Text(tr("quests.done", game.save.questsDone))
                    .font(.subheadline.bold())
                Spacer()
            }
            ForEach(game.save.quests) { quest in
                QuestCard(quest: quest)
                    .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
            }
            Text(tr("quests.hint"))
                .font(.caption)
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
                    .font(.subheadline.bold())
                Spacer()
                Text(tr("achievements.points", game.save.bonusTalentPoints))
                    .font(.caption.bold())
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
                    Circle()
                        .fill(done ? Color.green.opacity(0.22) : Color.orange.opacity(0.16))
                    if quest.type == .gather, let kind = quest.kind {
                        ResourceIcon(kind: kind, size: 30)
                    } else {
                        Text(quest.icon).font(.system(size: 26))
                    }
                }
                .frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 3) {
                    Text(quest.title)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        Label("\(Fmt.n(quest.coins))", systemImage: "circle.fill")
                            .labelStyle(RewardLabelStyle(icon: "🪙"))
                        Label("\(Fmt.n(quest.xp))", systemImage: "star.fill")
                            .labelStyle(RewardLabelStyle(icon: "✨"))
                    }
                }
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.15))
                        Capsule()
                            .fill(LinearGradient(colors: done ? [.green, .mint] : [.orange, .yellow],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(8, geo.size.width * quest.fraction))
                            .animation(.easeOut(duration: 0.4), value: quest.fraction)
                    }
                }
                .frame(height: 9)
                Text("\(Fmt.n(quest.progress)) / \(Fmt.n(quest.target))")
                    .font(.caption.bold())
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            if done {
                Button {
                    withAnimation(.spring(duration: 0.4)) { game.claimQuest(quest.id) }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: {
                    Text(tr("quests.claim")).font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(.green)
                .controlSize(.large)
            } else {
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.spring(duration: 0.4)) { game.rerollQuest(quest.id) }
                    } label: {
                        Label(tr("quests.reroll", Fmt.n(game.rerollCost)), systemImage: "arrow.triangle.2.circlepath")
                            .font(.footnote.bold())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(game.save.coins < game.rerollCost)
                    Button {
                        let id = quest.id
                        Ads.shared.show {
                            withAnimation(.spring(duration: 0.4)) { game.rerollQuest(id, free: true) }
                        }
                    } label: {
                        Label(tr("quests.rerollFree"), systemImage: game.hasPro ? "crown.fill" : "play.rectangle.fill")
                            .font(.footnote.bold())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(done ? Color.green.opacity(0.6) : Color.clear, lineWidth: 2)
        )
    }
}

struct RewardLabelStyle: LabelStyle {
    let icon: String

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            Text(icon).font(.system(size: 13))
            configuration.title
                .font(.system(size: 13, weight: .bold, design: .rounded))
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
                .background(Circle().fill(ready ? Color.yellow.opacity(0.3) : Color.secondary.opacity(0.12)))
                .grayscale(claimed || ready ? 0 : 0.8)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(achievement.title).font(.subheadline.bold())
                    Spacer()
                    HStack(spacing: 6) {
                        Text("🪙 \(Fmt.n(achievement.coins))")
                        if achievement.talentPoints > 0 { Text("🌟 +\(achievement.talentPoints)") }
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                }
                Text(achievement.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if claimed {
                    Label(tr("achievements.earned"), systemImage: "checkmark.seal.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                } else if ready {
                    Button {
                        withAnimation(.spring(duration: 0.35)) { game.claim(achievement) }
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } label: {
                        Text(tr("achievements.claim")).font(.subheadline.bold()).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.orange)
                } else {
                    ProgressView(value: fraction)
                        .tint(.orange)
                    Text("\(Fmt.n(min(progress, achievement.target))) / \(Fmt.n(achievement.target))")
                        .font(.caption2.bold())
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(ready ? Color.orange.opacity(0.7) : Color.clear, lineWidth: 2)
        )
        .opacity(claimed ? 0.7 : 1)
    }
}
