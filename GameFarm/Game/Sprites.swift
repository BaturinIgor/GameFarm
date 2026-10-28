import SpriteKit
import UIKit

/// Пиксельные спрайты из пака (готовятся скриптами tools/sprites.py и tools/world.py).
/// Если файлов в сборке нет, игра рисует всё эмодзи, как раньше.
enum Sprites {
    /// Один пиксель рисунка = 2 точки экрана: на экранах 2x и 3x пиксели получаются ровными.
    static let scale: CGFloat = 2

    private struct Info: Decodable {
        let w: Double
        let h: Double
        let anchor: [Double]
        let frame: Double?
        let rows: [Int]?
        /// Место в общем атласе: x, y, ширина, высота в пикселях (от левого верхнего угла).
        let atlas: [Double]?
        /// Сколько непустых кадров в каждом ряду листа зверя.
        let counts: [Int]?
    }

    private static let manifest: [String: Info] = {
        guard let url = Bundle.main.url(forResource: "sp_manifest", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: Info].self, from: data) else { return [:] }
        return decoded
    }()

    static let available: Bool = !manifest.isEmpty && image("pl_farmer") != nil

    nonisolated(unsafe) private static var images: [String: UIImage] = [:]
    nonisolated(unsafe) private static var textures: [String: SKTexture] = [:]
    nonisolated(unsafe) private static var sheets: [String: [SKTexture]] = [:]
    nonisolated(unsafe) private static var icons: [String: UIImage] = [:]

    static func has(_ name: String) -> Bool { manifest[name] != nil }

    /// Непустых кадров в ряду листа (если известно).
    static func frameCount(_ name: String, row: Int) -> Int? {
        guard let counts = manifest[name]?.counts, row >= 0, row < counts.count else { return nil }
        return counts[row]
    }

    static func image(_ name: String) -> UIImage? {
        if let cached = images[name] { return cached }
        guard let url = Bundle.main.url(forResource: "sp_\(name)", withExtension: "png"),
              let img = UIImage(contentsOfFile: url.path) else { return nil }
        images[name] = img
        return img
    }

    /// Общий атлас одиночных спрайтов: всё из него рисуется одной пачкой.
    private static let atlasTexture: SKTexture? = {
        guard let img = image("atlas") else { return nil }
        let tex = SKTexture(image: img)
        tex.filteringMode = .nearest
        return tex
    }()

    static func texture(_ name: String) -> SKTexture? {
        if let cached = textures[name] { return cached }
        if let r = manifest[name]?.atlas, r.count == 4, let atlas = atlasTexture {
            let size = atlas.size()
            let rect = CGRect(x: r[0] / size.width, y: 1 - (r[1] + r[3]) / size.height,
                              width: r[2] / size.width, height: r[3] / size.height)
            let tex = SKTexture(rect: rect, in: atlas)
            tex.filteringMode = .nearest
            textures[name] = tex
            return tex
        }
        guard let img = image(name) else { return nil }
        let tex = SKTexture(image: img)
        tex.filteringMode = .nearest
        textures[name] = tex
        return tex
    }

    static func anchor(_ key: String) -> CGPoint {
        guard let a = manifest[key]?.anchor, a.count == 2 else { return CGPoint(x: 0.5, y: 0) }
        return CGPoint(x: a[0], y: a[1])
    }

    /// Спрайт, у которого точка (0, 0) - место, где предмет стоит на земле.
    static func node(_ name: String, scale: CGFloat = Sprites.scale, x: CGFloat = 0, y: CGFloat = 0) -> SKSpriteNode? {
        if let width = manifest[name]?.frame, let first = strip(name).first {
            let node = SKSpriteNode(texture: first, size: CGSize(width: CGFloat(width) * scale, height: first.size().height * scale))
            node.anchorPoint = anchor(name)
            node.position = CGPoint(x: x, y: y)
            return node
        }
        guard let tex = texture(name) else { return nil }
        let size = tex.size()
        let node = SKSpriteNode(texture: tex, size: CGSize(width: size.width * scale, height: size.height * scale))
        node.anchorPoint = anchor(name)
        node.position = CGPoint(x: x, y: y)
        return node
    }

    /// Анимированный спрайт из ленты кадров (ширина кадра - в манифесте).
    static func animated(_ name: String, fps: Double = 8, scale: CGFloat = Sprites.scale, x: CGFloat = 0, y: CGFloat = 0,
                         random: Bool = true) -> SKSpriteNode? {
        let frames = strip(name)
        guard let made = Sprites.node(name, scale: scale, x: x, y: y) else { return nil }
        guard frames.count > 1 else { return made }
        let play = SKAction.repeatForever(.animate(with: frames, timePerFrame: 1 / fps))
        if random {
            made.run(.sequence([.wait(forDuration: Double.random(in: 0...(Double(frames.count) / fps))), play]))
        } else {
            made.run(play)
        }
        return made
    }

    /// Кадры ленты по ширине из манифеста.
    static func strip(_ name: String) -> [SKTexture] {
        guard let width = manifest[name]?.frame else { return texture(name).map { [$0] } ?? [] }
        let height = manifest[name]?.h ?? width
        return frames(name, w: CGFloat(width), h: CGFloat(height))
    }

    /// Все кадры листа по клеткам w x h, построчно сверху вниз.
    static func frames(_ name: String, w: CGFloat, h: CGFloat) -> [SKTexture] {
        let key = "\(name)|\(w)|\(h)"
        if let cached = sheets[key] { return cached }
        guard let tex = texture(name) else { return [] }
        let size = tex.size()
        let cols = Int(size.width / w)
        let rows = Int(size.height / h)
        var out: [SKTexture] = []
        for row in 0..<rows {
            for col in 0..<cols {
                let rect = CGRect(x: CGFloat(col) * w / size.width,
                                  y: 1 - CGFloat(row + 1) * h / size.height,
                                  width: w / size.width,
                                  height: h / size.height)
                let frame = SKTexture(rect: rect, in: tex)
                frame.filteringMode = .nearest
                out.append(frame)
            }
        }
        sheets[key] = out
        return out
    }

    static func frames(_ name: String, cell: CGFloat) -> [SKTexture] {
        frames(name, w: cell, h: cell)
    }

    /// Кусок картинки, увеличенный без сглаживания (для интерфейса).
    static func crisp(_ name: String, crop: CGRect? = nil, scale: CGFloat = 4) -> UIImage? {
        let key = "\(name)|\(crop.map { "\($0)" } ?? "")|\(scale)"
        if let cached = icons[key] { return cached }
        guard let img = image(name), let cg = img.cgImage else { return nil }
        var part = cg
        if let crop, let c = cg.cropping(to: crop) { part = c }
        part = trimmed(part) ?? part
        let size = CGSize(width: CGFloat(part.width) * scale, height: CGFloat(part.height) * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let out = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            ctx.cgContext.interpolationQuality = .none
            ctx.cgContext.translateBy(x: 0, y: size.height)
            ctx.cgContext.scaleBy(x: 1, y: -1)
            ctx.cgContext.draw(part, in: CGRect(origin: .zero, size: size))
        }
        icons[key] = out
        return out
    }

    /// Обрезает прозрачные края.
    private static func trimmed(_ image: CGImage) -> CGImage? {
        let w = image.width, h = image.height
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = ctx.data else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        let px = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h {
            for x in 0..<w where px[(y * w + x) * 4 + 3] > 0 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX else { return nil }
        // В памяти контекста первая строка - верх картинки, как и у cropping(to:).
        return image.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1))
    }

    /// Иконка ресурса в пиксельном стиле.
    static func icon(_ kind: ResourceKind) -> UIImage? {
        guard available, has("ic_\(kind.rawValue)") else { return nil }
        return crisp("ic_\(kind.rawValue)")
    }

    static func icon(named name: String) -> UIImage? {
        guard available, has("ic_\(name)") else { return nil }
        return crisp("ic_\(name)")
    }

    /// Портрет образа для интерфейса: голова и плечи из первого кадра.
    static func portrait(_ skin: Skin) -> UIImage? {
        guard available else { return nil }
        return crisp("pl_\(skin.rawValue)", crop: CGRect(x: 20, y: 14, width: 24, height: 26), scale: 4)
    }

    /// Первый кадр зверя для интерфейса.
    static func animalImage(_ id: AnimalID) -> UIImage? {
        guard available, let sheet = AnimalSheet.of(id) else { return nil }
        let row = sheet.idle.first ?? (0, 1)
        let rect = CGRect(x: 0, y: CGFloat(row.0) * sheet.cell + sheet.rowOffset, width: sheet.cell, height: sheet.cell)
        return crisp(sheet.name, crop: sheet.iconRect ?? rect, scale: sheet.cell <= 16 ? 6 : 4)
    }

    // MARK: Земля

    static func ground(_ id: LocationID) -> SKTexture? {
        guard available else { return nil }
        return texture("ground_\(LocationLayout.resourceName(id))") ?? texture("ground_\(id.rawValue)")
    }
}

/// Как устроен лист зверя: клетка, ряды "стоит" и "идёт" (вбок, вниз, вверх).
struct AnimalSheet {
    let name: String
    let cell: CGFloat
    /// (ряд, кадров) для взгляда вбок, вниз, вверх. Если есть только вид сбоку - один элемент.
    let idle: [(Int, Int)]
    let walk: [(Int, Int)]
    /// Вид сбоку смотрит влево.
    var facesLeft = true
    var fps: Double = 8
    var rowOffset: CGFloat = 0
    var iconRect: CGRect? = nil
    /// Летает: качается вверх-вниз.
    var flies = false
    /// Плавает: ряды "стоит в воде" и "плывёт".
    var swimIdle: (Int, Int)? = nil
    var swim: (Int, Int)? = nil

    static func of(_ id: AnimalID) -> AnimalSheet? {
        let four = { (name: String) in
            AnimalSheet(name: name, cell: 32, idle: [(0, 2), (1, 2), (2, 2)], walk: [(3, 8), (4, 8), (5, 8)], fps: 10)
        }
        let bird = { (name: String) in
            AnimalSheet(name: name, cell: 32, idle: [(0, 2)], walk: [(1, 6)], fps: 10)
        }
        let swimmer = { (name: String) in
            AnimalSheet(name: name, cell: 32, idle: [(0, 2)], walk: [(1, 6)], fps: 10, swimIdle: (7, 2), swim: (8, 4))
        }
        let sheet: AnimalSheet
        switch id {
        case .cow: sheet = four("an_cow")
        case .horse: sheet = four("an_horse")
        case .pig: sheet = four("an_pig")
        case .sheep: sheet = four("an_sheep")
        case .unicorn: sheet = four("an_unicorn")
        case .chicken: sheet = bird("an_chicken")
        case .rooster: sheet = bird("an_rooster")
        case .duck: sheet = swimmer("an_duck")
        case .duckHat: sheet = swimmer("an_duckHat")
        case .goose: sheet = bird("an_goose")
        case .goldenGoose: sheet = bird("an_goldenGoose")
        case .swan: sheet = swimmer("an_swan")
        case .frog: sheet = AnimalSheet(name: "an_frog", cell: 32, idle: [(0, 2)], walk: [(1, 8)], facesLeft: false, fps: 12)
        case .mouse: sheet = AnimalSheet(name: "an_mouse", cell: 32, idle: [(0, 6)], walk: [(1, 6)], fps: 12)
        case .bee: sheet = AnimalSheet(name: "an_bee", cell: 16, idle: [(0, 4)], walk: [(0, 4)], fps: 14, flies: true)
        case .butterfly: sheet = AnimalSheet(name: "an_butterfly", cell: 8, idle: [(2, 2)], walk: [(2, 2)], facesLeft: false, fps: 8,
                                             flies: true)
        }
        return Sprites.has(sheet.name) ? sheet : nil
    }
}

/// Анимированный персонаж, собранный по слоям из пака.
final class PixelPlayer {
    enum Facing: Int { case down = 0, side = 1, up = 2 }
    enum Action { case axe, pickaxe, hoe, fish }

    /// Корневой узел: его можно масштабировать и подбрасывать, не мешая повороту кадра.
    let root = SKNode()
    let node: SKSpriteNode
    private var rows: [[SKTexture]] = []
    private(set) var facing: Facing = .down
    private var flip: CGFloat = 1
    private var clock: Double = 0
    private var actionFrames: [SKTexture] = []
    private var actionTime: Double = 0
    private var actionLength: Double = 0
    private var frameTime: Double = 0.06

    private static let rowFrames = [6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 9, 9, 9, 8, 8, 8]

    init(skin: Skin) {
        let cell = 64 * Sprites.scale
        node = SKSpriteNode(texture: nil, size: CGSize(width: cell, height: cell))
        node.anchorPoint = Sprites.anchor("pl")
        root.addChild(node)
        setSkin(skin)
    }

    func setSkin(_ skin: Skin) {
        let all = Sprites.frames("pl_\(skin.rawValue)", cell: 64)
        guard all.count >= 9 * Self.rowFrames.count else { return }
        rows = Self.rowFrames.enumerated().map { i, n in Array(all[(i * 9)..<(i * 9 + n)]) }
        show(rows[facing.rawValue][0])
    }

    private func set(_ base: Int) -> [SKTexture] { rows.isEmpty ? [] : rows[base + facing.rawValue] }

    private func show(_ tex: SKTexture) {
        node.texture = tex
        node.xScale = facing == .side ? flip : 1
    }

    private func face(dx: CGFloat, dy: CGFloat) {
        if abs(dx) > abs(dy) * 0.85 {
            facing = .side
            flip = dx >= 0 ? 1 : -1
        } else {
            facing = dy > 0 ? .up : .down
        }
    }

    var busy: Bool { actionTime < actionLength }

    func update(velocity: CGVector, speedRatio: CGFloat, dt: Double) {
        guard !rows.isEmpty else { return }
        if actionTime < actionLength {
            actionTime += dt
            if speedRatio > 0.35 {
                actionLength = 0
            } else {
                let i = min(actionFrames.count - 1, Int(actionTime / frameTime))
                show(actionFrames[i])
                return
            }
        }
        if speedRatio > 0.05 {
            if hypot(velocity.dx, velocity.dy) > 6 { face(dx: velocity.dx, dy: velocity.dy) }
            clock += dt * Double(8 + 6 * speedRatio)
            let frames = set(3)
            show(frames[Int(clock) % frames.count])
        } else {
            clock += dt * 6
            let frames = set(0)
            show(frames[Int(clock) % frames.count])
        }
    }

    func act(_ action: Action, dx: CGFloat, dy: CGFloat, duration: Double = 0.36) {
        guard !rows.isEmpty else { return }
        face(dx: dx, dy: dy)
        switch action {
        case .axe: actionFrames = set(6)
        case .pickaxe: actionFrames = set(9)
        case .hoe: actionFrames = set(12)
        case .fish: actionFrames = set(15)
        }
        frameTime = duration / Double(max(1, actionFrames.count))
        actionTime = 0
        actionLength = duration
        show(actionFrames[0])
    }

    /// Повернуться к точке без замаха.
    func look(dx: CGFloat, dy: CGFloat) {
        face(dx: dx, dy: dy)
        actionLength = 0
        guard !rows.isEmpty else { return }
        show(set(0)[0])
    }
}

/// Анимированный зверь из листа пака.
final class PixelAnimal {
    let node: SKSpriteNode
    let sheet: AnimalSheet
    private var idle: [[SKTexture]] = []
    private var walk: [[SKTexture]] = []
    private var swimIdle: [SKTexture] = []
    private var swimMove: [SKTexture] = []
    private var clock = Double.random(in: 0...2)
    private var facing = 0
    private var right = false
    /// Зверь сейчас в воде (только для тех, кто умеет плавать).
    var swimming = false

    var canSwim: Bool { !swimMove.isEmpty }

    init?(_ id: AnimalID) {
        guard let sheet = AnimalSheet.of(id) else { return nil }
        self.sheet = sheet
        let all = Sprites.frames(sheet.name, cell: sheet.cell)
        guard let tex = Sprites.texture(sheet.name) else { return nil }
        let cols = Int(tex.size().width / sheet.cell)
        func row(_ r: (Int, Int)) -> [SKTexture] {
            // Пустые кадры в конце ряда не берём: иначе зверь мигает.
            let n = min(r.1, Sprites.frameCount(sheet.name, row: r.0) ?? r.1)
            let start = r.0 * cols
            guard n > 0, start + n <= all.count else { return [] }
            return Array(all[start..<(start + n)])
        }
        idle = sheet.idle.map(row).filter { !$0.isEmpty }
        walk = sheet.walk.map(row).filter { !$0.isEmpty }
        if let r = sheet.swimIdle { swimIdle = row(r) }
        if let r = sheet.swim { swimMove = row(r) }
        if swimIdle.isEmpty { swimMove = [] }
        if walk.isEmpty { walk = idle }
        guard let first = idle.first?.first else { return nil }
        let scale: CGFloat = sheet.cell <= 8 ? Sprites.scale * 2 : Sprites.scale
        node = SKSpriteNode(texture: first, size: CGSize(width: sheet.cell * scale, height: sheet.cell * scale))
        node.anchorPoint = sheet.flies ? CGPoint(x: 0.5, y: 0.2) : Sprites.anchor(sheet.name)
    }

    /// Обновить кадр. velocity - куда идёт зверь (для выбора вида).
    func update(velocity: CGVector, dt: Double) {
        let moving = hypot(velocity.dx, velocity.dy) > 12
        if moving {
            if idle.count >= 3 && !swimming {
                if abs(velocity.dx) > abs(velocity.dy) * 0.8 {
                    facing = 0
                } else {
                    facing = velocity.dy > 0 ? 2 : 1
                }
            }
            if abs(velocity.dx) > 6 { right = velocity.dx > 0 }
        }
        let frames: [SKTexture]
        if swimming && canSwim {
            facing = 0
            frames = moving ? swimMove : swimIdle
        } else {
            let set = moving ? walk : idle
            frames = set[min(facing, set.count - 1)]
        }
        clock += dt * (moving ? sheet.fps : 2.5)
        node.texture = frames[Int(clock) % frames.count]
        applyFlip()
    }

    private func applyFlip() {
        guard facing == 0 else {
            node.xScale = 1
            return
        }
        let mirrored = sheet.facesLeft ? right : !right
        node.xScale = mirrored ? -1 : 1
    }

    /// Повернуться к цели (для удара помощника).
    func look(dx: CGFloat) {
        guard abs(dx) > 2 else { return }
        facing = 0
        right = dx > 0
        applyFlip()
    }
}
