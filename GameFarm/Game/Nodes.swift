import SpriteKit
import UIKit

private func sprite(_ texture: SKTexture, _ size: CGSize, _ position: CGPoint = .zero) -> SKSpriteNode {
    let node = SKSpriteNode(texture: texture, size: size)
    node.position = position
    return node
}

private func emojiSprite(_ emoji: String, _ size: CGFloat, x: CGFloat = 0, y: CGFloat = 0,
                         tint: UIColor? = nil, blend: CGFloat = 0) -> SKSpriteNode {
    let node = sprite(Art.emoji(emoji, size: size), CGSize(width: size, height: size), CGPoint(x: x, y: y))
    if let tint {
        node.color = tint
        node.colorBlendFactor = blend
    }
    return node
}

private func shadowSprite(_ width: CGFloat, y: CGFloat = 0) -> SKSpriteNode {
    let node = sprite(Art.shadow, CGSize(width: width, height: width * 0.36), CGPoint(x: 0, y: y))
    node.alpha = 0.2
    return node
}

/// Дерево качается от ветра: точка вращения у основания.
private func swaying(_ node: SKSpriteNode, amount: CGFloat = 0.035) -> SKSpriteNode {
    let h = node.size.height
    node.anchorPoint = CGPoint(x: 0.5, y: 0.06)
    node.position.y -= h * 0.44
    let duration = Double.random(in: 1.6...2.4)
    let sway = SKAction.sequence([
        .rotate(toAngle: amount, duration: duration, shortestUnitArc: true),
        .rotate(toAngle: -amount, duration: duration, shortestUnitArc: true)
    ])
    sway.timingMode = .easeInEaseOut
    node.run(.sequence([.wait(forDuration: Double.random(in: 0...2)), .repeatForever(sway)]))
    return node
}

enum NodeArt {
    /// Живой вид точки и вид после добычи.
    static func build(_ type: NodeType) -> (alive: SKNode, dead: SKNode) {
        let alive = SKNode()
        let dead = SKNode()
        let snow = UIColor.white
        let purple = UIColor(red: 0.62, green: 0.42, blue: 1, alpha: 1)

        switch type {
        case .tree:
            alive.addChild(shadowSprite(46))
            alive.addChild(swaying(emojiSprite("🌳", 72, y: 28)))
            dead.addChild(shadowSprite(28))
            dead.addChild(sprite(Art.stump(), CGSize(width: 30, height: 22), CGPoint(x: 0, y: 4)))
        case .pine:
            alive.addChild(shadowSprite(42))
            alive.addChild(swaying(emojiSprite("🌲", 76, y: 30)))
            dead.addChild(shadowSprite(26))
            dead.addChild(sprite(Art.stump(), CGSize(width: 28, height: 21), CGPoint(x: 0, y: 4)))
        case .palm:
            alive.addChild(shadowSprite(44))
            alive.addChild(swaying(emojiSprite("🌴", 78, y: 30), amount: 0.05))
            dead.addChild(shadowSprite(26))
            dead.addChild(sprite(Art.stump(UIColor(red: 0.7, green: 0.5, blue: 0.3, alpha: 1)), CGSize(width: 26, height: 20), CGPoint(x: 0, y: 4)))
        case .snowPine:
            alive.addChild(shadowSprite(46))
            alive.addChild(swaying(emojiSprite("🌲", 80, y: 32, tint: snow, blend: 0.42)))
            dead.addChild(shadowSprite(28))
            dead.addChild(sprite(Art.stump(UIColor(red: 0.6, green: 0.5, blue: 0.45, alpha: 1)), CGSize(width: 30, height: 22), CGPoint(x: 0, y: 4)))
        case .glowTree:
            let glow = sprite(Art.glow, CGSize(width: 110, height: 110), CGPoint(x: 0, y: 34))
            glow.color = purple
            glow.colorBlendFactor = 1
            glow.alpha = 0.45
            glow.blendMode = .add
            alive.addChild(glow)
            alive.addChild(shadowSprite(48))
            alive.addChild(swaying(emojiSprite("🌳", 80, y: 30, tint: purple, blend: 0.55)))
            dead.addChild(sprite(Art.stump(purple), CGSize(width: 30, height: 22), CGPoint(x: 0, y: 4)))
        case .bush:
            alive.addChild(shadowSprite(34))
            alive.addChild(emojiSprite("🌿", 44, y: 14))
            alive.addChild(emojiSprite("🫐", 22, x: -6, y: 16))
            alive.addChild(emojiSprite("🫐", 18, x: 9, y: 22))
            dead.addChild(emojiSprite("🌿", 34, y: 10))
            dead.alpha = 0.8
        case .appleTree:
            alive.addChild(shadowSprite(46))
            let tree = swaying(emojiSprite("🌳", 72, y: 28))
            for (x, y) in [(-14.0, 52.0), (12.0, 58.0), (0.0, 40.0)] {
                let apple = emojiSprite("🍎", 16, x: CGFloat(x), y: CGFloat(y) + tree.size.height * 0.44 - 28)
                apple.zPosition = 1
                tree.addChild(apple)
            }
            alive.addChild(tree)
            dead.addChild(shadowSprite(46))
            dead.addChild(swaying(emojiSprite("🌳", 72, y: 28)))
        case .mushroom:
            alive.addChild(emojiSprite("🍄", 32, x: -5, y: 12))
            alive.addChild(emojiSprite("🍄", 22, x: 10, y: 8))
            dead.addChild(sprite(Art.dirt, CGSize(width: 28, height: 13)))
        case .carrot:
            alive.addChild(sprite(Art.dirt, CGSize(width: 36, height: 16)))
            for (x, r) in [(-8.0, 0.7), (8.0, 0.5)] {
                let carrot = emojiSprite("🥕", 28, x: CGFloat(x), y: 10)
                carrot.zRotation = CGFloat(r) + .pi / 2
                alive.addChild(carrot)
            }
            dead.addChild(sprite(Art.dirt, CGSize(width: 36, height: 16)))
        case .cactus:
            alive.addChild(shadowSprite(34))
            alive.addChild(emojiSprite("🌵", 58, y: 22))
            dead.addChild(emojiSprite("🌱", 20, y: 6))
        case .bamboo:
            alive.addChild(shadowSprite(34))
            alive.addChild(swaying(emojiSprite("🎋", 64, y: 26), amount: 0.06))
            dead.addChild(emojiSprite("🌱", 20, y: 6))
        case .glowShroom:
            let cyan = UIColor(red: 0.35, green: 0.95, blue: 1, alpha: 1)
            let glow = sprite(Art.glow, CGSize(width: 70, height: 70), CGPoint(x: 0, y: 12))
            glow.color = cyan
            glow.colorBlendFactor = 1
            glow.alpha = 0.55
            glow.blendMode = .add
            glow.run(.repeatForever(.sequence([.fadeAlpha(to: 0.3, duration: 1.2), .fadeAlpha(to: 0.6, duration: 1.2)])))
            alive.addChild(glow)
            alive.addChild(emojiSprite("🍄", 34, x: -6, y: 12, tint: cyan, blend: 0.5))
            alive.addChild(emojiSprite("🍄", 24, x: 10, y: 8, tint: cyan, blend: 0.5))
            dead.addChild(sprite(Art.dirt, CGSize(width: 28, height: 13)))
        case .rock:
            alive.addChild(shadowSprite(40))
            alive.addChild(emojiSprite("🪨", 48, y: 14))
            dead.addChild(sprite(Art.rubble(UIColor(white: 0.55, alpha: 1)), CGSize(width: 30, height: 18), CGPoint(x: 0, y: 4)))
        case .boulder:
            alive.addChild(shadowSprite(62))
            alive.addChild(emojiSprite("🪨", 76, y: 22))
            dead.addChild(sprite(Art.rubble(UIColor(white: 0.55, alpha: 1)), CGSize(width: 44, height: 26), CGPoint(x: 0, y: 4)))
        case .coalOre, .ironOre, .goldOre:
            let kind: ResourceKind = type == .coalOre ? .coal : (type == .ironOre ? .iron : .gold)
            alive.addChild(shadowSprite(52))
            alive.addChild(sprite(Art.texture("oreTex|\(kind.rawValue)") { Art.oreImage(kind.oreColor, size: 128) }, CGSize(width: 58, height: 58), CGPoint(x: 0, y: 18)))
            dead.addChild(sprite(Art.rubble(UIColor(white: 0.5, alpha: 1)), CGSize(width: 38, height: 22), CGPoint(x: 0, y: 4)))
        case .iceBlock:
            alive.addChild(shadowSprite(44))
            alive.addChild(emojiSprite("🧊", 52, y: 18))
            dead.addChild(sprite(Art.rubble(UIColor(red: 0.75, green: 0.9, blue: 1, alpha: 1)), CGSize(width: 34, height: 20), CGPoint(x: 0, y: 4)))
        case .diamondOre:
            alive.addChild(shadowSprite(52))
            alive.addChild(sprite(Art.texture("oreTex|diamond") { Art.oreImage(ResourceKind.diamond.oreColor, size: 128) }, CGSize(width: 58, height: 58), CGPoint(x: 0, y: 18)))
            let gem = emojiSprite("💎", 26, x: 12, y: 36)
            gem.run(.repeatForever(.sequence([.scale(to: 1.12, duration: 0.8), .scale(to: 1, duration: 0.8)])))
            alive.addChild(gem)
            dead.addChild(sprite(Art.rubble(UIColor(white: 0.5, alpha: 1)), CGSize(width: 38, height: 22), CGPoint(x: 0, y: 4)))
        case .crystalOre:
            let glow = sprite(Art.glow, CGSize(width: 96, height: 96), CGPoint(x: 0, y: 24))
            glow.color = purple
            glow.colorBlendFactor = 1
            glow.alpha = 0.5
            glow.blendMode = .add
            glow.run(.repeatForever(.sequence([.fadeAlpha(to: 0.25, duration: 1.4), .fadeAlpha(to: 0.55, duration: 1.4)])))
            alive.addChild(glow)
            alive.addChild(shadowSprite(52))
            alive.addChild(sprite(Art.texture("crystalTex") { Art.crystalImage(size: 128) }, CGSize(width: 66, height: 66), CGPoint(x: 0, y: 24)))
            dead.addChild(sprite(Art.rubble(UIColor(red: 0.55, green: 0.45, blue: 0.7, alpha: 1)), CGSize(width: 38, height: 22), CGPoint(x: 0, y: 4)))
        case .fishSpot, .oasisFish:
            let ripple = sprite(Art.ripple, CGSize(width: 54, height: 27))
            ripple.run(.repeatForever(.sequence([.scale(to: 1.15, duration: 1.0), .scale(to: 0.9, duration: 1.0)])))
            alive.addChild(ripple)
            let fish = emojiSprite("🐟", 20, x: 0, y: 4)
            fish.run(.repeatForever(.sequence([.moveBy(x: 0, y: 4, duration: 0.6), .moveBy(x: 0, y: -4, duration: 0.6)])))
            alive.addChild(fish)
            let calm = sprite(Art.ripple, CGSize(width: 40, height: 20))
            calm.alpha = 0.3
            dead.addChild(calm)
        case .iceHole:
            alive.addChild(sprite(Art.iceHole, CGSize(width: 54, height: 30)))
            let fish = emojiSprite("🐟", 18, x: 0, y: 2)
            fish.run(.repeatForever(.sequence([.fadeAlpha(to: 0.4, duration: 0.8), .fadeAlpha(to: 1, duration: 0.8)])))
            alive.addChild(fish)
            dead.addChild(sprite(Art.iceHole, CGSize(width: 54, height: 30)))
        }
        return (alive, dead)
    }
}

final class HPBar: SKNode {
    private let back = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.55), size: CGSize(width: 38, height: 7))
    private let fill = SKSpriteNode(color: .green, size: CGSize(width: 34, height: 4))

    override init() {
        super.init()
        addChild(back)
        fill.anchorPoint = CGPoint(x: 0, y: 0.5)
        fill.position = CGPoint(x: -17, y: 0)
        addChild(fill)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func set(_ fraction: Double) {
        let f = CGFloat(max(0, min(1, fraction)))
        fill.xScale = max(0.02, f)
        fill.color = UIColor(red: 1 - f * 0.7, green: 0.35 + f * 0.55, blue: 0.25, alpha: 1)
    }
}

/// Точка ресурса на карте. Всегда на одном месте, после добычи восстанавливается.
final class ResourceSpot: SKNode {
    let spec: NodeSpec
    var hp: Double
    private(set) var alive = true
    private var respawnLeft: Double = 0
    private let aliveArt: SKNode
    private let deadArt: SKNode
    private let bar = HPBar()
    private var barTime: Double = 0

    init(type: NodeType) {
        spec = type.spec
        hp = spec.hp
        let art = NodeArt.build(type)
        aliveArt = art.alive
        deadArt = art.dead
        super.init()
        deadArt.alpha = 0
        addChild(deadArt)
        addChild(aliveArt)
        bar.position = CGPoint(x: 0, y: spec.barHeight)
        bar.alpha = 0
        bar.zPosition = 5
        addChild(bar)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var isSolid: Bool { spec.blocking && (alive || spec.keepsBody) }

    func tick(_ dt: Double) {
        if barTime > 0 {
            barTime -= dt
            if barTime <= 0 { bar.run(.fadeOut(withDuration: 0.25)) }
        }
        guard !alive else { return }
        respawnLeft -= dt
        if respawnLeft <= 0 { respawn() }
    }

    func playHit() {
        aliveArt.removeAction(forKey: "hit")
        aliveArt.position = .zero
        aliveArt.setScale(1)
        let shake = SKAction.sequence([
            .moveBy(x: 3, y: 0, duration: 0.03), .moveBy(x: -6, y: 0, duration: 0.05), .moveBy(x: 3, y: 0, duration: 0.03)
        ])
        let squash = SKAction.sequence([.scaleX(to: 1.08, y: 0.93, duration: 0.05), .scale(to: 1, duration: 0.08)])
        aliveArt.run(.group([shake, squash]), withKey: "hit")
    }

    func showHP() {
        bar.set(hp / spec.hp)
        bar.removeAllActions()
        bar.alpha = 1
        barTime = 1.6
    }

    func deplete(respawnIn seconds: Double) {
        alive = false
        hp = 0
        respawnLeft = seconds
        barTime = 0
        bar.removeAllActions()
        bar.alpha = 0
        aliveArt.removeAction(forKey: "hit")
        aliveArt.position = .zero
        aliveArt.run(.group([.fadeOut(withDuration: 0.18), .scale(to: 0.7, duration: 0.18)]), withKey: "state")
        deadArt.run(.fadeIn(withDuration: 0.2), withKey: "state")
    }

    private func respawn() {
        alive = true
        hp = spec.hp
        aliveArt.removeAction(forKey: "state")
        aliveArt.alpha = 1
        aliveArt.setScale(0.3)
        let grow = SKAction.sequence([.scale(to: 1.12, duration: 0.22), .scale(to: 1, duration: 0.12)])
        grow.timingMode = .easeOut
        aliveArt.run(grow, withKey: "state")
        deadArt.run(.fadeOut(withDuration: 0.2), withKey: "state")
    }
}

final class PlayerNode: SKNode {
    private let body = SKSpriteNode(texture: Art.emoji("🧑‍🌾", size: 56), size: CGSize(width: 46, height: 46))
    private let tool = SKSpriteNode(texture: Art.emoji("🪓", size: 32), size: CGSize(width: 24, height: 24))
    private let shadowNode = SKSpriteNode(texture: Art.shadow, size: CGSize(width: 32, height: 12))
    private var phase: Double = 0
    private var facing: CGFloat = 1
    private var currentTool: ToolKind = .axe

    override init() {
        super.init()
        shadowNode.alpha = 0.25
        addChild(shadowNode)
        body.position = CGPoint(x: 0, y: 20)
        addChild(body)
        tool.position = CGPoint(x: 16, y: 22)
        tool.alpha = 0
        tool.zPosition = 1
        addChild(tool)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func animate(walking: Bool, dx: CGFloat, dt: Double) {
        if walking {
            phase += dt * 14
            body.position.y = 20 + CGFloat(abs(sin(phase))) * 4
            body.zRotation = CGFloat(sin(phase)) * 0.07
            if abs(dx) > 0.15 {
                facing = dx > 0 ? 1 : -1
                body.xScale = facing
            }
        } else {
            body.position.y += (20 - body.position.y) * 0.3
            body.zRotation *= 0.7
        }
    }

    func swing(_ kind: ToolKind, toward target: CGPoint) {
        let dir: CGFloat = target.x >= position.x ? 1 : -1
        facing = dir
        body.xScale = dir
        if kind != currentTool {
            currentTool = kind
            tool.texture = Art.emoji(kind.emoji, size: 32)
        }
        tool.removeAllActions()
        tool.position = CGPoint(x: 18 * dir, y: 24)
        tool.xScale = dir
        tool.zRotation = 0.9 * dir
        tool.alpha = 1
        let down = SKAction.rotate(toAngle: -0.7 * dir, duration: 0.09)
        down.timingMode = .easeIn
        tool.run(.sequence([down, .rotate(toAngle: 0.2 * dir, duration: 0.12), .wait(forDuration: 0.2), .fadeOut(withDuration: 0.2)]))
        body.run(.sequence([.scaleX(to: dir * 1.06, y: 0.95, duration: 0.06), .scaleX(to: dir, y: 1, duration: 0.08)]))
    }

    func bubble(_ text: String) {
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = text
        label.fontSize = 22
        label.position = CGPoint(x: 0, y: 52)
        label.zPosition = 10
        addChild(label)
        label.run(.sequence([.group([.moveBy(x: 0, y: 14, duration: 0.6), .sequence([.wait(forDuration: 0.4), .fadeOut(withDuration: 0.2)])]), .removeFromParent()]))
    }
}

final class CompanionNode: SKNode {
    let animal: AnimalID
    private let body: SKSpriteNode
    private let shadowNode = SKSpriteNode(texture: Art.shadow, size: CGSize(width: 24, height: 9))
    weak var target: ResourceSpot?
    var hitTimer: Double = 0
    var retargetTimer: Double = 0
    private var phase = Double.random(in: 0...6)

    init(animal: AnimalID) {
        self.animal = animal
        body = SKSpriteNode(texture: Art.emoji(animal.spec.emoji, size: 48), size: CGSize(width: 34, height: 34))
        super.init()
        shadowNode.alpha = 0.22
        addChild(shadowNode)
        body.position = CGPoint(x: 0, y: 15)
        addChild(body)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Двигается к точке и подпрыгивает при ходьбе.
    func move(toward point: CGPoint, dt: Double, speed: Double, stopAt: CGFloat = 8) {
        let dx = point.x - position.x
        let dy = point.y - position.y
        let d = hypot(dx, dy)
        if d > stopAt {
            let step = min(d - stopAt, CGFloat(speed * dt) * min(1.6, max(0.6, d / 80)))
            position.x += dx / d * step
            position.y += dy / d * step
            phase += dt * 16
            body.position.y = 15 + CGFloat(abs(sin(phase))) * 5
            if abs(dx) > 2 { body.xScale = dx > 0 ? -1 : 1 }
        } else {
            body.position.y += (15 - body.position.y) * 0.3
        }
    }

    func attack(toward point: CGPoint) {
        let dx = point.x - position.x
        if abs(dx) > 2 { body.xScale = dx > 0 ? -1 : 1 }
        let lunge = CGVector(dx: (point.x - position.x) * 0.15, dy: (point.y - position.y) * 0.15)
        body.run(.sequence([.moveBy(x: lunge.dx, y: lunge.dy, duration: 0.07), .moveBy(x: -lunge.dx, y: -lunge.dy, duration: 0.1)]))
    }
}

final class WildNode: SKNode {
    let animal: AnimalID
    var life: Double = 160
    private let home: CGPoint
    private var goal: CGPoint
    private var wait: Double = 1
    private let body: SKSpriteNode

    init(animal: AnimalID, at point: CGPoint) {
        self.animal = animal
        home = point
        goal = point
        body = SKSpriteNode(texture: Art.emoji(animal.spec.emoji, size: 56), size: CGSize(width: 40, height: 40))
        super.init()
        position = point
        let shadowNode = SKSpriteNode(texture: Art.shadow, size: CGSize(width: 28, height: 10))
        shadowNode.alpha = 0.22
        addChild(shadowNode)
        body.position = CGPoint(x: 0, y: 18)
        addChild(body)

        let sparkle = SKSpriteNode(texture: Art.glow, size: CGSize(width: 80, height: 80))
        sparkle.color = UIColor(red: 1, green: 0.85, blue: 0.4, alpha: 1)
        sparkle.colorBlendFactor = 1
        sparkle.blendMode = .add
        sparkle.alpha = 0.35
        sparkle.position = CGPoint(x: 0, y: 18)
        sparkle.zPosition = -1
        sparkle.run(.repeatForever(.sequence([.fadeAlpha(to: 0.15, duration: 0.9), .fadeAlpha(to: 0.4, duration: 0.9)])))
        addChild(sparkle)

        let mark = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        mark.text = "?"
        mark.fontSize = 18
        mark.fontColor = .white
        mark.verticalAlignmentMode = .center
        let bubble = SKShapeNode(circleOfRadius: 12)
        bubble.fillColor = UIColor(red: 0.95, green: 0.4, blue: 0.6, alpha: 1)
        bubble.strokeColor = .white
        bubble.lineWidth = 2
        bubble.position = CGPoint(x: 0, y: 50)
        bubble.addChild(mark)
        bubble.run(.repeatForever(.sequence([.moveBy(x: 0, y: 4, duration: 0.5), .moveBy(x: 0, y: -4, duration: 0.5)])))
        addChild(bubble)

        setScale(0.1)
        run(.scale(to: 1, duration: 0.3))
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func wander(_ dt: Double) {
        life -= dt
        wait -= dt
        let d = distance(position, goal)
        if d < 4 {
            if wait <= 0 {
                let a = CGFloat.random(in: 0...(.pi * 2))
                let r = CGFloat.random(in: 20...90)
                goal = CGPoint(x: home.x + cos(a) * r, y: home.y + sin(a) * r)
                wait = Double.random(in: 1.5...3.5)
            }
        } else {
            let step = min(d, CGFloat(38 * dt))
            position.x += (goal.x - position.x) / d * step
            position.y += (goal.y - position.y) / d * step
            if abs(goal.x - position.x) > 1 { body.xScale = goal.x > position.x ? -1 : 1 }
        }
    }

    func leave() {
        run(.sequence([.group([.fadeOut(withDuration: 0.4), .scale(to: 0.4, duration: 0.4)]), .removeFromParent()]))
    }
}

final class Joystick: SKNode {
    private let base = SKShapeNode(circleOfRadius: 58)
    private let knob = SKShapeNode(circleOfRadius: 26)
    private(set) var vector = CGVector.zero
    private var origin = CGPoint.zero
    private let radius: CGFloat = 58

    override init() {
        super.init()
        base.fillColor = UIColor.white.withAlphaComponent(0.12)
        base.strokeColor = UIColor.white.withAlphaComponent(0.45)
        base.lineWidth = 2
        knob.fillColor = UIColor.white.withAlphaComponent(0.55)
        knob.strokeColor = UIColor.white.withAlphaComponent(0.8)
        knob.lineWidth = 2
        addChild(base)
        addChild(knob)
        alpha = 0
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func begin(at point: CGPoint) {
        origin = point
        base.position = point
        knob.position = point
        vector = .zero
        removeAllActions()
        run(.fadeAlpha(to: 1, duration: 0.08))
    }

    func move(to point: CGPoint) {
        let dx = point.x - origin.x
        let dy = point.y - origin.y
        let d = hypot(dx, dy)
        let clamped = min(d, radius)
        if d > 0.5 {
            knob.position = CGPoint(x: origin.x + dx / d * clamped, y: origin.y + dy / d * clamped)
            let strength = min(1, d / radius)
            vector = CGVector(dx: dx / d * strength, dy: dy / d * strength)
        } else {
            knob.position = origin
            vector = .zero
        }
    }

    func end() {
        vector = .zero
        removeAllActions()
        run(.fadeAlpha(to: 0, duration: 0.15))
    }
}

/// Стрелка у края экрана, указывающая на склад или на дикого зверя.
final class PointerArrow: SKNode {
    let pointer: SKSpriteNode
    private let iconNode: SKSpriteNode

    init(color: UIColor, icon: String) {
        pointer = SKSpriteNode(texture: Art.arrow, size: CGSize(width: 30, height: 30))
        pointer.color = color
        pointer.colorBlendFactor = 1
        iconNode = SKSpriteNode(texture: Art.emoji(icon, size: 40), size: CGSize(width: 26, height: 26))
        super.init()
        let disc = SKShapeNode(circleOfRadius: 19)
        disc.fillColor = UIColor.black.withAlphaComponent(0.45)
        disc.strokeColor = color
        disc.lineWidth = 2.5
        addChild(disc)
        addChild(iconNode)
        addChild(pointer)
        isHidden = true
        run(.repeatForever(.sequence([.scale(to: 1.1, duration: 0.5), .scale(to: 1, duration: 0.5)])))
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func point(_ angle: CGFloat) {
        pointer.zRotation = angle
        pointer.position = CGPoint(x: cos(angle) * 30, y: sin(angle) * 30)
    }
}
