import SwiftUI

/// Пиксельный спрайт из набора в интерфейсе: scale точек на пиксель арта.
struct PixelSprite: View {
    let name: String
    var scale: CGFloat = 2.5

    var body: some View {
        if let image = Sprites.crisp(name, scale: 4) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.none)
                .frame(width: image.size.width / 4 * scale, height: image.size.height / 4 * scale)
        } else {
            Text("🪑").font(.system(size: 16 * scale))
        }
    }
}

/// Дом в разрезе: чердак, второй этаж, первый этаж и подвал. Этажи строятся, в комнатах есть
/// кухня, календарь, кровать и гардероб, а на каждом этаже три места для украшений.
struct HouseView: View {
    @Environment(GameState.self) private var game
    @Environment(\.gameActions) private var actions
    @State private var pickingSlot: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                roof
                VStack(spacing: 0) {
                    ForEach(HouseFloor.allCases) { floor in
                        if floor == .basement {
                            grassLine
                        }
                        FloorRoom(floor: floor, onSlot: { pickingSlot = $0 })
                    }
                }
                .overlay(Rectangle().strokeBorder(Palette.woodDark, lineWidth: 6))
                .overlay(Rectangle().strokeBorder(Palette.outline, lineWidth: 2))
                comfortCard
                    .padding(.top, 16)
            }
            .padding(16)
        }
        .sheetChrome(tr("house.title"), coins: game.save.coins)
        .overlay {
            if let slot = pickingSlot {
                DecorPicker(slot: slot) { pickingSlot = nil }
                    .transition(.opacity)
            }
        }
        .animation(.snappy(duration: 0.2), value: pickingSlot)
    }

    private var roof: some View {
        ZStack(alignment: .bottom) {
            RoofShape()
                .fill(LinearGradient(colors: [Color(hex: 0xC2493A), Color(hex: 0x8E2E25)], startPoint: .top, endPoint: .bottom))
                .overlay(RoofShape().stroke(Palette.outline, lineWidth: 2.5))
                .frame(height: 70)
            Rectangle()
                .fill(Color(hex: 0x6E3A24))
                .frame(width: 22, height: 34)
                .overlay(Rectangle().strokeBorder(Palette.outline, lineWidth: 2))
                .offset(x: 80, y: -46)
        }
        .padding(.horizontal, -6)
    }

    private var grassLine: some View {
        Rectangle()
            .fill(LinearGradient(colors: [Color(hex: 0x5AC54F), Color(hex: 0x33984B)], startPoint: .top, endPoint: .bottom))
            .frame(height: 10)
            .overlay(alignment: .bottom) { Rectangle().fill(Color(hex: 0x6E4A2A)).frame(height: 3) }
    }

    private var comfortCard: some View {
        Card(tint: Palette.goldDark) {
            HStack(spacing: 10) {
                Text("🛋️").font(.system(size: 28))
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("house.comfort", game.comfort)).font(.game(15))
                    Text(tr("house.comfort.bonus", Fmt.pct(Comfort.bonus(game.comfort))))
                        .font(.game(12, .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct RoofShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// Одна комната дома в разрезе.
private struct FloorRoom: View {
    @Environment(GameState.self) private var game
    @Environment(\.gameActions) private var actions
    let floor: HouseFloor
    let onSlot: (String) -> Void

    private var wall: [Color] {
        switch floor {
        case .attic: [Color(hex: 0xB07A4A), Color(hex: 0x8A5A34)]
        case .upper: [Color(hex: 0x9CC4E4), Color(hex: 0x7AA8D0)]
        case .ground: [Color(hex: 0xF4DCA8), Color(hex: 0xE8C88A)]
        case .basement: [Color(hex: 0x8A8698), Color(hex: 0x6C6878)]
        }
    }

    var body: some View {
        let built = game.isBuilt(floor)
        ZStack(alignment: .topLeading) {
            background
            if built {
                furniture
                slots
            }
            Text(floor.title + (built ? " · " + floor.room : ""))
                .font(.game(11))
                .foregroundStyle(.white)
                .outlined(Palette.outline, width: 1)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Palette.woodDark.opacity(0.85)))
                .padding(8)
            if !built {
                LockedFloor(floor: floor)
            }
        }
        .frame(height: 168)
        .clipped()
    }

    private var background: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: wall, startPoint: .top, endPoint: .bottom)
            // Полоски обоев или кладка
            HStack(spacing: 22) {
                ForEach(0..<16, id: \.self) { _ in
                    Rectangle().fill(Color.white.opacity(floor == .basement ? 0.06 : 0.12)).frame(width: 6)
                }
            }
            VStack(spacing: 0) {
                Rectangle().fill(Palette.woodDark).frame(height: 3)
                Rectangle()
                    .fill(LinearGradient(colors: [Color(hex: 0xA66A40), Color(hex: 0x7A4A2C)], startPoint: .top, endPoint: .bottom))
                    .frame(height: 16)
            }
        }
    }

    /// Ставит предмет на пол комнаты: низ предмета на уровне пола.
    private func onFloor<V: View>(_ view: V, x: CGFloat, width w: CGFloat, height: CGFloat = 96) -> some View {
        view
            .frame(width: 110, height: height, alignment: .bottom)
            .position(x: w * x, y: 168 - 19 - height / 2)
    }

    @ViewBuilder
    private var furniture: some View {
        GeometryReader { geo in
            let w = geo.size.width
            switch floor {
            case .ground:
                PixelSprite(name: "window", scale: 2.2).position(x: w * 0.5, y: 50)
                onFloor(tappable(PixelSprite(name: "stove", scale: 2.4), label: tr("house.kitchen")) { actions.open(.kitchen) },
                        x: 0.14, width: w)
                onFloor(PixelSprite(name: "table_small", scale: 2.4), x: 0.5, width: w)
                tappable(PixelSprite(name: "ic_calendar", scale: 2.3), label: tr("house.calendar"), badge: game.canClaimLogin) {
                    actions.open(.calendar)
                }
                .position(x: w * 0.85, y: 58)
            case .upper:
                PixelSprite(name: "window", scale: 2.2).position(x: w * 0.5, y: 50)
                onFloor(tappable(PixelSprite(name: "bed", scale: 2.3), label: tr("house.bed")) {
                    Dialogs.shared.info(tr("house.bed"), message: tr("house.perk.upper"), icon: "🛏️")
                }, x: 0.18, width: w)
                onFloor(tappable(PixelSprite(name: "wardrobe", scale: 2.3), label: tr("wardrobe.title")) { actions.open(.wardrobe) },
                        x: 0.85, width: w)
            case .basement:
                onFloor(PixelSprite(name: "barrel_water", scale: 2.3), x: 0.1, width: w)
                onFloor(PixelSprite(name: "barrel_berries", scale: 2.3), x: 0.9, width: w)
                onFloor(tappable(PixelSprite(name: "stove", scale: 2.2), label: tr("house.kitchen")) { actions.open(.kitchen) },
                        x: 0.5, width: w)
            case .attic:
                PixelSprite(name: "window", scale: 2.0).position(x: w * 0.5, y: 50)
                onFloor(PixelSprite(name: "bookshelf", scale: 2.2), x: 0.14, width: w)
                onFloor(tappable(Text("🔭").font(.system(size: 40)), label: tr("house.telescope")) {
                    Dialogs.shared.info(tr("house.telescope"), message: tr("house.perk.attic"), icon: "🔭")
                }, x: 0.86, width: w)
            }
        }
    }

    private var slotXs: [CGFloat] {
        switch floor {
        case .ground: [0.3, 0.7, 0.86]
        case .upper: [0.4, 0.53, 0.66]
        case .basement: [0.24, 0.36, 0.72]
        case .attic: [0.36, 0.5, 0.64]
        }
    }

    /// Три места для украшений вдоль пола.
    private var slots: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ForEach(Array(floor.slots.enumerated()), id: \.offset) { i, slot in
                Button {
                    if let decor = game.decor(at: slot) {
                        Dialogs.shared.confirm(tr("decor.remove", decor.name), message: tr("decor.remove.message"), icon: "🧹",
                                               confirm: tr("decor.remove.action"), tone: .red) {
                            game.removeDecor(at: slot)
                        }
                    } else {
                        onSlot(slot)
                    }
                } label: {
                    if let decor = game.decor(at: slot) {
                        PixelSprite(name: decor.sprite, scale: 2.0)
                    } else {
                        Image(systemName: "plus")
                            .font(.game(14))
                            .foregroundStyle(Palette.woodDark.opacity(0.7))
                            .frame(width: 34, height: 34)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.25)))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.woodDark.opacity(0.6),
                                                                                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
                    }
                }
                .buttonStyle(.press)
                .frame(width: 80, height: 76, alignment: .bottom)
                .position(x: w * slotXs[i], y: 168 - 19 - 38)
            }
        }
    }

    private func tappable<V: View>(_ view: V, label: String, badge: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                view
                Text(label)
                    .font(.game(10))
                    .foregroundStyle(.white)
                    .outlined(Palette.outline, width: 1)
                    .lineLimit(1)
            }
            .overlay(alignment: .topTrailing) {
                if badge { CountBadge(count: 1).offset(x: 8, y: -6) }
            }
        }
        .buttonStyle(.press)
    }
}

/// Этаж ещё не построен: что даст и сколько стоит.
private struct LockedFloor: View {
    @Environment(GameState.self) private var game
    let floor: HouseFloor

    var body: some View {
        let levelOK = game.save.level >= floor.level
        ZStack {
            Palette.woodDark.opacity(0.88)
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill").font(.game(13))
                    Text(floor.title + " · " + floor.room).font(.game(14))
                    LevelTag(level: floor.level, ok: levelOK)
                }
                .foregroundStyle(.white)
                Text(floor.perk)
                    .font(.game(11, .semibold))
                    .foregroundStyle(Palette.parchment)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                CostView(cost: floor.cost)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Palette.parchmentLight))
                Button {
                    withAnimation(.spring(duration: 0.35)) {
                        if game.build(floor) { UINotificationFeedbackGenerator().notificationOccurred(.success) }
                    }
                } label: {
                    Text(levelOK ? tr("house.build") : tr("common.needLevel", floor.level))
                }
                .buttonStyle(.game(.green, small: true))
                .disabled(!game.canBuild(floor))
            }
            .padding(.horizontal, 14)
            .padding(.top, 24)
        }
    }
}

/// Выбор украшения для свободного места.
private struct DecorPicker: View {
    @Environment(GameState.self) private var game
    let slot: String
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Palette.dim.ignoresSafeArea().onTapGesture(perform: onClose)
            VStack(spacing: 10) {
                Text(tr("decor.pick")).font(.game(17)).padding(.top, 6)
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(DecorID.allCases) { decor in
                            HStack(spacing: 10) {
                                PixelSprite(name: decor.sprite, scale: 1.8)
                                    .frame(width: 60, height: 52)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Palette.parchmentDeep.opacity(0.7)))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(decor.name).font(.game(14))
                                    Text(tr("decor.comfort", decor.comfort)).font(.game(11)).foregroundStyle(Palette.good)
                                    CostView(cost: decor.cost)
                                }
                                Spacer(minLength: 4)
                                Button {
                                    if game.place(decor, at: slot) { onClose() }
                                } label: {
                                    Text(tr("common.buy"))
                                }
                                .buttonStyle(.game(.green, small: true))
                                .disabled(!game.canPlace(decor))
                            }
                            .padding(8)
                            .listBox(radius: 12)
                        }
                    }
                    .padding(4)
                }
                .frame(maxHeight: 420)
                Button(tr("common.close"), action: onClose)
                    .buttonStyle(.game(.wood, small: true))
            }
            .foregroundStyle(Palette.ink)
            .padding(14)
            .frame(maxWidth: 380)
            .gamePanel()
            .padding(20)
        }
    }
}

// MARK: Кухня

struct KitchenView: View {
    @Environment(GameState.self) private var game

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                stoveCard
                if let meal = game.activeMeal {
                    mealCard(meal)
                }
                if game.totalDishes > 0 {
                    SectionTitle(text: tr("kitchen.pantry"))
                    ForEach(DishID.allCases.filter { game.dishes($0) > 0 }) { dish in
                        pantryRow(dish)
                    }
                }
                SectionTitle(text: tr("kitchen.recipes"))
                ForEach(DishID.allCases) { RecipeRow(dish: $0) }
            }
            .padding(16)
        }
        .sheetChrome(tr("house.kitchen"), coins: game.save.coins)
        .task {
            while !Task.isCancelled {
                game.collectDishes()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private var stoveCard: some View {
        Card(tint: ButtonTone.orange.base) {
            HStack(spacing: 12) {
                PixelSprite(name: "stove", scale: 2)
                VStack(alignment: .leading, spacing: 6) {
                    Text(tr("kitchen.stove", game.save.cooking.count, game.cookSlots)).font(.game(15))
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(game.save.cooking) { job in
                                let left = max(0, job.readyAt.timeIntervalSince(context.date))
                                HStack(spacing: 6) {
                                    PixelIcon(name: job.dish.icon, size: 20, fallback: job.dish.emoji)
                                    GameBar(value: 1 - left / job.dish.cookTime, tone: .orange, height: 14,
                                            label: Countdown.text(left))
                                }
                            }
                            if game.save.cooking.isEmpty {
                                Text(tr("kitchen.idle")).font(.game(12, .semibold)).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func mealCard(_ meal: DishID) -> some View {
        Card(tint: ButtonTone.green.base) {
            HStack(spacing: 10) {
                PixelIcon(name: meal.icon, size: 34, fallback: meal.emoji)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("kitchen.eaten", meal.name)).font(.game(14))
                    Text(meal.effectText).font(.game(12, .semibold)).foregroundStyle(Palette.good)
                    if let until = game.save.mealUntil {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Label(Countdown.text(until.timeIntervalSince(context.date)), systemImage: "clock")
                                .font(.game(12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func pantryRow(_ dish: DishID) -> some View {
        HStack(spacing: 10) {
            PixelIcon(name: dish.icon, size: 30, fallback: dish.emoji)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(dish.name) x\(game.dishes(dish))").font(.game(14))
                Text(dish.effectText).font(.game(11, .semibold)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Button(tr("kitchen.eat")) {
                withAnimation(.snappy) { game.eat(dish) }
            }
            .buttonStyle(.game(.green, small: true))
        }
        .padding(10)
        .listBox(radius: 14)
    }
}

private struct RecipeRow: View {
    @Environment(GameState.self) private var game
    let dish: DishID

    var body: some View {
        Card {
            HStack(spacing: 10) {
                PixelIcon(name: dish.icon, size: 34, fallback: dish.emoji)
                    .frame(width: 46, height: 46)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.parchmentDeep.opacity(0.7)))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.woodDark.opacity(0.4), lineWidth: 1.5))
                VStack(alignment: .leading, spacing: 3) {
                    Text(dish.name).font(.game(15))
                    Text(dish.effectText + " · " + Fmt.seconds(dish.duration)).font(.game(11, .bold)).foregroundStyle(Palette.good)
                }
                Spacer(minLength: 0)
            }
            CostView(cost: Cost(coins: 0, items: dish.ingredients))
            Button {
                withAnimation(.snappy) {
                    if game.cook(dish) { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                }
            } label: {
                Label(tr("kitchen.cook", Fmt.seconds(dish.cookTime)), systemImage: "flame.fill")
            }
            .buttonStyle(.game(.orange, small: true, wide: true))
            .disabled(!game.canCook(dish))
        }
    }
}

/// Блюдо, которое сейчас действует, на главном экране.
struct MealPill: View {
    @Environment(GameState.self) private var game
    let onTap: () -> Void

    var body: some View {
        if let meal = game.activeMeal, let until = game.save.mealUntil {
            Button(action: onTap) {
                HStack(spacing: 4) {
                    PixelIcon(name: meal.icon, size: 18, fallback: meal.emoji)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(Countdown.text(until.timeIntervalSince(context.date)))
                            .font(.game(12))
                            .foregroundStyle(.white)
                            .outlined(Palette.outline, width: 1)
                            .monospacedDigit()
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .woodPill(radius: 13, tint: ButtonTone.green.base)
            }
            .buttonStyle(.press)
        }
    }
}

/// Карточка у двери дома или у загона.
struct PlaceCard: View {
    @Environment(GameState.self) private var game
    let kind: PlaceKind
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(kind == .house ? "🏠" : "🐾").font(.system(size: 34))
            VStack(alignment: .leading, spacing: 2) {
                Text(kind == .house ? tr("house.title") : tr("pen.title")).font(.game(15))
                Text(kind == .house ? tr("house.hint")
                                    : tr("pen.count", AnimalID.allCases.filter { game.stars($0) > 0 }.count))
                    .font(.game(12, .semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Button(action: onOpen) {
                Text(kind == .house ? tr("house.enter") : tr("hud.animals"))
            }
            .buttonStyle(.game(kind == .house ? .orange : .green))
            .overlay(alignment: .topTrailing) {
                if kind == .house && (game.canClaimLogin || game.save.cooking.contains { $0.readyAt <= Date() }) {
                    CountBadge(count: 1).offset(x: 6, y: -8)
                }
            }
        }
        .foregroundStyle(Palette.ink)
        .padding(12)
        .gamePanel(radius: 18, border: 3)
    }
}

// MARK: Календарь

struct CalendarView: View {
    @Environment(GameState.self) private var game

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text(tr("calendar.hint"))
                    .font(.game(13, .semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                CalendarGrid()
                ClaimLoginButton()
            }
            .padding(16)
        }
        .sheetChrome(tr("house.calendar"), coins: game.save.coins)
    }
}

/// Неделя наград: забранные, сегодняшняя и будущие.
struct CalendarGrid: View {
    @Environment(GameState.self) private var game

    var body: some View {
        let start = game.save.loginClaims - game.save.loginClaims % LoginCalendar.days
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(0..<LoginCalendar.days, id: \.self) { i in
                let claim = start + i
                let claimed = claim < game.save.loginClaims
                let today = claim == game.save.loginClaims && game.canClaimLogin
                VStack(spacing: 4) {
                    Text(tr("calendar.day", i + 1))
                        .font(.game(11))
                        .foregroundStyle(today ? Color.white : Palette.inkSoft)
                        .outlined(today ? ButtonTone.orange.lip : .clear, width: 1)
                    LoginRewardIcon(reward: game.loginReward(claim))
                        .opacity(claimed ? 0.45 : 1)
                        .overlay {
                            if claimed {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(Palette.good)
                                    .background(Circle().fill(.white))
                            }
                        }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(today ? ButtonTone.orange.base : (i == LoginCalendar.days - 1 ? Color(hex: 0xFBE3C2) : Palette.parchmentLight)))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(today ? Palette.outline : Palette.woodDark.opacity(0.4), lineWidth: today ? 2.5 : 1.5))
            }
        }
    }
}

struct LoginRewardIcon: View {
    let reward: LoginCalendar.Reward

    var body: some View {
        VStack(spacing: 2) {
            switch reward {
            case .coins(let n):
                CoinIcon(size: 26)
                Text(Fmt.n(n)).font(.game(11))
            case .seeds(let crop, let n):
                PixelIcon(name: crop.seedIcon, size: 26, fallback: "🌱")
                Text("x\(n)").font(.game(11))
            case .tickets(let n):
                TicketIcon(size: 26)
                Text("x\(n)").font(.game(11))
            case .coinsAndWood(let n, _):
                HStack(spacing: 0) {
                    CoinIcon(size: 20)
                    ResourceIcon(kind: .wood, size: 20)
                }
                Text(Fmt.n(n)).font(.game(11))
            case .dish(let dish):
                PixelIcon(name: dish.icon, size: 26, fallback: dish.emoji)
                Text("x1").font(.game(11))
            case .resource(let kind, let n):
                ResourceIcon(kind: kind, size: 26)
                Text("x\(n)").font(.game(11))
            case .chest(let tickets, let coins):
                PixelIcon(name: "chest_gold", size: 28, fallback: "🎁")
                Text("\(Fmt.n(coins)) +\(tickets)🎟️").font(.game(10))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .foregroundStyle(Palette.ink)
    }
}

struct ClaimLoginButton: View {
    @Environment(GameState.self) private var game
    var onClaim: () -> Void = {}

    var body: some View {
        if game.canClaimLogin {
            Button {
                withAnimation(.spring(duration: 0.35)) { game.claimLogin() }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onClaim()
            } label: {
                Label(tr("calendar.claim"), systemImage: "gift.fill")
            }
            .buttonStyle(.game(.orange, wide: true))
        } else {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let next = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: context.date)) ?? context.date
                Label(tr("calendar.next", Countdown.text(next.timeIntervalSince(context.date))), systemImage: "clock")
                    .font(.game(13))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Календарь при запуске игры, если сегодняшняя награда ещё не забрана.
struct CalendarPopup: View {
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Palette.dim.ignoresSafeArea().onTapGesture(perform: onClose)
            VStack(spacing: 12) {
                CalendarGrid()
                    .padding(.top, 14)
                ClaimLoginButton(onClaim: onClose)
                Button(tr("offer.later"), action: onClose)
                    .buttonStyle(.game(.wood, small: true))
            }
            .padding(16)
            .frame(maxWidth: 380)
            .gamePanel()
            .overlay(alignment: .top) {
                RibbonTitle(text: "📅 " + tr("house.calendar"), tone: .orange, size: 19)
                    .padding(.horizontal, 24)
                    .offset(y: -18)
            }
            .padding(20)
        }
    }
}
