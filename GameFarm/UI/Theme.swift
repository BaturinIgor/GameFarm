import SwiftUI

// MARK: Цвета и шрифты

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

/// Палитра интерфейса: пергамент, дерево и тёмный контур, как у пиксельных спрайтов.
enum Palette {
    static let parchment = Color(hex: 0xF4E4C1)
    static let parchmentLight = Color(hex: 0xFBF1DC)
    static let parchmentDeep = Color(hex: 0xE7CF9F)
    static let wood = Color(hex: 0xA0673A)
    static let woodLight = Color(hex: 0xC48A55)
    static let woodDark = Color(hex: 0x5E3A1F)
    static let outline = Color(hex: 0x2B1A0F)
    static let ink = Color(hex: 0x3B2416)
    static let inkSoft = Color(hex: 0x7B5B40)
    static let gold = Color(hex: 0xF7C948)
    static let goldDark = Color(hex: 0xC98A1B)
    static let good = Color(hex: 0x3E8E3A)
    static let bad = Color(hex: 0xC0392B)
    static let dim = Color(hex: 0x1A0F08, opacity: 0.55)
}

extension Font {
    /// Основной игровой шрифт: круглый и жирный.
    static func game(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: Обводка текста

/// Обводка четырьмя тенями. Чтобы тени не перерисовывались каждый кадр поверх движущейся игры,
/// результат один раз растеризуется в текстуру (drawingGroup) и дальше просто накладывается.
struct OutlinedText: ViewModifier {
    var color: Color
    var width: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color, radius: 0, x: width, y: 0)
            .shadow(color: color, radius: 0, x: -width, y: 0)
            .shadow(color: color, radius: 0, x: 0, y: width)
            .shadow(color: color, radius: 0, x: 0, y: -width)
            .padding(width + 1)
            .drawingGroup()
            .padding(-(width + 1))
    }
}

extension View {
    /// Белый текст с тёмной обводкой, как в играх.
    func outlined(_ color: Color = Palette.outline, width: CGFloat = 1.2) -> some View {
        modifier(OutlinedText(color: color, width: width))
    }

    /// Заголовочный стиль: белые буквы с обводкой.
    func gameTitle(_ size: CGFloat, color: Color = .white, outline: Color = Palette.outline) -> some View {
        self.font(.game(size))
            .foregroundStyle(color)
            .outlined(outline, width: size >= 20 ? 1.6 : 1.2)
    }
}

// MARK: Кнопки

enum ButtonTone {
    case green, orange, red, blue, purple, gold, wood, gray

    var top: Color {
        switch self {
        case .green: Color(hex: 0x8BD45A)
        case .orange: Color(hex: 0xFFB04A)
        case .red: Color(hex: 0xF0725E)
        case .blue: Color(hex: 0x6CC3F2)
        case .purple: Color(hex: 0xB58BF0)
        case .gold: Color(hex: 0xFFE07A)
        case .wood: Color(hex: 0xD29A62)
        case .gray: Color(hex: 0xBDB3A6)
        }
    }

    var base: Color {
        switch self {
        case .green: Color(hex: 0x4FA83A)
        case .orange: Color(hex: 0xF0821E)
        case .red: Color(hex: 0xD2412F)
        case .blue: Color(hex: 0x2F8FD0)
        case .purple: Color(hex: 0x7C55C9)
        case .gold: Color(hex: 0xF0B22E)
        case .wood: Color(hex: 0xA0673A)
        case .gray: Color(hex: 0x958A7E)
        }
    }

    var lip: Color {
        switch self {
        case .green: Color(hex: 0x2E6E25)
        case .orange: Color(hex: 0xA5520E)
        case .red: Color(hex: 0x8A2419)
        case .blue: Color(hex: 0x1C5A8A)
        case .purple: Color(hex: 0x4D3285)
        case .gold: Color(hex: 0xA8721A)
        case .wood: Color(hex: 0x5E3A1F)
        case .gray: Color(hex: 0x5F574F)
        }
    }

    /// Цвет надписи: на светлом золоте читается тёмный текст.
    var text: Color { self == .gold ? Palette.ink : .white }
}

/// Объёмная кнопка с "губой" снизу: при нажатии опускается.
struct GameButtonStyle: ButtonStyle {
    var tone: ButtonTone = .green
    var small = false
    var wide = false

    func makeBody(configuration: Configuration) -> some View {
        GameButtonBody(configuration: configuration, tone: tone, small: small, wide: wide)
    }
}

private struct GameButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let tone: ButtonTone
    let small: Bool
    let wide: Bool
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        let t = enabled ? tone : .gray
        let lip: CGFloat = small ? 3 : 4
        let radius: CGFloat = small ? 10 : 13
        let pressed = configuration.isPressed && enabled
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        configuration.label
            .font(.game(small ? 13 : 16))
            .foregroundStyle(t.text)
            .outlined(t == .gold ? .clear : t.lip, width: 1)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, small ? 10 : 16)
            .padding(.vertical, small ? 6 : 10)
            .frame(maxWidth: wide ? .infinity : nil)
            .frame(minHeight: small ? 30 : 42)
            .background(shape.fill(LinearGradient(colors: [t.top, t.base], startPoint: .top, endPoint: .bottom)))
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Color.white.opacity(0.4))
                    .frame(height: small ? 2 : 3)
                    .padding(.horizontal, radius)
                    .padding(.top, 3)
            }
            .overlay(shape.strokeBorder(Palette.outline, lineWidth: 2))
            .offset(y: pressed ? lip : 0)
            .padding(.bottom, lip)
            .background {
                shape.fill(t.lip)
                    .overlay(shape.strokeBorder(Palette.outline, lineWidth: 2))
                    .padding(.top, lip)
            }
            .opacity(enabled ? 1 : 0.85)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.08), value: pressed)
    }
}

extension ButtonStyle where Self == GameButtonStyle {
    static func game(_ tone: ButtonTone = .green, small: Bool = false, wide: Bool = false) -> GameButtonStyle {
        GameButtonStyle(tone: tone, small: small, wide: wide)
    }
}

/// Простая кнопка без фона, которая слегка сжимается при нажатии.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressStyle {
    static var press: PressStyle { PressStyle() }
}

/// Круглая красная кнопка закрытия.
struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(ButtonTone.red.lip).offset(y: 3)
                Circle().fill(LinearGradient(colors: [ButtonTone.red.top, ButtonTone.red.base], startPoint: .top, endPoint: .bottom))
                Circle().strokeBorder(Palette.outline, lineWidth: 2)
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.white)
                    .outlined(ButtonTone.red.lip, width: 1)
            }
            .frame(width: 34, height: 34)
            .padding(.bottom, 3)
        }
        .buttonStyle(.press)
        .accessibilityLabel(tr("common.close"))
    }
}

// MARK: Панели

/// Пергамент в деревянной рамке с жёсткой тенью.
struct GamePanel: ViewModifier {
    var fill: Color = Palette.parchment
    var frame: Color = Palette.wood
    var radius: CGFloat = 20
    var border: CGFloat = 4

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background(shape.fill(fill))
            .overlay(shape.strokeBorder(frame, lineWidth: border))
            .overlay(shape.inset(by: border).strokeBorder(Palette.outline.opacity(0.35), lineWidth: 1))
            .overlay(shape.strokeBorder(Palette.outline, lineWidth: 2))
            .background(shape.fill(Palette.outline.opacity(0.45)).offset(y: 4))
    }
}

extension View {
    func gamePanel(fill: Color = Palette.parchment, frame: Color = Palette.wood, radius: CGFloat = 20, border: CGFloat = 4) -> some View {
        modifier(GamePanel(fill: fill, frame: frame, radius: radius, border: border))
    }

    /// Деревянная плашка для элементов поверх карты.
    func woodPill(radius: CGFloat = 14, tint: Color = Palette.wood) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return self
            .background(shape.fill(LinearGradient(colors: [tint.mix(with: .white, by: 0.18), tint], startPoint: .top, endPoint: .bottom)))
            .overlay(shape.inset(by: 2).strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
            .overlay(shape.strokeBorder(Palette.outline, lineWidth: 2))
            .background(shape.fill(Palette.outline.opacity(0.5)).offset(y: 3))
    }
}

/// Лента-заголовок для окон и всплывающих сообщений.
struct RibbonTitle: View {
    let text: String
    var tone: ButtonTone = .orange
    var size: CGFloat = 20

    var body: some View {
        Text(text)
            .gameTitle(size, outline: tone.lip)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 26)
            .padding(.vertical, 8)
            .background {
                RibbonShape()
                    .fill(LinearGradient(colors: [tone.top, tone.base], startPoint: .top, endPoint: .bottom))
                    .overlay(RibbonShape().stroke(Palette.outline, lineWidth: 2))
                    .background(RibbonShape().fill(tone.lip).offset(y: 3))
            }
    }
}

/// Лента с вырезами по краям.
struct RibbonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let notch: CGFloat = min(12, rect.height * 0.35)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - notch, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + notch, y: rect.midY))
        p.closeSubpath()
        return p
    }
}

// MARK: Иконки

/// Пиксельная иконка из набора спрайтов, с запасным эмодзи.
struct PixelIcon: View {
    let name: String
    var size: CGFloat = 22
    var fallback: String = ""

    var body: some View {
        if let image = Sprites.icon(named: name) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.medium)
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Text(fallback)
                .font(.system(size: size * 0.82))
                .frame(width: size, height: size)
        }
    }
}

struct CoinIcon: View {
    var size: CGFloat = 18
    var body: some View { PixelIcon(name: "coin", size: size, fallback: "🪙") }
}

/// Иконка по строке: "px:имя" - пиксельная иконка, монета - золотая из пака, иначе эмодзи.
struct IconView: View {
    let icon: String
    var size: CGFloat = 20

    var body: some View {
        if icon == "🪙" {
            CoinIcon(size: size)
        } else if icon.hasPrefix("px:") {
            PixelIcon(name: String(icon.dropFirst(3)), size: size)
        } else {
            Text(icon).font(.system(size: size * 0.85))
        }
    }
}

/// Маленькие картинки для вставки прямо в текст.
@MainActor
enum InlineIcons {
    private static var cache: [String: UIImage] = [:]

    static func image(_ name: String, size: CGFloat) -> UIImage? {
        let key = "\(name)|\(size)"
        if let cached = cache[key] { return cached }
        guard let source = Sprites.icon(named: name) else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let out = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format).image { ctx in
            ctx.cgContext.interpolationQuality = .none
            source.draw(in: CGRect(x: 0, y: 0, width: size, height: size))
        }
        cache[key] = out
        return out
    }
}

extension Text {
    /// Текст, в котором эмодзи монеты заменена золотой монетой из пака.
    @MainActor
    static func withCoins(_ string: String, size: CGFloat = 14) -> Text {
        guard string.contains("🪙"), let coin = InlineIcons.image("coin", size: size) else { return Text(string) }
        let parts = string.components(separatedBy: "🪙")
        var text = Text(parts[0])
        for part in parts.dropFirst() {
            let image = Text(Image(uiImage: coin)).baselineOffset(-size * 0.18)
            text = Text("\(text)\(image)\(part)")
        }
        return text
    }
}

/// Красный кружок со счётчиком.
struct CountBadge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.game(11))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .frame(minWidth: 20, minHeight: 20)
            .background(Capsule().fill(ButtonTone.red.base))
            .overlay(Capsule().strokeBorder(Palette.outline, lineWidth: 1.5))
    }
}

// MARK: Полоска прогресса

struct GameBar: View {
    let value: Double
    var tone: ButtonTone = .green
    var height: CGFloat = 12
    var label: String? = nil

    var body: some View {
        let v = min(1, max(0, value))
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.woodDark.opacity(0.85))
                Capsule()
                    .fill(LinearGradient(colors: [tone.top, tone.base], startPoint: .top, endPoint: .bottom))
                    .frame(width: v > 0 ? max(height, geo.size.width * v) : 0)
                    .overlay(alignment: .top) {
                        Capsule().fill(Color.white.opacity(0.35)).frame(height: max(1, height * 0.2))
                            .padding(.horizontal, height * 0.4).padding(.top, height * 0.15)
                    }
                Capsule().strokeBorder(Palette.outline, lineWidth: 1.5)
                if let label {
                    Text(label)
                        .font(.game(max(9, height * 0.72)))
                        .foregroundStyle(.white)
                        .outlined(Palette.outline, width: 1)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: height)
    }
}

// MARK: Вкладки и переключатели

/// Деревянные вкладки вместо системного сегментного переключателя.
struct GameTabs<T: Hashable>: View {
    @Binding var selection: T
    let items: [(T, String)]
    /// Красные счётчики на вкладках (например, незабранные награды).
    var badges: [T: Int] = [:]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                let on = item.0 == selection
                Button {
                    selection = item.0
                } label: {
                    Text(item.1)
                        .font(.game(13))
                        .foregroundStyle(on ? Color.white : Palette.inkSoft)
                        .outlined(on ? Palette.woodDark : .clear, width: 1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(on ? AnyShapeStyle(LinearGradient(colors: [Palette.woodLight, Palette.wood], startPoint: .top, endPoint: .bottom))
                                         : AnyShapeStyle(Color.clear))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(on ? Palette.outline : .clear, lineWidth: 1.5)
                        )
                        .contentShape(Rectangle())
                        .overlay(alignment: .topTrailing) {
                            if let n = badges[item.0], n > 0 {
                                CountBadge(count: n).scaleEffect(0.85).offset(x: 4, y: -8)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Palette.parchmentDeep))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Palette.woodDark.opacity(0.5), lineWidth: 1.5))
        .animation(.snappy(duration: 0.2), value: selection)
    }
}

struct GameToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer(minLength: 8)
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? ButtonTone.green.base : Palette.woodDark.opacity(0.55))
                    .overlay(Capsule().strokeBorder(Palette.outline, lineWidth: 2))
                    .frame(width: 54, height: 30)
                Circle()
                    .fill(LinearGradient(colors: [Palette.parchmentLight, Palette.parchmentDeep], startPoint: .top, endPoint: .bottom))
                    .overlay(Circle().strokeBorder(Palette.outline, lineWidth: 2))
                    .frame(width: 26, height: 26)
                    .padding(2)
            }
            .animation(.snappy(duration: 0.18), value: configuration.isOn)
            .onTapGesture { configuration.isOn.toggle() }
        }
        .contentShape(Rectangle())
    }
}

// MARK: Действия окон

struct GameActions {
    var close: () -> Void = {}
    var open: (GameSheet) -> Void = { _ in }
}

private struct GameActionsKey: EnvironmentKey {
    static let defaultValue = GameActions()
}

extension EnvironmentValues {
    var gameActions: GameActions {
        get { self[GameActionsKey.self] }
        set { self[GameActionsKey.self] = newValue }
    }
}

/// Шапка окна: монеты слева, заголовок на доске, крестик справа.
struct WindowHeader: View {
    @Environment(\.gameActions) private var actions
    let title: String
    let coins: Int

    var body: some View {
        ZStack {
            Text(title)
                .gameTitle(20)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 110)
            HStack {
                CoinsBadge(coins: coins)
                Spacer()
                CloseButton { actions.close() }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [Palette.woodLight, Palette.wood], startPoint: .top, endPoint: .bottom))
        )
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.outline).frame(height: 2)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.woodDark.opacity(0.6)).frame(height: 3).offset(y: 5)
        }
    }
}

/// Рамка окна меню поверх игры.
struct GameWindowFrame: ViewModifier {
    func body(content: Content) -> some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous)
        content
            .frame(maxWidth: 600, maxHeight: .infinity)
            .background {
                shape.fill(Palette.parchment).ignoresSafeArea(edges: .bottom)
            }
            .overlay {
                shape.strokeBorder(Palette.outline, lineWidth: 2).ignoresSafeArea(edges: .bottom)
            }
            .environment(\.colorScheme, .light)
            .foregroundStyle(Palette.ink)
            .tint(Palette.wood)
    }
}

// MARK: Диалоги

/// Подтверждения и сообщения в стиле игры вместо системных окон.
@MainActor
@Observable
final class Dialogs {
    static let shared = Dialogs()

    struct Item: Identifiable {
        let id = UUID()
        var title: String
        var message: String
        var icon: String
        var confirm: String
        var tone: ButtonTone
        var cancel: String?
        var action: (() -> Void)?
    }

    var current: Item?

    func confirm(_ title: String, message: String = "", icon: String = "❓", confirm: String,
                 tone: ButtonTone = .red, action: @escaping () -> Void) {
        current = Item(title: title, message: message, icon: icon, confirm: confirm, tone: tone,
                       cancel: tr("common.cancel"), action: action)
    }

    func info(_ title: String, message: String, icon: String = "⚠️") {
        current = Item(title: title, message: message, icon: icon, confirm: tr("common.ok"), tone: .green,
                       cancel: nil, action: nil)
    }
}

struct DialogView: View {
    let item: Dialogs.Item
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Palette.dim.ignoresSafeArea()
                .onTapGesture { if item.cancel != nil { onClose() } }
            VStack(spacing: 12) {
                Text(item.title)
                    .font(.game(20))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 38)
                if !item.message.isEmpty {
                    Text(item.message)
                        .font(.game(14, .semibold))
                        .foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 10) {
                    if let cancel = item.cancel {
                        Button(cancel) { onClose() }
                            .buttonStyle(.game(.wood, wide: true))
                    }
                    Button {
                        let action = item.action
                        onClose()
                        action?()
                    } label: {
                        Text.withCoins(item.confirm, size: 15)
                    }
                    .buttonStyle(.game(item.tone, wide: true))
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .frame(maxWidth: 340)
            .gamePanel()
            .overlay(alignment: .top) {
                IconView(icon: item.icon, size: 36)
                    .frame(width: 62, height: 62)
                    .background(Circle().fill(LinearGradient(colors: [item.tone.top, item.tone.base], startPoint: .top, endPoint: .bottom)))
                    .overlay(Circle().strokeBorder(Palette.outline, lineWidth: 2.5))
                    .background(Circle().fill(item.tone.lip).offset(y: 3))
                    .offset(y: -31)
            }
            .padding(24)
        }
    }
}

// MARK: Списки

extension View {
    /// Светлая подложка для групп строк, как у карточек.
    func listBox(radius: CGFloat = 16) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return self
            .background(shape.fill(Palette.parchmentLight))
            .overlay(shape.strokeBorder(Palette.woodDark.opacity(0.45), lineWidth: 1.5))
            .background(shape.fill(Palette.woodDark.opacity(0.25)).offset(y: 3))
    }
}

/// Пунктирный разделитель строк на пергаменте.
struct PaperDivider: View {
    var body: some View {
        Rectangle()
            .fill(Palette.woodDark.opacity(0.18))
            .frame(height: 1.5)
    }
}

/// Плашка "Ур. N": зелёная, если уровень достигнут.
struct LevelTag: View {
    let level: Int
    let ok: Bool

    var body: some View {
        Text(tr("common.lvl", level))
            .font(.game(12))
            .foregroundStyle(.white)
            .outlined(ok ? ButtonTone.green.lip : ButtonTone.red.lip, width: 1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(ok ? ButtonTone.green.base : ButtonTone.red.base))
            .overlay(Capsule().strokeBorder(Palette.outline, lineWidth: 1.5))
    }
}

/// Награда "+N" с иконкой в светлой капсуле.
struct RewardChip<Icon: View>: View {
    let text: String
    @ViewBuilder var icon: Icon

    var body: some View {
        HStack(spacing: 5) {
            icon
            Text(text)
                .font(.game(16))
                .foregroundStyle(Palette.ink)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Palette.parchmentLight))
        .overlay(Capsule().strokeBorder(Palette.woodDark.opacity(0.5), lineWidth: 1.5))
    }
}
