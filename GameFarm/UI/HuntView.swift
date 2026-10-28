import SwiftUI

/// Портрет монстра: первый кадр листа.
struct MonsterIcon: View {
    let kind: MonsterKind
    var size: CGFloat = 40

    var body: some View {
        let sheet = kind.sheet
        let crop = CGRect(x: 0, y: CGFloat(sheet.idle.row) * sheet.cell, width: sheet.cell, height: sheet.cell)
        if let image = Sprites.crisp(kind.sprite, crop: crop, scale: 4) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Text(kind.emoji).font(.system(size: size * 0.8))
        }
    }
}

/// Стражник у доски: заказы на охоту и подземелья.
struct HuntView: View {
    enum Tab: Hashable { case hunts, dungeons }

    @Environment(GameState.self) private var game
    @Environment(\.gameActions) private var actions
    @State private var tab: Tab = .hunts

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    NPCPortrait(name: "guard")
                    Text(tr(tab == .hunts ? "hunt.hello" : "dungeon.hello"))
                        .font(.game(13, .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listBox(radius: 12)
                }
                GameTabs(selection: $tab, items: [(Tab.hunts, tr("hunt.tab")), (Tab.dungeons, tr("dungeon.tab"))],
                         badges: [.hunts: game.claimableHunts])
                switch tab {
                case .hunts: HuntList()
                case .dungeons: DungeonList { actions.close() }
                }
            }
            .padding(16)
        }
        .sheetChrome(tr("hunt.title"), coins: game.save.coins)
        .onAppear { game.ensureHunts() }
    }
}

/// Список заказов: прогресс, награды и кнопка "Забрать".
struct HuntList: View {
    @Environment(GameState.self) private var game

    var body: some View {
        VStack(spacing: 12) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Label(tr("hunt.refresh", Countdown.text(game.nextHuntsAt.timeIntervalSince(context.date))), systemImage: "clock")
                    .font(.game(12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if game.save.hunts.isEmpty {
                Card {
                    Text(tr("hunt.empty")).font(.game(14, .semibold))
                }
            }
            ForEach(game.save.hunts) { HuntCard(hunt: $0) }
            Text(tr("hunt.tip"))
                .font(.game(11, .semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .onAppear { game.ensureHunts() }
    }
}

private struct HuntCard: View {
    @Environment(GameState.self) private var game
    let hunt: HuntContract

    var body: some View {
        Card(tint: hunt.done ? ButtonTone.green.base : .clear) {
            HStack(spacing: 12) {
                MonsterIcon(kind: hunt.monster, size: 40)
                    .frame(width: 52, height: 52)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.parchmentDeep.opacity(0.7)))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.outline.opacity(0.6), lineWidth: 2))
                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("hunt.kill", hunt.target, hunt.monster.name)).font(.game(15))
                    Text(Bestiary.home(of: hunt.monster).map { $0.spec.emoji + " " + $0.spec.name }.joined(separator: ", "))
                        .font(.game(11, .semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        RewardTag(icon: AnyView(CoinIcon(size: 15)), text: Fmt.n(hunt.coins))
                        RewardTag(icon: AnyView(Text("✨").font(.system(size: 13))), text: Fmt.n(hunt.xp))
                        if hunt.ticket { RewardTag(icon: AnyView(TicketIcon(size: 15)), text: "1") }
                    }
                }
                Spacer(minLength: 0)
            }
            GameBar(value: Double(hunt.progress) / Double(max(1, hunt.target)), tone: hunt.done ? .green : .red, height: 16,
                    label: "\(min(hunt.progress, hunt.target)) / \(hunt.target)")
            if hunt.done {
                Button {
                    withAnimation(.spring(duration: 0.35)) { game.claimHunt(hunt.id) }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: {
                    Text(tr("quests.claim"))
                }
                .buttonStyle(.game(.green, wide: true))
            }
        }
    }
}
