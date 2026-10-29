import SwiftUI
import UniformTypeIdentifiers

struct LevelView: View {
    @Environment(GameState.self) private var game
    @Environment(Store.self) private var store
    @Environment(\.gameActions) private var actions
    @State private var musicOn = Sound.shared.musicOn
    @State private var sfxOn = Sound.shared.sfxOn
    @AppStorage("settings.batterySaver") private var batterySaver = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                progressCard
                bonusesCard
                UpcomingCard()
                statsCard
                rebirthCard
                settingsCard
                if Distribution.gameCenter { leaderboardsCard }
                BackupCard()
                FeedbackCard()
            }
            .padding(16)
        }
        .sheetChrome(tr("profile.title"), coins: game.save.coins)
    }

    /// Рейтинги Game Center (только в сборке из App Store).
    private var leaderboardsCard: some View {
        Card {
            HStack(spacing: 12) {
                PixelIcon(name: "trophy", size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("leaderboards.title")).font(.game(15))
                    Text(tr("leaderboards.hint"))
                        .font(.game(11, .semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            Button {
                GameCenter.shared.show()
            } label: {
                Label(tr("leaderboards.open"), systemImage: "list.number")
            }
            .buttonStyle(.game(.gold, wide: true))
        }
    }

    private var rebirthCard: some View {
        Card(tint: ButtonTone.purple.base) {
            HStack(spacing: 12) {
                PixelIcon(name: "spark", size: 36)
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
            Toggle(isOn: $batterySaver) {
                VStack(alignment: .leading, spacing: 1) {
                    Label(tr("settings.battery"), systemImage: "battery.75percent").font(.game(14))
                    Text(tr("settings.battery.hint")).font(.game(11, .semibold)).foregroundStyle(.secondary)
                }
            }
            .toggleStyle(GameToggleStyle())
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

    /// Характеристики героя плитками: иконка, значение, подпись.
    private var bonusesCard: some View {
        let s = game.stats
        let tiles: [StatTile.Item] = [
            .init(icon: "fist", title: tr("stats.damage"), value: "x" + Fmt.decimal(s.damageMult, digits: 2)),
            .init(icon: "bolt", title: tr("stats.hitEvery"), value: tr("stats.seconds", Fmt.decimal(s.hitInterval, digits: 2))),
            .init(icon: "heart", title: tr("stats.health"), value: Fmt.n(Int(game.maxHP))),
            .init(icon: "shield", title: tr("stats.defense"), value: Fmt.pct(game.defense)),
            .init(icon: "wind", title: tr("stats.dodge"), value: Fmt.pct(game.dodgeChance)),
            .init(icon: "target", title: tr("stats.crit"), value: Fmt.pct(s.critChance)),
            .init(icon: "boots", title: tr("stats.speed"), value: "+" + Fmt.pct(s.speed / GameRules.baseSpeed - 1)),
            .init(icon: "bag", title: tr("stats.backpack"), value: tr("stats.slots", s.capacity)),
            .init(icon: "basket", title: tr("stats.yield"), value: "+" + Fmt.pct(s.yieldAll)),
            .init(icon: "sprout", title: tr("stats.regrow"), value: "x" + Fmt.decimal(1 / s.respawnMult, digits: 2)),
            .init(icon: "book", title: tr("stats.xp"), value: "+" + Fmt.pct(s.xpMult - 1)),
            .init(icon: "coins", title: tr("stats.sell"), value: "+" + Fmt.pct(s.sellMult - 1)),
        ]
        return VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: tr("stats.title"))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(tiles) { StatTile(item: $0) }
            }
            HStack(spacing: 10) {
                PixelIcon(name: "star", size: 26)
                Text(tr("stats.talentPoints")).font(.game(14, .semibold))
                Spacer()
                Text(tr("stats.freeOf", game.talentPointsFree, game.talentPointsTotal))
                    .font(.game(14, .semibold).bold())
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .listBox(radius: 12)
        }
    }

    private func statRow(_ icon: String, _ title: String, _ value: String) -> some View {
        HStack {
            PixelIcon(name: icon, size: 22).frame(width: 26)
            Text(title).font(.game(14, .semibold))
            Spacer()
            Text(value)
                .font(.game(14, .semibold).bold())
                .monospacedDigit()
        }
    }

    private var statsCard: some View {
        let gathered = ResourceKind.allCases.compactMap { kind -> ResourceAmount? in
            let n = game.save.gathered[kind] ?? 0
            return n > 0 ? ResourceAmount(kind: kind, amount: n) : nil
        }
        return Card {
            Text(tr("stats.statistics")).font(.game(16))
            statRow("tool_pickaxe", tr("stats.harvests"), Fmt.n(game.save.harvests))
            statRow("coins", tr("stats.coinsEarned"), Fmt.n(game.save.coinsEarned))
            statRow("wheat", tr("stats.crops"), Fmt.n(game.save.cropsHarvested))
            statRow("skull", tr("stats.kills"), Fmt.n(game.save.kills))
            statRow("paw", tr("stats.animals"), tr("common.ofN", AnimalID.allCases.filter { game.stars($0) > 0 }.count, AnimalID.allCases.count))
            statRow("map", tr("stats.locations"), tr("common.ofN", game.save.unlocked.count, LocationID.world.count))
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

/// Плитка характеристики героя.
struct StatTile: View {
    struct Item: Identifiable {
        let icon: String
        let title: String
        let value: String
        var id: String { icon + title }
    }

    let item: Item

    var body: some View {
        HStack(spacing: 8) {
            PixelIcon(name: item.icon, size: 26)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Palette.parchmentDeep))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Palette.woodDark.opacity(0.4), lineWidth: 1.5))
            VStack(alignment: .leading, spacing: 0) {
                Text(item.value)
                    .font(.game(15))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(item.title)
                    .font(.game(11, .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .listBox(radius: 12)
    }
}

/// "Скоро откроется": ближайшая награда крупно, дальше компактная лента уровней.
struct UpcomingCard: View {
    @Environment(GameState.self) private var game
    @State private var expanded: Set<Int> = []

    private var items: [UpcomingLevel] {
        let start = game.save.level + 1
        let end = min(GameRules.maxLevel, start + 14)
        guard start <= end else { return [] }
        return (start...end).map { UpcomingLevel(level: $0, lines: GameRules.unlocks(at: $0)) }.filter { !$0.lines.isEmpty }
    }

    var body: some View {
        let list = items
        let rest = Array(list.dropFirst().prefix(6))
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: tr("upcoming.title"))
            everyLevel
            if let next = list.first {
                nextCard(next)
                if !rest.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(rest) { item in
                            row(item)
                            if item.id != rest.last?.id {
                                PaperDivider().padding(.leading, 52)
                            }
                        }
                    }
                    .listBox(radius: 14)
                }
            } else {
                Text(tr("upcoming.none")).font(.game(14, .semibold))
            }
        }
    }

    /// Что даёт каждый уровень: четыре короткие плашки.
    private var everyLevel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(tr("upcoming.eachTitle"))
                .font(.game(11, .semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                chip("star", tr("upcoming.chip.talent"))
                chip("bag", tr("upcoming.chip.bag"))
                chip("fist", tr("upcoming.chip.power"))
                chip("coins", tr("upcoming.chip.sell"))
            }
        }
    }

    private func chip(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 3) {
            PixelIcon(name: icon, size: 15)
            Text(text)
                .font(.game(11))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(Capsule().fill(Palette.parchmentDeep))
        .overlay(Capsule().strokeBorder(Palette.woodDark.opacity(0.35), lineWidth: 1))
    }

    private func levelBadge(_ level: Int, size: CGFloat) -> some View {
        Text("\(level)")
            .gameTitle(size * 0.42)
            .frame(width: size, height: size)
            .background(Circle().fill(LinearGradient(colors: [ButtonTone.orange.top, ButtonTone.orange.base],
                                                     startPoint: .top, endPoint: .bottom)))
            .overlay(Circle().strokeBorder(Palette.outline, lineWidth: 2))
    }

    /// Ближайший уровень с наградами: все строки и сколько осталось.
    private func nextCard(_ item: UpcomingLevel) -> some View {
        let left = item.level - game.save.level
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                levelBadge(item.level, size: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text(tr("upcoming.next")).font(.game(15))
                    Text(left == 1 ? tr("upcoming.nextLevel") : tr("upcoming.inLevels", left))
                        .font(.game(11, .semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            ForEach(item.lines) { line in
                HStack(spacing: 8) {
                    IconView(icon: line.icon, size: 22).frame(width: 26)
                    Text(line.text)
                        .font(.game(13, .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(Color(hex: 0xFFF3D0)))
        .overlay(shape.strokeBorder(Palette.goldDark, lineWidth: 2.5))
        .background(shape.fill(Palette.woodDark.opacity(0.25)).offset(y: 3))
    }

    /// Строка уровня: иконки наград, по нажатию раскрывается текст.
    private func row(_ item: UpcomingLevel) -> some View {
        let open = expanded.contains(item.level)
        return Button {
            withAnimation(.snappy) {
                if open { expanded.remove(item.level) } else { expanded.insert(item.level) }
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    levelBadge(item.level, size: 30)
                    HStack(spacing: 4) {
                        ForEach(item.lines.prefix(5)) { line in
                            IconView(icon: line.icon, size: 22)
                        }
                        if item.lines.count > 5 {
                            Text("+\(item.lines.count - 5)").font(.game(12)).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 4)
                    Image(systemName: open ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.inkSoft)
                }
                if open {
                    ForEach(item.lines) { line in
                        HStack(spacing: 8) {
                            IconView(icon: line.icon, size: 18).frame(width: 22)
                            Text(line.text)
                                .font(.game(12, .semibold))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.leading, 40)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}


/// Резервная копия прогресса: сохранить в файл и восстановить из файла.
/// Файл копии прогресса для окна "Сохранить в Файлы".
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct BackupCard: View {
    @Environment(GameState.self) private var game
    @State private var exportURL: URL?
    @State private var importing = false
    @State private var exporting = false
    @State private var document: BackupDocument?

    var body: some View {
        Card {
            HStack(spacing: 10) {
                PixelIcon(name: "scroll2", size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("backup.title")).font(.game(15))
                    Text(tr("backup.hint"))
                        .font(.game(11, .semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: 8) {
                // Сохранить в Файлы: можно сразу выбрать папку в iCloud Drive
                Button {
                    if let url = game.exportBackup(), let data = try? Data(contentsOf: url) {
                        exportURL = url
                        document = BackupDocument(data: data)
                        exporting = true
                    }
                } label: {
                    Label(tr("backup.saveFiles"), systemImage: "icloud.and.arrow.up")
                }
                .buttonStyle(.game(.green, small: true, wide: true))
                Button {
                    importing = true
                } label: {
                    Label(tr("backup.load"), systemImage: "icloud.and.arrow.down")
                }
                .buttonStyle(.game(.wood, small: true, wide: true))
                if let url = exportURL {
                    // Отправить файл, например себе в мессенджер
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up").font(.game(14, .black))
                    }
                    .buttonStyle(.game(.wood, small: true))
                }
            }
        }
        .onAppear { exportURL = game.exportBackup() }
        .fileExporter(isPresented: $exporting, document: document, contentType: .json,
                      defaultFilename: exportURL?.deletingPathExtension().lastPathComponent ?? "HarvestHollow") { result in
            if case .success = result { game.toast("px:scroll2", tr("backup.saved")) }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .data]) { result in
            guard case .success(let url) = result else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url), let restored = game.peekBackup(data) else {
                Dialogs.shared.info(tr("backup.bad"), message: tr("backup.bad.message"))
                return
            }
            Dialogs.shared.confirm(tr("backup.confirm", restored.level), message: tr("backup.confirm.message", game.save.level),
                                   icon: "px:scroll2", confirm: tr("backup.load"), tone: .orange) {
                game.restoreBackup(restored)
            }
        }
    }
}

/// Обратная связь: тема, по желанию файл прогресса, письмо с версией игры и моделью телефона.
struct FeedbackCard: View {
    @Environment(GameState.self) private var game
    @State private var topic: FeedbackTopic = .bug
    @State private var attachSave = true

    var body: some View {
        Card {
            HStack(spacing: 10) {
                PixelIcon(name: "quest", size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("feedback.title")).font(.game(15))
                    Text(tr("feedback.hint"))
                        .font(.game(11, .semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: 6) {
                ForEach(FeedbackTopic.allCases) { item in
                    let active = item == topic
                    Button {
                        withAnimation(.spring(duration: 0.25)) { topic = item }
                    } label: {
                        Label(item.title, systemImage: item.icon)
                            .font(.game(12, .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .foregroundStyle(active ? Color.white : Palette.ink)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(active ? ButtonTone.green.base : Palette.parchmentDeep.opacity(0.7)))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(active ? Palette.outline : Palette.woodDark.opacity(0.35), lineWidth: active ? 2 : 1.5))
                    }
                    .buttonStyle(.press)
                }
            }
            Toggle(isOn: $attachSave) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(tr("feedback.attach")).font(.game(13))
                    Text(tr("feedback.attach.hint")).font(.game(11, .semibold)).foregroundStyle(.secondary)
                }
            }
            .toggleStyle(GameToggleStyle())
            Button {
                Feedback.shared.compose(topic, attachSave: attachSave, game: game)
            } label: {
                Label(tr("feedback.write"), systemImage: "envelope.fill")
            }
            .buttonStyle(.game(.green, wide: true))
        }
    }
}
