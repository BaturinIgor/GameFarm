import SwiftUI

struct LevelView: View {
    @Environment(GameState.self) private var game
    @Environment(Store.self) private var store
    @State private var confirmReset = false
    @State private var showWardrobe = false
    @State private var musicOn = Sound.shared.musicOn
    @State private var sfxOn = Sound.shared.sfxOn

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    progressCard
                    settingsCard
                    bonusesCard
                    upcomingCard
                    statsCard
                    Button(role: .destructive) {
                        confirmReset = true
                    } label: {
                        Text(tr("profile.reset"))
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 6)
                }
                .padding(16)
            }
            .sheetChrome(tr("profile.title"), coins: game.save.coins)
            .sheet(isPresented: $showWardrobe) {
                WardrobeView().environment(game)
            }
            .confirmationDialog(tr("profile.reset.confirm"), isPresented: $confirmReset, titleVisibility: .visible) {
                Button(tr("profile.reset.action"), role: .destructive) { game.resetProgress() }
            } message: {
                Text(tr("profile.reset.message"))
            }
        }
    }

    private var progressCard: some View {
        Card(tint: .yellow) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().stroke(Color.yellow.opacity(0.2), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: game.levelProgress)
                        .stroke(Color.yellow, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(game.save.level)")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                }
                .frame(width: 82, height: 82)
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("level.n", game.save.level)).font(.title3.bold())
                    if game.save.level < GameRules.maxLevel {
                        Text(tr("level.xpOf", Fmt.n(game.save.xp), Fmt.n(game.xpToNext)))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Text(tr("level.xpHint"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(tr("level.maxReached")).font(.subheadline)
                    }
                }
            }
        }
    }

    private var settingsCard: some View {
        Card {
            HStack {
                Label(tr("settings.language"), systemImage: "globe")
                    .font(.subheadline.bold())
                Spacer()
                Picker(tr("settings.language"), selection: Binding(get: { Lang.shared.code }, set: { Lang.shared.set($0) })) {
                    ForEach(Lang.options) { option in
                        Text(option.name).tag(option.code)
                    }
                }
                .pickerStyle(.menu)
            }
            Divider()
            Toggle(isOn: $musicOn) {
                Label(tr("settings.music"), systemImage: "music.note").font(.subheadline.bold())
            }
            .onChange(of: musicOn) { _, on in Sound.shared.musicOn = on }
            Toggle(isOn: $sfxOn) {
                Label(tr("settings.sounds"), systemImage: "speaker.wave.2.fill").font(.subheadline.bold())
            }
            .onChange(of: sfxOn) { _, on in Sound.shared.sfxOn = on }
            Divider()
            Button {
                showWardrobe = true
            } label: {
                HStack {
                    SkinIcon(skin: game.currentSkin, size: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(tr("wardrobe.title")).font(.subheadline.bold())
                        Text(game.currentSkin.name).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Divider()
            HStack {
                if game.hasPro {
                    Label(ProductID.pro.title, systemImage: "crown.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.purple)
                }
                Spacer()
                Button(tr("shop.restore")) {
                    Task { await store.restore() }
                }
                .font(.subheadline)
            }
            #if SIDELOAD
            Button(role: .destructive) {
                game.resetTestPurchases()
            } label: {
                Text(tr("settings.resetTest")).font(.caption)
            }
            #endif
        }
    }

    private var bonusesCard: some View {
        let s = game.stats
        return Card {
            Text(tr("stats.title")).font(.headline)
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
            Text(title).font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .monospacedDigit()
        }
    }

    private var upcomingCard: some View {
        let start = game.save.level + 1
        let end = min(GameRules.maxLevel, start + 11)
        let levels = start <= end ? Array(start...end) : []
        let items = levels.map { UpcomingLevel(level: $0, lines: GameRules.unlocks(at: $0)) }.filter { !$0.lines.isEmpty }
        return Card {
            Text(tr("upcoming.title")).font(.headline)
            Text(tr("upcoming.each"))
                .font(.caption)
                .foregroundStyle(.secondary)
            if items.isEmpty {
                Text(tr("upcoming.none")).font(.subheadline)
            }
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("level.n", item.level)).font(.subheadline.bold())
                    ForEach(item.lines) { line in
                        HStack(spacing: 8) {
                            Text(line.icon).frame(width: 24)
                            Text(line.text).font(.caption)
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
            Text(tr("stats.statistics")).font(.headline)
            statRow("⛏️", tr("stats.harvests"), Fmt.n(game.save.harvests))
            statRow("🪙", tr("stats.coinsEarned"), Fmt.n(game.save.coinsEarned))
            statRow("🐾", tr("stats.animals"), tr("common.ofN", AnimalID.allCases.filter { game.stars($0) > 0 }.count, AnimalID.allCases.count))
            statRow("🗺️", tr("stats.locations"), tr("common.ofN", game.save.unlocked.count, LocationID.world.count))
            if !gathered.isEmpty {
                Text(tr("stats.gathered")).font(.caption.bold()).foregroundStyle(.secondary)
                FlowLayout(spacing: 6) {
                    ForEach(gathered) { item in
                        HStack(spacing: 4) {
                            ResourceIcon(kind: item.kind, size: 18)
                            Text(Fmt.n(item.amount)).font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.secondary.opacity(0.12)))
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
