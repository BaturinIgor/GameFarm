import SwiftUI

/// Плашка сверху в подземелье: этаж, волна и выход.
struct DungeonPill: View {
    @Environment(GameState.self) private var game

    var body: some View {
        if let run = game.dungeonRun, game.inDungeon {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(run.dungeon.name)
                        .font(.game(12))
                        .foregroundStyle(.white)
                        .outlined(Palette.outline, width: 1)
                        .lineLimit(1)
                    Text(run.cleared ? tr("dungeon.pill.cleared", run.floor) : tr("dungeon.pill", run.floor, max(1, run.wave), run.waves))
                        .font(.game(11))
                        .foregroundStyle(run.cleared ? Palette.gold : Color.white.opacity(0.9))
                        .outlined(Palette.outline, width: 1)
                }
                if run.cleared && game.canGoDeeper {
                    Button {
                        game.goDeeper()
                    } label: {
                        HStack(spacing: 3) {
                            Text(tr("dungeon.deeper"))
                            Image(systemName: "arrow.down.right").font(.system(size: 11, weight: .black))
                        }
                    }
                    .buttonStyle(.game(.green, small: true))
                }
                Button {
                    if run.cleared {
                        game.leaveDungeon()
                    } else {
                        Dialogs.shared.confirm(tr("dungeon.leave.confirm"), message: tr("dungeon.leave.message"), icon: "px:door",
                                               confirm: tr("dungeon.leave"), tone: .red) {
                            game.leaveDungeon()
                        }
                    }
                } label: {
                    Text(tr("dungeon.leave"))
                }
                .buttonStyle(.game(run.cleared ? .wood : .red, small: true))
            }
            .padding(.leading, 12)
            .padding(.trailing, 6)
            .padding(.vertical, 5)
            .woodPill(radius: 16, tint: Color(hex: run.dungeon.colors.1))
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

/// Полоска здоровья босса.
struct BossBar: View {
    @Environment(GameState.self) private var game

    var body: some View {
        if let boss = game.bossInfo {
            VStack(spacing: 3) {
                Text(boss.name)
                    .font(.game(13))
                    .foregroundStyle(.white)
                    .outlined(Palette.outline, width: 1)
                GameBar(value: boss.fraction, tone: .red, height: 14)
                    .frame(width: 220)
                    .animation(.easeOut(duration: 0.2), value: boss.fraction)
            }
            .transition(.opacity)
        }
    }
}

/// Кнопка зелья лечения в бою.
struct PotionButton: View {
    @Environment(GameState.self) private var game

    var body: some View {
        if game.save.potions > 0 && (game.inCombat || game.inDungeon) {
            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                Button {
                    game.drinkPotion()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        PixelIcon(name: "heart_plus", size: 34)
                            .frame(width: 52, height: 52)
                            .woodPill(radius: 26, tint: ButtonTone.red.base)
                        Text("\(game.save.potions)")
                            .font(.game(12))
                            .foregroundStyle(.white)
                            .outlined(Palette.outline, width: 1)
                            .padding(.horizontal, 5)
                            .background(Capsule().fill(Palette.outline.opacity(0.6)))
                            .offset(x: 4, y: 4)
                    }
                    .opacity(game.potionReady ? 1 : 0.5)
                }
                .buttonStyle(.press)
                .disabled(!game.potionReady || game.hpFraction >= 0.999)
            }
        }
    }
}

/// Итог забега.
struct DungeonReportOverlay: View {
    @Environment(GameState.self) private var game
    let report: DungeonReport
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Palette.dim.ignoresSafeArea().onTapGesture(perform: onClose)
            if report.won { ConfettiView().ignoresSafeArea().allowsHitTesting(false) }
            VStack(spacing: 12) {
                MonsterIcon(kind: report.dungeon.boss, size: 64)
                    .padding(.top, 26)
                Text(report.won ? tr("dungeon.report.won", report.floor) : tr("dungeon.report.lost", report.floor))
                    .font(.game(18))
                    .multilineTextAlignment(.center)
                if report.firstClear {
                    Text(tr("dungeon.report.first")).font(.game(13)).foregroundStyle(Palette.good)
                }
                HStack(spacing: 14) {
                    HStack(spacing: 4) { CoinIcon(size: 22); Text("+\(Fmt.n(report.coins))").font(.game(16)) }
                    HStack(spacing: 4) { ResourceIcon(kind: .essence, size: 22); Text("+\(report.essence)").font(.game(16)) }
                    if report.potions > 0 {
                        HStack(spacing: 4) { PixelIcon(name: "potion", size: 22); Text("+\(report.potions)").font(.game(16)) }
                    }
                    if report.maps > 0 {
                        HStack(spacing: 4) { PixelIcon(name: "tmap", size: 22); Text("+\(report.maps)").font(.game(16)) }
                    }
                }
                if let weapon = report.weapon {
                    HStack(spacing: 8) {
                        PixelIcon(name: "sword", size: 30).colorMultiply(Color(uiColor: weapon.color))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tr("dungeon.report.weapon", weapon.name)).font(.game(14))
                            Text(weapon.effectText).font(.game(11, .semibold)).foregroundStyle(Palette.good)
                        }
                    }
                    .padding(10)
                    .listBox(radius: 12)
                }
                // Сразу в бой: следующий этаж после победы или ещё раз этот же
                let next = report.floor + 1
                HStack(spacing: 8) {
                    if report.won && next <= Dungeon.floors && game.canEnter(report.dungeon, floor: next) {
                        Button {
                            onClose()
                            game.startDungeon(report.dungeon, floor: next)
                        } label: {
                            Text(tr("dungeon.floorN", next))
                        }
                        .buttonStyle(.game(.green, small: true, wide: true))
                    } else if game.canEnter(report.dungeon, floor: report.floor) {
                        Button {
                            onClose()
                            game.startDungeon(report.dungeon, floor: report.floor)
                        } label: {
                            Text(tr("dungeon.retry"))
                        }
                        .buttonStyle(.game(.orange, small: true, wide: true))
                    }
                    Button(tr("common.great"), action: onClose)
                        .buttonStyle(.game(.wood, small: true, wide: true))
                }
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .frame(maxWidth: 340)
            .gamePanel()
            .overlay(alignment: .top) {
                RibbonTitle(text: report.dungeon.name, tone: report.won ? .gold : .red, size: 18).offset(y: -16)
            }
            .popIn()
        }
    }
}

/// Список подземелий у стражника.
struct DungeonList: View {
    @Environment(GameState.self) private var game
    let onEnter: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            PotionShopCard()
            ForEach(DungeonID.allCases) { DungeonCard(id: $0, onEnter: onEnter) }
            SectionTitle(text: tr("dungeon.soon"))
            ForEach(ComingDungeon.allCases) { soon in
                Card {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Palette.inkSoft)
                            .frame(width: 52, height: 52)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.parchmentDeep.opacity(0.7)))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(soon.name).font(.game(15))
                            Text(soon.blurb).font(.game(11, .semibold)).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Text(tr("dungeon.soon.tag"))
                            .font(.game(11))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(ButtonTone.purple.base))
                    }
                }
                .opacity(0.8)
            }
            Text(tr("dungeon.tip"))
                .font(.game(11, .semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

private struct PotionShopCard: View {
    @Environment(GameState.self) private var game

    var body: some View {
        Card(tint: ButtonTone.red.base.opacity(0.6)) {
            HStack(spacing: 12) {
                PixelIcon(name: "heart_plus", size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("potion.title", game.save.potions)).font(.game(15))
                    Text(tr("potion.hint", Fmt.pct(Potion.heal))).font(.game(11, .semibold)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                ForEach([1, 5], id: \.self) { n in
                    Button {
                        game.buyPotions(n)
                    } label: {
                        HStack(spacing: 4) {
                            Text("x\(n)")
                            CoinIcon(size: 14)
                            Text(Fmt.n(game.potionPrice(n)))
                        }
                    }
                    .buttonStyle(.game(.red, small: true, wide: true))
                    .disabled(game.save.coins < game.potionPrice(n))
                }
            }
        }
    }
}

private struct DungeonCard: View {
    @Environment(GameState.self) private var game
    let id: DungeonID
    let onEnter: () -> Void
    @State private var floor = 1

    var body: some View {
        let best = game.dungeonBest(id)
        let open = game.save.level >= id.level
        let maxFloor = min(Dungeon.floors, best + 1)
        let colors = id.colors
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                MonsterIcon(kind: id.boss, size: 52)
                    .frame(width: 62, height: 62)
                    .background(Circle().fill(Color.black.opacity(0.25)))
                    .saturation(open ? 1 : 0)
                VStack(alignment: .leading, spacing: 3) {
                    Text(id.name).gameTitle(17)
                    Text(id.blurb).font(.game(11, .semibold)).foregroundStyle(.white.opacity(0.92))
                        .outlined(Palette.outline.opacity(0.6), width: 1)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            // Этажи: пройденные, текущий и закрытые
            HStack(spacing: 4) {
                ForEach(1...Dungeon.floors, id: \.self) { f in
                    let done = f <= best
                    let boss = Dungeon.isBossFloor(f)
                    Text("\(f)")
                        .font(.game(10))
                        .foregroundStyle(done ? Color.white : Palette.inkSoft)
                        .frame(maxWidth: .infinity)
                        .frame(height: 22)
                        .background(RoundedRectangle(cornerRadius: 6).fill(done ? ButtonTone.green.base : Palette.parchmentLight.opacity(0.85)))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(boss ? Palette.gold : Palette.outline.opacity(0.5),
                                                                              lineWidth: boss ? 2 : 1))
                }
            }
            if open {
                HStack(spacing: 8) {
                    Button { floor = max(1, floor - 1) } label: { Image(systemName: "chevron.left") }
                        .buttonStyle(.game(.wood, small: true))
                        .disabled(floor <= 1)
                    VStack(spacing: 1) {
                        Text(tr("dungeon.floor", floor)).font(.game(14)).foregroundStyle(.white).outlined(Palette.outline, width: 1)
                        Text(tr("dungeon.monsterLevel", Dungeon.monsterLevel(id, floor: floor)))
                            .font(.game(10)).foregroundStyle(.white.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity)
                    Button { floor = min(maxFloor, floor + 1) } label: { Image(systemName: "chevron.right") }
                        .buttonStyle(.game(.wood, small: true))
                        .disabled(floor >= maxFloor)
                }
                HStack(spacing: 10) {
                    let first = floor > best
                    HStack(spacing: 3) { CoinIcon(size: 15); Text(Fmt.n(Dungeon.coins(id, floor: floor, first: first))).font(.game(12)) }
                    HStack(spacing: 3) { ResourceIcon(kind: .essence, size: 15); Text("\(Dungeon.essence(id, floor: floor, first: first))").font(.game(12)) }
                    if Dungeon.isBossFloor(floor) && !game.ownsWeapon(id.weapon) {
                        HStack(spacing: 3) {
                            PixelIcon(name: "sword", size: 15).colorMultiply(Color(uiColor: id.weapon.color))
                            Text(id.weapon.name).font(.game(11)).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.white)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.25)))
                Button {
                    game.startDungeon(id, floor: floor)
                    onEnter()
                } label: {
                    Label(Dungeon.isBossFloor(floor) ? tr("dungeon.enterBoss") : tr("dungeon.enter"), systemImage: "figure.walk")
                }
                .buttonStyle(.game(Dungeon.isBossFloor(floor) ? .orange : .green, wide: true))
                .disabled(!game.canEnter(id, floor: floor))
            } else {
                Label(tr("common.needLevel", id.level), systemImage: "lock.fill")
                    .font(.game(13))
                    .foregroundStyle(.white)
                    .outlined(Palette.outline, width: 1)
            }
        }
        .padding(14)
        .background(shape.fill(LinearGradient(colors: [Color(hex: colors.0), Color(hex: colors.1)], startPoint: .top, endPoint: .bottom)))
        .overlay(shape.strokeBorder(Palette.outline, lineWidth: 3))
        .background(shape.fill(Palette.outline.opacity(0.5)).offset(y: 4))
        .onAppear { floor = maxFloor }
    }
}
