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

/// План дома: этажи, что они дают, постройка новых и уют.
struct HouseView: View {
    @Environment(GameState.self) private var game

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                comfortCard
                ForEach(HouseFloor.allCases) { floor in
                    FloorCard(floor: floor)
                }
                Text(tr("house.tip"))
                    .font(.game(11, .semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(16)
        }
        .sheetChrome(tr("house.title"), coins: game.save.coins)
    }

    private var comfortCard: some View {
        Card(tint: Palette.goldDark) {
            HStack(spacing: 10) {
                PixelSprite(name: "hm_sofa", scale: 1.2)
                    .frame(width: 56, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("house.comfort", game.comfort)).font(.game(15))
                    Text(tr("house.comfort.bonus", Fmt.pct(Comfort.bonus(game.comfort))))
                        .font(.game(12, .semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

/// Этаж в плане: построен или что нужно для постройки.
private struct FloorCard: View {
    @Environment(GameState.self) private var game
    let floor: HouseFloor

    var body: some View {
        let built = game.isBuilt(floor)
        let levelOK = game.save.level >= floor.level
        Card(tint: built ? ButtonTone.green.base.opacity(0.6) : .clear) {
            HStack(alignment: .top, spacing: 12) {
                Image(uiImage: MiniMap.image(floor.location, framed: false))
                    .resizable()
                    .interpolation(.none)
                    .scaledToFill()
                    .frame(width: 70, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Palette.outline.opacity(0.6), lineWidth: 2))
                    .saturation(built ? 1 : 0.2)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(floor.title).font(.game(15))
                        if built {
                            Image(systemName: "checkmark.seal.fill").foregroundStyle(Palette.good)
                        } else {
                            LevelTag(level: floor.level, ok: levelOK)
                        }
                    }
                    Text(floor.room).font(.game(12, .semibold)).foregroundStyle(Palette.inkSoft)
                    Text(floor.perk)
                        .font(.game(11, .semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            if !built {
                CostView(cost: floor.cost)
                Button {
                    withAnimation(.spring(duration: 0.35)) {
                        if game.build(floor) { UINotificationFeedbackGenerator().notificationOccurred(.success) }
                    }
                } label: {
                    Text(levelOK ? tr("house.build") : tr("common.needLevel", floor.level))
                }
                .buttonStyle(.game(.green, small: true, wide: true))
                .disabled(!game.canBuild(floor))
            }
        }
    }
}

/// Выбор украшения для свободного места.
struct DecorPicker: View {
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
                                    if let event = decor.event {
                                        Text(game.hasDecor(decor) ? tr("decor.event.owned") : tr("decor.event.locked", event.name))
                                            .font(.game(11, .semibold))
                                            .foregroundStyle(game.hasDecor(decor) ? Palette.good : Palette.inkSoft)
                                    } else {
                                        CostView(cost: decor.cost)
                                    }
                                }
                                Spacer(minLength: 4)
                                Button {
                                    if game.place(decor, at: slot) { onClose() }
                                } label: {
                                    Text(decor.event == nil ? tr("common.buy") : tr("decor.place"))
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
                levelCard
                if !game.activeMeals.isEmpty {
                    SectionTitle(text: tr("kitchen.active", game.activeMeals.count, game.mealSlots))
                    ForEach(game.activeMeals) { mealCard($0.dish, until: $0.until) }
                }
                if game.totalDishes > 0 {
                    SectionTitle(text: tr("kitchen.pantry"))
                    ForEach(DishID.allCases.filter { game.dishes($0) > 0 }) { dish in
                        pantryRow(dish)
                    }
                }
                SectionTitle(text: tr("kitchen.recipes"))
                Text(tr("kitchen.sources"))
                    .font(.game(11, .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                                    GameBar(value: 1 - left / max(1, game.cookTime(job.dish)), tone: .orange, height: 14,
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

    /// Уровень кухни: плиты, скорость готовки и сколько блюд сразу.
    private var levelCard: some View {
        let level = game.save.kitchenLevel
        return Card {
            HStack(spacing: 10) {
                PixelIcon(name: "hammer", size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("kitchen.level", level, Kitchen.maxLevel)).font(.game(14))
                    Text(tr("kitchen.level.now", Kitchen.slots(level), Fmt.pct(1 - Kitchen.speed(level)), Kitchen.mealSlots(level)))
                        .font(.game(11, .semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            if let cost = game.nextKitchenCost {
                let need = Kitchen.requiredLevel(level + 1)
                Text(tr("kitchen.level.next", Kitchen.slots(level + 1), Fmt.pct(1 - Kitchen.speed(level + 1)), Kitchen.mealSlots(level + 1)))
                    .font(.game(11, .semibold))
                    .foregroundStyle(Palette.inkSoft)
                CostView(cost: cost)
                Button {
                    game.upgradeKitchen()
                } label: {
                    Text(game.save.level >= need ? tr("common.upgrade") : tr("common.needLevel", need))
                }
                .buttonStyle(.game(.orange, small: true, wide: true))
                .disabled(!game.canUpgradeKitchen())
            }
        }
    }

    private func mealCard(_ meal: DishID, until: Date) -> some View {
        Card(tint: ButtonTone.green.base) {
            HStack(spacing: 10) {
                PixelIcon(name: meal.icon, size: 34, fallback: meal.emoji)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("kitchen.eaten", meal.name)).font(.game(14))
                    Text(meal.effectText).font(.game(12, .semibold)).foregroundStyle(Palette.good)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Label(Countdown.text(until.timeIntervalSince(context.date)), systemImage: "clock")
                            .font(.game(12))
                            .foregroundStyle(.secondary)
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
                withAnimation(.snappy) { _ = game.eat(dish) }
            }
            .buttonStyle(.game(.green, small: true))
            .disabled(!game.canEat(dish))
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
                Label(tr("kitchen.cook", Fmt.seconds(game.cookTime(dish))), systemImage: "flame.fill")
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
        let meals = game.activeMeals
        if let first = meals.first {
            Button(action: onTap) {
                HStack(spacing: 2) {
                    ForEach(meals) { meal in
                        PixelIcon(name: meal.dish.icon, size: 18, fallback: meal.dish.emoji)
                    }
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(Countdown.text(first.until.timeIntervalSince(context.date)))
                            .font(.game(12))
                            .foregroundStyle(.white)
                            .outlined(Palette.outline, width: 1)
                            .monospacedDigit()
                            .padding(.leading, 2)
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

/// Карточка у двери дома, у загона или у стражника.
struct PlaceCard: View {
    @Environment(GameState.self) private var game
    let kind: PlaceKind
    let onOpen: () -> Void

    private var title: String {
        switch kind {
        case .house: tr("house.title")
        case .pen: tr("pen.title")
        case .hunter: tr("hunt.guard")
        }
    }

    private var subtitle: String {
        switch kind {
        case .house: tr("house.hint")
        case .pen: tr("pen.count", AnimalID.allCases.filter { game.stars($0) > 0 }.count)
        case .hunter: tr("hunt.hint")
        }
    }

    private var button: String {
        switch kind {
        case .house: tr("house.enter")
        case .pen: tr("hud.animals")
        case .hunter: tr("hunt.open")
        }
    }

    private var badge: Int {
        switch kind {
        case .house: (game.canClaimLogin || game.save.cooking.contains { $0.readyAt <= Date() }) ? 1 : 0
        case .pen: 0
        case .hunter: game.claimableHunts
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            if kind == .hunter {
                NPCPortrait(name: "guard", size: 52)
            } else {
                Text(kind == .house ? "🏠" : "🐾").font(.system(size: 34))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.game(15))
                Text(subtitle)
                    .font(.game(12, .semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Button(action: onOpen) {
                Text(button)
            }
            .buttonStyle(.game(kind == .house ? .orange : (kind == .hunter ? .red : .green)))
            .overlay(alignment: .topTrailing) {
                if badge > 0 {
                    CountBadge(count: badge).offset(x: 6, y: -8)
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
