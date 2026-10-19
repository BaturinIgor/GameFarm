import SwiftUI

struct MapView: View {
    @Environment(GameState.self) private var game
    let onTravel: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(LocationID.allCases) { id in
                        LocationCard(id: id, onTravel: onTravel)
                    }
                }
                .padding(16)
            }
            .sheetChrome("Карта", coins: game.save.coins)
        }
    }
}

struct LocationCard: View {
    @Environment(GameState.self) private var game
    let id: LocationID
    let onTravel: () -> Void

    var body: some View {
        let spec = id.spec
        let unlocked = game.isUnlocked(id)
        let here = game.save.current == id
        let levelOK = game.save.level >= spec.level
        let cost = game.unlockCost(id)
        let ground = Color(uiColor: spec.ground)

        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .leading) {
                LinearGradient(colors: [ground, Color(uiColor: spec.patches.last ?? spec.ground), Color(uiColor: spec.path)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                HStack(spacing: -6) {
                    Spacer()
                    ForEach(Array(spec.decor.prefix(3).enumerated()), id: \.offset) { item in
                        Text(item.element).font(.system(size: 22)).opacity(0.7)
                            .offset(y: item.offset % 2 == 0 ? -14 : 12)
                    }
                    Text(spec.emoji)
                        .font(.system(size: 58))
                        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                        .padding(.trailing, 10)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(spec.name).font(.headline)
                        if !unlocked {
                            Image(systemName: "lock.fill").font(.system(size: 12, weight: .bold))
                        }
                    }
                    Text(spec.blurb)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .frame(maxWidth: 230, alignment: .leading)
                .padding(10)
            }
            .frame(height: 104)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .saturation(unlocked ? 1 : 0.55)

            FlowLayout(spacing: 5) {
                ForEach(spec.resources) { kind in
                    ResourceIcon(kind: kind, size: 22)
                        .padding(4)
                        .background(Circle().fill(Color.secondary.opacity(0.12)))
                }
                ForEach(spec.wild) { animal in
                    Text(animal.spec.emoji)
                        .font(.system(size: 17))
                        .padding(4)
                        .background(Circle().fill(Color.pink.opacity(0.14)))
                        .opacity(game.stars(animal) > 0 ? 1 : 0.55)
                }
            }

            if here {
                Label("Ты здесь", systemImage: "mappin.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)
            } else if unlocked {
                Button {
                    game.travel(to: id)
                    onTravel()
                } label: {
                    Text("Перейти").font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
            } else {
                Divider()
                HStack {
                    Text("Чтобы открыть").font(.subheadline.bold())
                    Spacer()
                    Text("Ур. \(spec.level)")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(levelOK ? Color.green.opacity(0.18) : Color.red.opacity(0.15)))
                        .foregroundStyle(levelOK ? Color.primary : Color.red)
                }
                CostView(cost: cost)
                Button {
                    withAnimation(.spring(duration: 0.4)) {
                        if game.unlock(id) {
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    }
                } label: {
                    Text(levelOK ? "Открыть локацию" : "Нужен уровень \(spec.level)")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(!levelOK || !game.canAfford(cost))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(here ? Color.green.opacity(0.6) : ground.opacity(0.6), lineWidth: here ? 2 : 1.5)
        )
    }
}
