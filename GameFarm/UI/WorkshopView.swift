import SwiftUI

struct WorkshopView: View {
    @Environment(GameState.self) private var game
    @State private var tab: GearTab = .gathering

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                GameTabs(selection: $tab, items: GearTab.allCases.map { ($0, $0.title) },
                         badges: Dictionary(uniqueKeysWithValues: GearTab.allCases.map { t in
                             (t, t.tools.filter { game.canUpgradeNow($0) }.count)
                         }))
                Text(tr("gear.hint.\(tab.rawValue)"))
                    .font(.game(12, .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if tab == .defense {
                    HeroDefenseCard()
                }
                ForEach(tab.tools) { tool in
                    ToolCard(tool: tool)
                }
                if tab == .weapons {
                    SectionTitle(text: tr("weapon.special"))
                    ForEach(WeaponID.allCases.filter { $0 != .forged }) { WeaponCard(id: $0) }
                }
            }
            .padding(16)
        }
        .sheetChrome(tr("hud.workshop"), coins: game.save.coins)
    }
}

/// Итог защиты героя: здоровье, броня, уклонение.
private struct HeroDefenseCard: View {
    @Environment(GameState.self) private var game

    var body: some View {
        Card(tint: ButtonTone.blue.base.opacity(0.5)) {
            HStack(spacing: 14) {
                stat("heart", Fmt.n(Int(game.maxHP)), tr("gear.stat.hp"))
                stat("shield", Fmt.pct(game.defense), tr("gear.stat.defense"))
                stat("eye", Fmt.pct(game.dodgeChance), tr("gear.stat.dodge"))
                stat("sword", Fmt.n(Int(game.weaponDamage().rounded())), tr("gear.stat.damage"))
            }
        }
    }

    private func stat(_ icon: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            PixelIcon(name: icon, size: 24)
            Text(value).font(.game(14)).monospacedDigit()
            Text(label).font(.game(10, .semibold)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Особое оружие: где взять, свойство, ступень, надеть и улучшить.
private struct WeaponCard: View {
    @Environment(GameState.self) private var game
    let id: WeaponID

    var body: some View {
        let owned = game.ownsWeapon(id)
        let tier = game.weaponTier(id)
        let equipped = game.save.weapon == id
        Card(tint: equipped ? ButtonTone.gold.base : .clear) {
            HStack(spacing: 12) {
                PixelIcon(name: "sword", size: 34)
                    .colorMultiply(Color(uiColor: id.color))
                    .frame(width: 52, height: 52)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.parchmentDeep.opacity(0.7)))
                    .opacity(owned ? 1 : 0.4)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(id.name).font(.game(15))
                        if owned { Text(tr("common.lvl", tier)).font(.game(11)).foregroundStyle(Palette.inkSoft) }
                    }
                    Text(id.effectText).font(.game(11, .semibold)).foregroundStyle(Palette.good)
                    if owned && game.effectiveWeaponTier(id) < tier {
                        // Ступень выше доступной по уровню: пока работает слабее
                        Text(tr("weapon.capped", game.effectiveWeaponTier(id)))
                            .font(.game(11, .semibold))
                            .foregroundStyle(ButtonTone.orange.lip)
                    }
                    if !owned {
                        Text(id.source).font(.game(11, .semibold)).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            if owned {
                HStack(spacing: 8) {
                    Button {
                        game.equip(id)
                    } label: {
                        Text(equipped ? tr("weapon.equipped") : tr("weapon.equip"))
                    }
                    .buttonStyle(.game(equipped ? .green : .wood, small: true, wide: true))
                    .disabled(equipped)
                    if game.weaponUpgradeCost(id) != nil {
                        let need = ToolTier.requiredLevel(.sword, tier: tier + 1)
                        Button {
                            game.upgradeWeapon(id)
                        } label: {
                            Text(game.save.level >= need ? tr("common.upgrade") : tr("common.needLevel", need))
                        }
                        .buttonStyle(.game(.green, small: true, wide: true))
                        .disabled(!game.canUpgradeWeapon(id))
                    }
                }
                if let cost = game.weaponUpgradeCost(id) {
                    CostView(cost: cost)
                }
            }
        }
    }
}

struct ToolCard: View {
    @Environment(GameState.self) private var game
    let tool: ToolKind

    private func nodes(for tier: Int, exact: Bool) -> [NodeType] {
        NodeType.allCases.filter { type in
            let spec = type.spec
            guard spec.tool == tool else { return false }
            return exact ? spec.tier == tier : spec.tier <= tier
        }
    }

    var body: some View {
        let tier = game.tier(tool)
        let next = tier + 1
        let color = Color(uiColor: ToolTier.color(tier))
        Card(tint: color) {
            HStack(spacing: 12) {
                PixelIcon(name: tool.icon, size: 36, fallback: tool.emoji)
                    .frame(width: 58, height: 58)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(color.opacity(0.25)))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.outline.opacity(0.7), lineWidth: 2))
                VStack(alignment: .leading, spacing: 3) {
                    Text(ToolTier.name(tool, tier: tier))
                        .font(.game(16))
                    Group {
                        switch tool {
                        case .armor:
                            Text(tr("workshop.armor", tier, ToolTier.maxTier, Int(game.maxHP)))
                        case .sword:
                            Text(tr("workshop.sword", tier, ToolTier.maxTier,
                                    Int((Hero.swordDamage(level: game.save.level, sword: tier) * game.stats.damageMult * game.stats.swordMult).rounded())))
                        case .helmet:
                            Text(tr("workshop.helmet", tier, ToolTier.maxTier, Fmt.pct(Hero.defense(helmet: tier))))
                        case .boots:
                            Text(tr("workshop.boots", tier, ToolTier.maxTier, Fmt.pct(Hero.dodge(boots: tier)), Fmt.pct(Hero.speed(boots: tier))))
                        default:
                            Text(tr("workshop.tier", tier, ToolTier.maxTier, Fmt.decimal(ToolTier.power(tier), digits: 1)))
                        }
                    }
                        .font(.game(12, .semibold))
                        .foregroundStyle(.secondary)
                    Text(tool.purpose)
                        .font(.game(12, .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            let available = nodes(for: tier, exact: false)
            if !available.isEmpty {
                Text(tr("workshop.gathers")).font(.game(12)).foregroundStyle(.secondary)
                FlowLayout(spacing: 6) {
                    ForEach(available, id: \.self) { NodeChip(type: $0) }
                }
            }

            PerkList(tool: tool, tier: tier)

            if next <= ToolTier.maxTier, let cost = game.nextToolCost(tool) {
                PaperDivider()
                let needLevel = ToolTier.requiredLevel(tool, tier: next)
                let levelOK = game.save.level >= needLevel
                HStack {
                    Text(tr("talents.next", ToolTier.name(tool, tier: next)))
                        .font(.game(14, .semibold).bold())
                    Spacer()
                    LevelTag(level: needLevel, ok: levelOK)
                }
                let opens = nodes(for: next, exact: true)
                if !opens.isEmpty {
                    HStack(spacing: 6) {
                        Text(tr("workshop.opens")).font(.game(12, .semibold)).foregroundStyle(.secondary)
                        FlowLayout(spacing: 6) {
                            ForEach(opens, id: \.self) { NodeChip(type: $0) }
                        }
                    }
                }
                CostView(cost: cost)
                Button {
                    withAnimation(.spring(duration: 0.4)) {
                        if game.upgradeTool(tool) {
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    }
                } label: {
                    Text(levelOK ? tr("workshop.upgrade") : tr("common.needLevel", needLevel))
                }
                .buttonStyle(.game(.green, wide: true))
                .disabled(!levelOK || !game.canAfford(cost))
            } else {
                PaperDivider()
                Label(tr("workshop.maxTier"), systemImage: "checkmark.seal.fill")
                    .font(.game(14))
                    .foregroundStyle(Palette.good)
            }
        }
    }
}


/// Бонусы ступеней: открытые подсвечены, следующие - серые.
private struct PerkList: View {
    let tool: ToolKind
    let tier: Int

    var body: some View {
        let perks = ToolPerk.list(tool)
        if !perks.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(perks) { perk in
                    let open = tier >= perk.tier
                    HStack(alignment: .top, spacing: 6) {
                        Text(tr("common.lvl", perk.tier))
                            .font(.game(10))
                            .foregroundStyle(open ? .white : Palette.inkSoft)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(open ? ButtonTone.green.base : Palette.parchmentDeep))
                        Text(perk.text)
                            .font(.game(11, .semibold))
                            .foregroundStyle(open ? Palette.ink : Palette.inkSoft.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .listBox(radius: 10)
        }
    }
}
