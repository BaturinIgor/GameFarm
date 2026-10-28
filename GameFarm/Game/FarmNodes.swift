import SpriteKit
import UIKit

/// Грядка: земля (плоская, под всеми), мокрая земля после полива и растение по стадиям.
final class BedNode {
    let index: Int
    let position: CGPoint
    private let soil: SKSpriteNode
    private let wet: SKSpriteNode
    private let plant = SKSpriteNode()
    private var shownKey = ""

    init(index: Int, at point: CGPoint, in parent: SKNode, z: CGFloat) {
        self.index = index
        position = point
        soil = Sprites.node("soil", x: point.x, y: point.y)
            ?? SKSpriteNode(color: UIColor(red: 0.7, green: 0.45, blue: 0.3, alpha: 1), size: CGSize(width: 28, height: 28))
        soil.position = point
        soil.zPosition = 3
        parent.addChild(soil)
        wet = Sprites.node("soil_wet", x: point.x, y: point.y)
            ?? SKSpriteNode(color: UIColor(red: 0.45, green: 0.27, blue: 0.2, alpha: 1), size: CGSize(width: 26, height: 26))
        wet.position = point
        wet.zPosition = 4
        wet.isHidden = true
        parent.addChild(wet)
        plant.position = CGPoint(x: point.x, y: point.y - 8)
        plant.zPosition = z
        plant.isHidden = true
        parent.addChild(plant)
    }

    /// Обновляет вид, только если что-то поменялось.
    func refresh(bed: Bed, unlocked: Bool, now: Date) {
        let stage = bed.stage(at: now)
        let ripe = bed.isRipe(at: now)
        let key = "\(unlocked)|\(bed.crop?.rawValue ?? "-")|\(stage)|\(bed.watered)"
        guard key != shownKey else { return }
        shownKey = key
        soil.alpha = unlocked ? 1 : 0.3
        wet.isHidden = !(bed.watered && !ripe)
        plant.removeAction(forKey: "ripe")
        plant.setScale(1)
        guard let crop = bed.crop else {
            plant.isHidden = true
            return
        }
        let name = "\(crop.sprite)_\(stage)"
        if let tex = Sprites.texture(name) {
            plant.texture = tex
            plant.size = CGSize(width: tex.size().width * Sprites.scale, height: tex.size().height * Sprites.scale)
            plant.anchorPoint = Sprites.anchor(name)
            plant.isHidden = false
        } else {
            plant.texture = Art.emoji(crop.spec.produce.emoji ?? "🌱", size: 40)
            plant.size = CGSize(width: 24, height: 24)
            plant.anchorPoint = CGPoint(x: 0.5, y: 0)
            plant.isHidden = false
        }
        if ripe {
            let up = SKAction.scale(to: 1.08, duration: 0.45)
            let down = SKAction.scale(to: 1, duration: 0.45)
            up.timingMode = .easeInEaseOut
            down.timingMode = .easeInEaseOut
            plant.run(.repeatForever(.sequence([up, down])), withKey: "ripe")
        }
    }

    /// Сбросить кеш вида (после действия игрока).
    func invalidate() { shownKey = "" }
}

/// Торговец у прилавка: лавка у дома или бродячий с фиолетовым навесом.
final class TraderNode: SKNode {
    let kind: TraderKind

    init(kind: TraderKind, title: String) {
        self.kind = kind
        super.init()
        let stallName = kind == .stall ? "stall" : "stall_purple"
        if let stall = Sprites.node(stallName) {
            addChild(stall)
        } else {
            let emoji = SKSpriteNode(texture: Art.emoji("🏪", size: 96), size: CGSize(width: 72, height: 72))
            emoji.anchorPoint = CGPoint(x: 0.5, y: 0.1)
            addChild(emoji)
        }
        let npcName = kind == .stall ? "pl_merchant" : "pl_wanderer"
        let frames = Sprites.frames(npcName, cell: 64)
        if frames.count >= 6 {
            let npc = SKSpriteNode(texture: frames[0], size: CGSize(width: 64 * Sprites.scale, height: 64 * Sprites.scale))
            npc.anchorPoint = Sprites.anchor("pl")
            npc.position = CGPoint(x: -58, y: -4)
            npc.zPosition = 1
            npc.run(.repeatForever(.animate(with: Array(frames[0..<6]), timePerFrame: 1.0 / 6)))
            addChild(npc)
        }
        let sign = SignArt.sign(title: title, tag: .none, royal: kind == .wanderer)
        sign.position = CGPoint(x: 0, y: 112)
        sign.zPosition = 30
        addChild(bobbing(sign, height: 3, duration: 1.2))
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// Зверь в загоне: бродит внутри забора и иногда стоит.
final class PenAnimal {
    let node: CompanionNode
    private let area: CGRect
    private var goal: CGPoint
    private var wait = Double.random(in: 0.5...3)

    init(animal: AnimalID, at point: CGPoint, area: CGRect) {
        node = CompanionNode(animal: animal)
        node.position = point
        self.area = area
        goal = point
    }

    func update(_ dt: Double) {
        if distance(node.position, goal) < 6 {
            wait -= dt
            if wait <= 0 {
                wait = Double.random(in: 1.5...5)
                goal = CGPoint(x: CGFloat.random(in: area.minX...area.maxX), y: CGFloat.random(in: area.minY...area.maxY))
            }
        }
        node.move(toward: goal, dt: dt, speed: 38, stopAt: 4)
    }
}
