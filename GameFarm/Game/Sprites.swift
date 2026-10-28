import SpriteKit
import UIKit

/// Пиксельные спрайты из паков (готовятся скриптом tools/sprites.py).
/// Если файлов в сборке нет, игра рисует всё эмодзи, как раньше.
enum Sprites {
    /// Во сколько раз увеличиваем пиксель персонажа, животных, руды и грядок.
    static let scale: CGFloat = 2.5

    private struct Info: Decodable {
        let w: Double
        let h: Double
        let anchor: [Double]
    }

    private static let manifest: [String: Info] = {
        guard let url = Bundle.main.url(forResource: "sp_manifest", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: Info].self, from: data) else { return [:] }
        return decoded
    }()

    static let available: Bool = !manifest.isEmpty && image("player_farmer") != nil

    private static var images: [String: UIImage] = [:]
    private static var textures: [String: SKTexture] = [:]
    private static var sheets: [String: [SKTexture]] = [:]

    static func image(_ name: String) -> UIImage? {
        if let cached = images[name] { return cached }
        guard let url = Bundle.main.url(forResource: "sp_\(name)", withExtension: "png"),
              let img = UIImage(contentsOfFile: url.path) else { return nil }
        images[name] = img
        return img
    }

    static func texture(_ name: String) -> SKTexture? {
        if let cached = textures[name] { return cached }
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
        guard let tex = texture(name) else { return nil }
        let size = tex.size()
        let node = SKSpriteNode(texture: tex, size: CGSize(width: size.width * scale, height: size.height * scale))
        node.anchorPoint = anchor(name)
        node.position = CGPoint(x: x, y: y)
        return node
    }

    /// Все кадры листа по клеткам cell x cell, построчно сверху вниз.
    static func frames(_ name: String, cell: CGFloat) -> [SKTexture] {
        if let cached = sheets[name] { return cached }
        guard let tex = texture(name) else { return [] }
        let size = tex.size()
        let cols = Int(size.width / cell)
        let rows = Int(size.height / cell)
        var out: [SKTexture] = []
        for row in 0..<rows {
            for col in 0..<cols {
                let rect = CGRect(x: CGFloat(col) * cell / size.width,
                                  y: 1 - CGFloat(row + 1) * cell / size.height,
                                  width: cell / size.width,
                                  height: cell / size.height)
                let frame = SKTexture(rect: rect, in: tex)
                frame.filteringMode = .nearest
                out.append(frame)
            }
        }
        sheets[name] = out
        return out
    }

    /// Портрет образа для интерфейса: первый кадр персонажа.
    static func portrait(_ skin: Skin) -> UIImage? {
        guard available, let img = image("player_\(skin.rawValue)"), let cg = img.cgImage,
              let crop = cg.cropping(to: CGRect(x: 4, y: 2, width: 24, height: 24)) else { return nil }
        return UIImage(cgImage: crop)
    }

    // MARK: Животные

    static func animalSheet(_ id: AnimalID) -> String? {
        guard available else { return nil }
        switch id {
        case .chicken: return "animal_chicken"
        case .cow: return "animal_cow"
        case .pig: return "animal_pig"
        case .sheep: return "animal_sheep"
        default: return nil
        }
    }

    // MARK: Мелкий декор

    static func decor(_ emoji: String) -> String? {
        guard available else { return nil }
        switch emoji {
        case "🌼": return "flowers_yellow"
        case "🌸": return "flowers_white"
        case "🌷": return "tulip_red"
        case "🌺": return "tulip_yellow"
        case "🌱": return "grass1"
        case "🌿": return "grass3"
        case "🌾": return "wheat"
        case "🍄": return "mushroom"
        case "🪵": return "log"
        default: return nil
        }
    }

    static func border(_ emoji: String) -> (name: String, scale: CGFloat)? {
        guard available else { return nil }
        switch emoji {
        case "🌳": return ("oak_small", 1.7)
        case "🌲": return ("pine", 0.66)
        case "🪨": return ("stone", 3)
        case "🪵": return ("log", 2.5)
        default: return nil
        }
    }
}

/// Анимированный персонаж из листа Cute Fantasy.
final class PixelPlayer {
    enum Facing: Int { case down = 0, side = 1, up = 2 }
    enum Action { case axe, pickaxe, hoe }

    /// Корневой узел: его можно масштабировать и подбрасывать, не мешая повороту кадра.
    let root = SKNode()
    let node: SKSpriteNode
    private var idle: [[SKTexture]] = []
    private var walk: [[SKTexture]] = []
    private var axe: [[SKTexture]] = []
    private var pickaxe: [[SKTexture]] = []
    private var hoe: [[SKTexture]] = []
    private(set) var facing: Facing = .down
    private var flip: CGFloat = 1
    private var clock: Double = 0
    private var actionFrames: [SKTexture] = []
    private var actionTime: Double = 0
    private var actionLeft: Double = 0
    private var big = false
    private let smallSize: CGSize
    private let bigSize: CGSize
    private let smallAnchor = Sprites.anchor("player")
    private let bigAnchor = Sprites.anchor("actions")

    init(skin: Skin) {
        smallSize = CGSize(width: 32 * Sprites.scale, height: 32 * Sprites.scale)
        bigSize = CGSize(width: 48 * Sprites.scale, height: 48 * Sprites.scale)
        node = SKSpriteNode(texture: nil, size: smallSize)
        node.anchorPoint = smallAnchor
        root.addChild(node)
        setSkin(skin)
    }

    func setSkin(_ skin: Skin) {
        let body = Sprites.frames("player_\(skin.rawValue)", cell: 32)
        let acts = Sprites.frames("actions_\(skin.rawValue)", cell: 48)
        guard body.count >= 60, acts.count >= 24 else { return }
        func row(_ frames: [SKTexture], _ r: Int, _ cols: Int, _ n: Int) -> [SKTexture] {
            Array(frames[(r * cols)..<(r * cols + n)])
        }
        idle = (0..<3).map { row(body, $0, 6, 6) }
        walk = (0..<3).map { row(body, $0 + 3, 6, 6) }
        // В листе действий ряды идут: бок, вниз, вверх.
        let order = [1, 0, 2]
        pickaxe = (0..<3).map { row(acts, order[$0], 2, 2) }
        axe = (0..<3).map { row(acts, 3 + order[$0], 2, 2) }
        hoe = (0..<3).map { row(acts, 6 + order[$0], 2, 2) }
        show(idle[facing.rawValue][0], big: false)
    }

    private func show(_ tex: SKTexture, big newBig: Bool) {
        node.texture = tex
        if newBig != big {
            big = newBig
            node.size = big ? bigSize : smallSize
            node.anchorPoint = big ? bigAnchor : smallAnchor
        }
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

    var busy: Bool { actionLeft > 0 }

    func update(velocity: CGVector, speedRatio: CGFloat, dt: Double) {
        if actionLeft > 0 {
            actionLeft -= dt
            actionTime += dt
            if speedRatio > 0.35 {
                actionLeft = 0
            } else {
                let frame = actionTime < 0.09 ? actionFrames[0] : actionFrames[min(1, actionFrames.count - 1)]
                show(frame, big: true)
                return
            }
        }
        guard !idle.isEmpty else { return }
        if speedRatio > 0.05 {
            if hypot(velocity.dx, velocity.dy) > 6 { face(dx: velocity.dx, dy: velocity.dy) }
            clock += dt * Double(7 + 7 * speedRatio)
            let frames = walk[facing.rawValue]
            show(frames[Int(clock) % frames.count], big: false)
        } else {
            clock += dt * 5
            let frames = idle[facing.rawValue]
            show(frames[Int(clock) % frames.count], big: false)
        }
    }

    func act(_ action: Action, dx: CGFloat, dy: CGFloat) {
        face(dx: dx, dy: dy)
        let set: [[SKTexture]]
        switch action {
        case .axe: set = axe
        case .pickaxe: set = pickaxe
        case .hoe: set = hoe
        }
        guard !set.isEmpty else { return }
        actionFrames = set[facing.rawValue]
        actionTime = 0
        actionLeft = 0.34
        show(actionFrames[0], big: true)
    }

    /// Повернуться к точке без замаха (для удочки).
    func look(dx: CGFloat, dy: CGFloat) {
        face(dx: dx, dy: dy)
        actionLeft = 0
        guard !idle.isEmpty else { return }
        show(idle[facing.rawValue][0], big: false)
    }
}

/// Животное из листа 2x2: верхний ряд - стоит, нижний - идёт. Смотрит влево.
final class PixelAnimal {
    let node: SKSpriteNode
    private let idle: [SKTexture]
    private let walk: [SKTexture]
    private var clock = Double.random(in: 0...2)

    init?(_ id: AnimalID) {
        guard let sheet = Sprites.animalSheet(id) else { return nil }
        let frames = Sprites.frames(sheet, cell: 32)
        guard frames.count >= 4 else { return nil }
        idle = [frames[0], frames[1]]
        walk = [frames[2], frames[3]]
        node = SKSpriteNode(texture: idle[0], size: CGSize(width: 32 * Sprites.scale, height: 32 * Sprites.scale))
        node.anchorPoint = Sprites.anchor(sheet)
    }

    func update(moving: Bool, dt: Double) {
        if moving {
            clock += dt * 7
            node.texture = walk[Int(clock) % 2]
        } else {
            clock += dt * 1.6
            node.texture = idle[Int(clock) % 2]
        }
    }
}
