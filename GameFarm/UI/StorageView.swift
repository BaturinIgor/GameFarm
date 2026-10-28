import SwiftUI

/// Вкладки склада.
enum StorageTab: String, CaseIterable, Identifiable {
    case materials, food, loot, rare

    var id: String { rawValue }
    var title: String { tr("storage.tab.\(rawValue)") }

    var categories: [ResourceCategory] {
        switch self {
        case .materials: [.wood, .stone, .ore]
        case .food: [.crop, .food, .farm]
        case .loot: [.loot]
        case .rare: [.gem, .treasure]
        }
    }
}

struct StorageView: View {
    @Environment(GameState.self) private var game
    @State private var tab: StorageTab = .materials

    private func kinds(_ tab: StorageTab) -> [ResourceKind] {
        tab.categories.flatMap { ResourceKind.ordered(in: $0) }.filter { (game.save.storage[$0] ?? 0) > 0 }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if game.backpackCount > 0 {
                    backpackCard
                }
                GameTabs(selection: $tab, items: StorageTab.allCases.map { ($0, $0.title) })
                let list = kinds(tab)
                if list.isEmpty {
                    Card {
                        Text(totalStored == 0 ? tr("storage.empty") : tr("storage.tabEmpty"))
                            .font(.game(16))
                        Text(tr("storage.empty.hint"))
                            .font(.game(14, .semibold))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(tab.categories) { category in
                        let rows = list.filter { $0.category == category }
                        if !rows.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                if tab.categories.count > 1 { SectionTitle(text: category.title) }
                                VStack(spacing: 0) {
                                    ForEach(rows) { kind in
                                        StorageRow(kind: kind)
                                        if kind != rows.last {
                                            PaperDivider().padding(.leading, 56)
                                        }
                                    }
                                }
                                .listBox()
                            }
                        }
                    }
                    sellTabButton(list)
                }
                Text(tr("storage.priceHint"))
                    .font(.game(12, .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding(16)
        }
        .sheetChrome(tr("hud.storage"), coins: game.save.coins)
    }

    /// Продать всё во вкладке, с подтверждением и суммой.
    private func sellTabButton(_ list: [ResourceKind]) -> some View {
        let total = list.reduce(0) { $0 + (game.save.storage[$1] ?? 0) * game.sellPrice($1) }
        return Button {
            Dialogs.shared.confirm(tr("storage.sellTab.confirm", tab.title), message: tr("storage.sellTab.message", Fmt.n(total)),
                                   icon: "px:coins", confirm: tr("storage.sellAll"), tone: .green) {
                withAnimation(.snappy) {
                    for kind in list { game.sell(kind, game.save.storage[kind] ?? 0) }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(tr("storage.sellTab"))
                CoinIcon(size: 16)
                Text(Fmt.n(total)).monospacedDigit()
            }
        }
        .buttonStyle(.game(.wood, small: true, wide: true))
    }

    private var totalStored: Int { game.save.storage.values.reduce(0, +) }

    private var backpackCard: some View {
        Card(tint: ButtonTone.orange.base) {
            HStack {
                Text(tr("storage.inBackpack"))
                    .font(.game(16))
                Spacer()
                Text("\(game.backpackCount)/\(game.stats.capacity)")
                    .font(.game(14, .semibold).bold())
                    .monospacedDigit()
            }
            FlowLayout(spacing: 6) {
                ForEach(ResourceKind.allCases.filter { (game.save.backpack[$0] ?? 0) > 0 }) { kind in
                    HStack(spacing: 4) {
                        ResourceIcon(kind: kind, size: 18)
                        Text(Fmt.n(game.save.backpack[kind] ?? 0))
                            .font(.game(13, .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color(hex: 0xFBE3C2)))
                    .overlay(Capsule().strokeBorder(ButtonTone.orange.base.opacity(0.5), lineWidth: 1.5))
                }
            }
            Text(tr("storage.backpackHint"))
                .font(.game(12, .semibold))
                .foregroundStyle(.secondary)
        }
    }
}

struct StorageRow: View {
    @Environment(GameState.self) private var game
    let kind: ResourceKind

    var body: some View {
        let have = game.save.storage[kind] ?? 0
        let price = game.sellPrice(kind)
        HStack(spacing: 12) {
            ResourceIcon(kind: kind, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.name).font(.game(15, .semibold))
                Text.withCoins(tr("storage.row", Fmt.n(have), price), size: 12)
                    .font(.game(12, .semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer(minLength: 4)
            HStack(spacing: 6) {
                if have >= 10 {
                    sellButton("10", amount: 10)
                }
                sellButton(have >= 10 ? tr("storage.sellAll") : tr("storage.sell"), amount: have)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func sellButton(_ title: String, amount: Int) -> some View {
        Button {
            withAnimation(.snappy) { game.sell(kind, amount) }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text(title)
        }
        .buttonStyle(.game(amount == 10 ? .wood : .green, small: true))
    }
}
