import SwiftUI

struct LevelView: View {
    @Environment(GameState.self) private var game
    @Environment(Store.self) private var store
    @Environment(\.gameActions) private var actions
    @State private var musicOn = Sound.shared.musicOn
    @State private var sfxOn = Sound.shared.sfxOn

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                progressCard
                settingsCard
                bonusesCard
                upcomingCard
                statsCard
                rebirthCard
            }
            .padding(16)
        }
        .sheetChrome(tr("profile.title"), coins: game.save.coins)
    }

    private var rebirthCard: some View {
        Card(tint: ButtonTone.purple.base) {
            HStack(spacing: 12) {
                PixelIcon(name: "spark", size: 36, fallback: "✨")
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("rebirth.title")).font(.game(16))
                    Text(game.save.level >= Rebirth.minLevel ? tr("rebirth.short", game.rebirthReward)
                                                           : tr("rebirth.locked", Rebirth.minLevel))
                        .font(.game(12, .semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                SparkBadge(sparks: game.save.sparks)
            }
            Button {
                actions.open(.legacy)
            } label: {
                Text(tr("legacy.open"))
            }
            .buttonStyle(.game(.purple, wide: true))
        }
    }

    private var progressCard: some View {
        Card(tint: Palette.goldDark) {
            HStack(spacing: 14) {
                ZStack(alignment: .bottomTrailing) {
                    SkinIcon(skin: game.currentSkin, size: 64)
                        .frame(width: 78, height: 78)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.parchmentDeep))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.outline, lineWidth: 2.5))
                    Text("\(game.save.level)")
                        .gameTitle(18)
                        .padding(.horizontal, 6)
                        .frame(minWidth: 34, minHeight: 34)
                        .background(Capsule().fill(LinearGradient(colors: [ButtonTone.orange.top, ButtonTone.orange.base], startPoint: .top, endPoint: .bottom)))
                        .overlay(Capsule().strokeBorder(Palette.outline, lineWidth: 2))
                        .offset(x: 8, y: 8)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(tr("level.n", game.save.level)).font(.game(19))
                    if game.save.level < GameRules.maxLevel {
                        GameBar(value: game.levelProgress, tone: .gold, height: 16,
                                label: "\(Fmt.n(game.save.xp)) / \(Fmt.n(game.xpToNext))")
                        Text(tr("level.xpHint"))
                            .font(.game(12, .semibold))
                            .foregroundStyle(.secondary)
                    } else {
                        Text(tr("level.maxReached")).font(.game(14, .semibold))
                    }
                }
            }
        }
    }

    private var settingsCard: some View {
        Card {
            HStack {
                Label(tr("settings.language"), systemImage: "globe")
                    .font(.game(14, .semibold).bold())
                Spacer()
                Menu {
                    ForEach(Lang.options) { option in
                        Button(option.name) { Lang.shared.set(option.code) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(Lang.options.first { $0.code == Lang.shared.code }?.name ?? Lang.shared.code)
                        Image(systemName: "chevron.down").font(.system(size: 10, weight: .black))
                    }
                    .font(.game(13))
                    .foregroundStyle(.white)
                    .outlined(Palette.woodDark, width: 1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .woodPill(radius: 10)
                }
            }
            PaperDivider()
            Toggle(isOn: $musicOn) {
                Label(tr("settings.music"), systemImage: "music.note").font(.game(14))
            }
            .toggleStyle(GameToggleStyle())
            .onChange(of: musicOn) { _, on in Sound.shared.musicOn = on }
            Toggle(isOn: $sfxOn) {
                Label(tr("settings.sounds"), systemImage: "speaker.wave.2.fill").font(.game(14))
            }
            .toggleStyle(GameToggleStyle())
            .onChange(of: sfxOn) { _, on in Sound.shared.sfxOn = on }
            PaperDivider()
            Button {
                actions.open(.wardrobe)
            } label: {
                HStack {
                    SkinIcon(skin: game.currentSkin, size: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(tr("wardrobe.title")).font(.game(14, .semibold).bold())
                        Text(game.currentSkin.name).font(.game(12, .semibold)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.game(14)).foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.press)
            PaperDivider()
            HStack {
                if game.hasPro {
                    Label(ProductID.pro.title, systemImage: "crown.fill")
                        .font(.game(14, .semibold).bold())
                        .foregroundStyle(ButtonTone.purple.lip)
                }
                Spacer()
                Button(tr("shop.restore")) {
                    Task { await store.restore() }
                }
                .buttonStyle(.game(.wood, small: true))
            }
            #if SIDELOAD
            Button {
                game.resetTestPurchases()
            } label: {
                Text(tr("settings.resetTest"))
            }
            .buttonStyle(.game(.gray, small: true))
            #endif
        }
    }

    private var bonusesCard: some View {
        let s = game.stats
        return Card {
            Text(tr("stats.title")).font(.game(16))
            statRow("💪", tr("stats.damage"), "x" + Fmt.decimal(s.damageMult, digits: 2))
            statRow("⚡", tr("stats.hitEvery"), tr("stats.seconds", Fmt.decimal(s.hitInterval, digits: 2)))
            statRow("🎒", tr("stats.backpack"), tr("stats.slots", s.capacity))
            statRow("👟", tr("stats.speed"), "+\(Fmt.pct(s.speed / GameRules.baseSpeed - 1))")
            statRow("🧺", tr("stats.yield"), "+\(Fmt.pct(s.yieldAll))")
            statRow("📚", tr("stats.xp"), "+\(Fmt.pct(s.xpMult - 1))")
            statRow("💰", tr("stats.sell"), "+\(Fmt.pct(s.sellMult - 1))")
            statRow("🎯", tr("stats.crit"), Fmt.pct(s.critChance))
            statRow("🌱", tr("stats.regrow"), "x" + Fmt.decimal(1 / s.respawnMult, digits: 2))
            statRow("🌟", tr("stats.talentPoints"), tr("stats.freeOf", game.talentPointsFree, game.talentPointsTotal))
        }
    }

    private func statRow(_ icon: String, _ title: String, _ value: String) -> some View {
        HStack {
            Text(icon).frame(width: 26)
            Text(title).font(.game(14, .semibold))
            Spacer()
            Text(value)
                .font(.game(14, .semibold).bold())
                .monospacedDigit()
        }
    }

    private var upcomingCard: some View {
        let start = game.save.level + 1
        let end = min(GameRules.maxLevel, start + 11)
        let levels = start <= end ? Array(start...end) : []
        let items = levels.map { UpcomingLevel(level: $0, lines: GameRules.unlocks(at: $0)) }.filter { !$0.lines.isEmpty }
        return Card {
            Text(tr("upcoming.title")).font(.game(16))
            Text(tr("upcoming.each"))
                .font(.game(12, .semibold))
                .foregroundStyle(.secondary)
            if items.isEmpty {
                Text(tr("upcoming.none")).font(.game(14, .semibold))
            }
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("level.n", item.level)).font(.game(14, .semibold).bold())
                    ForEach(item.lines) { line in
                        HStack(spacing: 8) {
                            Text(line.icon).frame(width: 24)
                            Text(line.text).font(.game(12, .semibold))
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private var statsCard: some View {
        let gathered = ResourceKind.allCases.compactMap { kind -> ResourceAmount? in
            let n = game.save.gathered[kind] ?? 0
            return n > 0 ? ResourceAmount(kind: kind, amount: n) : nil
        }
        return Card {
            Text(tr("stats.statistics")).font(.game(16))
            statRow("⛏️", tr("stats.harvests"), Fmt.n(game.save.harvests))
            statRow("🪙", tr("stats.coinsEarned"), Fmt.n(game.save.coinsEarned))
            statRow("🐾", tr("stats.animals"), tr("common.ofN", AnimalID.allCases.filter { game.stars($0) > 0 }.count, AnimalID.allCases.count))
            statRow("🗺️", tr("stats.locations"), tr("common.ofN", game.save.unlocked.count, LocationID.world.count))
            if !gathered.isEmpty {
                Text(tr("stats.gathered")).font(.game(12, .semibold).bold()).foregroundStyle(.secondary)
                FlowLayout(spacing: 6) {
                    ForEach(gathered) { item in
                        HStack(spacing: 4) {
                            ResourceIcon(kind: item.kind, size: 18)
                            Text(Fmt.n(item.amount)).font(.game(13, .semibold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Palette.parchmentDeep))
                        .overlay(Capsule().strokeBorder(Palette.woodDark.opacity(0.35), lineWidth: 1))
                    }
                }
            }
        }
    }
}

struct UpcomingLevel: Identifiable {
    let level: Int
    let lines: [UnlockLine]
    var id: Int { level }
}
