import SwiftUI

struct LevelView: View {
    @Environment(GameState.self) private var game
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    progressCard
                    bonusesCard
                    upcomingCard
                    statsCard
                    Button(role: .destructive) {
                        confirmReset = true
                    } label: {
                        Text("Начать игру заново")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 6)
                }
                .padding(16)
            }
            .sheetChrome("Уровень", coins: game.save.coins)
            .confirmationDialog("Удалить весь прогресс?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Удалить и начать заново", role: .destructive) { game.resetProgress() }
            } message: {
                Text("Уровень, ресурсы, звери и таланты обнулятся. Отменить это нельзя.")
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
                    Text("Уровень \(game.save.level)").font(.title3.bold())
                    if game.save.level < GameRules.maxLevel {
                        Text("\(Fmt.n(game.save.xp)) из \(Fmt.n(game.xpToNext)) опыта")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Text("Опыт дают добыча, приручение зверей и открытие локаций")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Достигнут максимальный уровень").font(.subheadline)
                    }
                }
            }
        }
    }

    private var bonusesCard: some View {
        let s = game.stats
        return Card {
            Text("Что сейчас даёт уровень и всё остальное").font(.headline)
            statRow("💪", "Урон", "x" + String(format: "%.2f", s.damageMult).replacingOccurrences(of: ".", with: ","))
            statRow("⚡", "Удар раз в", String(format: "%.2f с", s.hitInterval).replacingOccurrences(of: ".", with: ","))
            statRow("🎒", "Рюкзак", "\(s.capacity) мест")
            statRow("👟", "Скорость", "+\(Fmt.pct(s.speed / GameRules.baseSpeed - 1))")
            statRow("🧺", "Ресурсы с добычи", "+\(Fmt.pct(s.yieldAll))")
            statRow("📚", "Опыт", "+\(Fmt.pct(s.xpMult - 1))")
            statRow("💰", "Цена продажи", "+\(Fmt.pct(s.sellMult - 1))")
            statRow("🎯", "Шанс крита", Fmt.pct(s.critChance))
            statRow("🌱", "Восстановление ресурсов", "x" + String(format: "%.2f", 1 / s.respawnMult).replacingOccurrences(of: ".", with: ","))
            statRow("🌟", "Очки талантов", "\(game.talentPointsFree) свободно из \(game.talentPointsTotal)")
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
            Text("Скоро откроется").font(.headline)
            Text("Каждый уровень: +1 очко таланта, +5 мест в рюкзаке, +2% к урону, +1% к цене продажи и монеты")
                .font(.caption)
                .foregroundStyle(.secondary)
            if items.isEmpty {
                Text("Всё уже открыто").font(.subheadline)
            }
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text("Уровень \(item.level)").font(.subheadline.bold())
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
            Text("Статистика").font(.headline)
            statRow("⛏️", "Добыто раз", Fmt.n(game.save.harvests))
            statRow("🪙", "Заработано монет", Fmt.n(game.save.coinsEarned))
            statRow("🐾", "Зверей", "\(AnimalID.allCases.filter { game.stars($0) > 0 }.count) из \(AnimalID.allCases.count)")
            statRow("🗺️", "Локаций", "\(game.save.unlocked.count) из \(LocationID.allCases.count)")
            if !gathered.isEmpty {
                Text("Собрано всего").font(.caption.bold()).foregroundStyle(.secondary)
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
