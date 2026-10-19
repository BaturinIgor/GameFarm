import SpriteKit
import UIKit

final class HPBar: SKNode {
    private let back = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.55), size: CGSize(width: 40, height: 8))
    private let fill = SKSpriteNode(color: .green, size: CGSize(width: 36, height: 4))
    private let shine = SKSpriteNode(color: UIColor.white.withAlphaComponent(0.35), size: CGSize(width: 36, height: 1.5))

    override init() {
        super.init()
        addChild(back)
        fill.anchorPoint = CGPoint(x: 0, y: 0.5)
        fill.position = CGPoint(x: -18, y: 0)
        addChild(fill)
        shine.anchorPoint = CGPoint(x: 0, y: 0.5)
        shine.position = CGPoint(x: -18, y: 1)
        addChild(shine)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func set(_ fraction: Double) {
        let f = CGFloat(max(0, min(1, fraction)))
        fill.removeAction(forKey: "w")
        let resize = SKAction.scaleX(to: max(0.02, f), duration: 0.12)
        resize.timingMode = .easeOut
        fill.run(resize, withKey: "w")
        shine.xScale = max(0.02, f)
        fill.color = UIColor(red: 1 - f * 0.7, green: 0.35 + f * 0.55, blue: 0.25, alpha: 1)
    }

    func reset() {
        fill.removeAllActions()
        fill.xScale = 1
        shine.xScale = 1
    }
}

/// Точка ресурса на карте. Всегда на одном месте, после добычи восстанавливается.
final class ResourceSpot: SKNode {
    let spec: NodeSpec
    let style: DepleteStyle
    var hp: Double
    private(set) var alive = true
    private var respawnLeft: Double = 0
    private let aliveArt: SKNode
    private let deadArt: SKNode
    private let bar = HPBar()
    private let flash: SKSpriteNode
    private var barTime: Double = 0

    init(type: NodeType) {
        spec = type.spec
        style = NodeArt.style(type)
        hp = spec.hp
        let art = NodeArt.build(type)
        aliveArt = art.alive
        deadArt = art.dead
        flash = sprite(Art.glow, CGSize(width: spec.radius * 5, height: spec.radius * 5), CGPoint(x: 0, y: spec.barHeight * 0.4))
        super.init()
        deadArt.alpha = 0
        addChild(deadArt)
        addChild(aliveArt)
        flash.blendMode = .add
        flash.alpha = 0
        flash.zPosition = 3
        addChild(flash)
        bar.position = CGPoint(x: 0, y: spec.barHeight)
        bar.alpha = 0
        bar.zPosition = 5
        addChild(bar)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var isSolid: Bool { spec.blocking && (alive || spec.keepsBody) }

    /// Возвращает true, если ресурс только что вырос заново.
    @discardableResult
    func tick(_ dt: Double) -> Bool {
        if barTime > 0 {
            barTime -= dt
            if barTime <= 0 { bar.run(.fadeOut(withDuration: 0.25)) }
        }
        guard !alive else { return false }
        respawnLeft -= dt
        if respawnLeft <= 0 {
            respawn()
            return true
        }
        return false
    }

    func playHit(strong: Bool) {
        aliveArt.removeAction(forKey: "hit")
        aliveArt.position = .zero
        aliveArt.setScale(1)
        let amp: CGFloat = strong ? 5 : 3
        let shake = SKAction.sequence([
            .moveBy(x: amp, y: 0, duration: 0.03), .moveBy(x: -amp * 2, y: 0, duration: 0.05), .moveBy(x: amp, y: 0, duration: 0.03)
        ])
        let squash = SKAction.sequence([.scaleX(to: 1.1, y: 0.9, duration: 0.05), .scaleX(to: 0.97, y: 1.04, duration: 0.06), .scale(to: 1, duration: 0.07)])
        aliveArt.run(.group([shake, squash]), withKey: "hit")
        flash.removeAllActions()
        flash.alpha = strong ? 0.75 : 0.45
        flash.run(.fadeOut(withDuration: 0.18))
    }

    func showHP() {
        bar.set(hp / spec.hp)
        bar.removeAction(forKey: "fade")
        bar.alpha = 1
        barTime = 1.6
    }

    func deplete(respawnIn seconds: Double, from point: CGPoint) {
        alive = false
        hp = 0
        respawnLeft = seconds
        barTime = 0
        bar.removeAllActions()
        bar.alpha = 0
        aliveArt.removeAction(forKey: "hit")
        aliveArt.position = .zero
        aliveArt.setScale(1)

        let gone: SKAction
        switch style {
        case .fall:
            let dir: CGFloat = point.x <= position.x ? -1 : 1
            let tilt = SKAction.rotate(toAngle: dir * 1.45, duration: 0.42)
            tilt.timingMode = .easeIn
            let bounce = SKAction.rotate(toAngle: dir * 1.32, duration: 0.08)
            gone = .sequence([tilt, bounce, .group([.fadeOut(withDuration: 0.3), .moveBy(x: 0, y: -4, duration: 0.3)])])
        case .crumble:
            gone = .sequence([.scaleX(to: 1.15, y: 0.85, duration: 0.06), .group([.fadeOut(withDuration: 0.16), .scaleX(to: 1.3, y: 0.3, duration: 0.16)])])
        case .pop:
            let up = SKAction.scale(to: 1.25, duration: 0.08)
            up.timingMode = .easeOut
            gone = .sequence([up, .group([.fadeOut(withDuration: 0.12), .scale(to: 0.2, duration: 0.12)])])
        case .splash:
            gone = .group([.fadeOut(withDuration: 0.25), .scale(to: 1.4, duration: 0.25)])
        case .fade:
            gone = .fadeOut(withDuration: 0.25)
        }
        aliveArt.run(gone, withKey: "state")
        deadArt.run(.sequence([.wait(forDuration: style == .fall ? 0.35 : 0.05), .fadeIn(withDuration: 0.2)]), withKey: "state")
    }

    private func respawn() {
        alive = true
        hp = spec.hp
        bar.reset()
        aliveArt.removeAction(forKey: "state")
        aliveArt.zRotation = 0
        aliveArt.alpha = 1
        aliveArt.setScale(0.2)
        aliveArt.position = .zero
        let grow = SKAction.scale(to: 1.12, duration: 0.24)
        grow.timingMode = .easeOut
        let settle = SKAction.scale(to: 1, duration: 0.14)
        settle.timingMode = .easeInEaseOut
        aliveArt.run(.sequence([grow, settle]), withKey: "state")
        deadArt.run(.fadeOut(withDuration: 0.2), withKey: "state")
    }
}

final class PlayerNode: SKNode {
    private let body = SKSpriteNode(texture: Art.emoji("🧑‍🌾", size: 56), size: CGSize(width: 46, height: 46))
    private let tool = SKSpriteNode(texture: Art.emoji("🪓", size: 32), size: CGSize(width: 24, height: 24))
    private let shadowNode = SKSpriteNode(texture: Art.shadow, size: CGSize(width: 32, height: 12))
    private let ring = SKShapeNode(ellipseOf: CGSize(width: 40, height: 16))
    private var phase: Double = 0
    private var idle: Double = 0
    private var facing: CGFloat = 1
    private var currentTool: ToolKind = .axe

    override init() {
        super.init()
        ring.strokeColor = UIColor.white.withAlphaComponent(0.55)
        ring.lineWidth = 2
        ring.fillColor = UIColor.white.withAlphaComponent(0.08)
        addChild(ring)
        shadowNode.alpha = 0.28
        addChild(shadowNode)
        body.anchorPoint = CGPoint(x: 0.5, y: 0.08)
        body.position = CGPoint(x: 0, y: 0)
        addChild(body)
        tool.position = CGPoint(x: 16, y: 22)
        tool.alpha = 0
        tool.zPosition = 1
        addChild(tool)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// speedRatio от 0 до 1: насколько быстро бежит персонаж.
    func animate(velocity: CGVector, speedRatio: CGFloat, dt: Double) {
        if speedRatio > 0.05 {
            idle = 0
            phase += dt * (8 + 8 * Double(speedRatio))
            let hop = CGFloat(abs(sin(phase))) * 5 * speedRatio
            body.position.y = hop
            shadowNode.setScale(1 - hop * 0.03)
            if abs(velocity.dx) > 8 {
                let newFacing: CGFloat = velocity.dx > 0 ? 1 : -1
                if newFacing != facing { facing = newFacing }
            }
            let lean = -velocity.dx / 900 + CGFloat(sin(phase)) * 0.05 * speedRatio
            body.zRotation += (lean - body.zRotation) * 0.3
            body.xScale += (facing - body.xScale) * 0.35
            body.yScale = 1
        } else {
            idle += dt
            body.position.y += (0 - body.position.y) * 0.3
            body.zRotation *= 0.8
            body.xScale += (facing - body.xScale) * 0.35
            body.yScale = 1 + CGFloat(sin(idle * 3)) * 0.025
            shadowNode.setScale(1)
        }
    }

    func setSkin(_ emoji: String) {
        body.texture = Art.emoji(emoji, size: 56)
        body.removeAction(forKey: "pop")
        body.setScale(0.6)
        let grow = SKAction.scale(to: 1, duration: 0.25)
        grow.timingMode = .easeOut
        body.run(grow, withKey: "pop")
    }

    func swing(_ kind: ToolKind, toward target: CGPoint) {
        let dir: CGFloat = target.x >= position.x ? 1 : -1
        facing = dir
        if kind != currentTool {
            currentTool = kind
            tool.texture = Art.emoji(kind.emoji, size: 32)
        }
        tool.removeAllActions()
        tool.position = CGPoint(x: 18 * dir, y: 24)
        tool.xScale = dir
        tool.zRotation = 0.9 * dir
        tool.alpha = 1
        let down = SKAction.rotate(toAngle: -0.75 * dir, duration: 0.08)
        down.timingMode = .easeIn
        let back = SKAction.rotate(toAngle: 0.2 * dir, duration: 0.12)
        back.timingMode = .easeOut
        tool.run(.sequence([down, back, .wait(forDuration: 0.18), .fadeOut(withDuration: 0.18)]))
        body.removeAction(forKey: "swing")
        body.run(.sequence([.moveBy(x: 3 * dir, y: 0, duration: 0.06), .moveBy(x: -3 * dir, y: 0, duration: 0.1)]), withKey: "swing")
    }

    func celebrate() {
        let jump = SKAction.moveBy(x: 0, y: 18, duration: 0.15)
        jump.timingMode = .easeOut
        let land = SKAction.moveBy(x: 0, y: -18, duration: 0.15)
        land.timingMode = .easeIn
        body.run(.sequence([jump, land, jump, land]))
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
    private var velocity = CGVector.zero

    init(animal: AnimalID) {
        self.animal = animal
        body = SKSpriteNode(texture: Art.emoji(animal.spec.emoji, size: 48), size: CGSize(width: 34, height: 34))
        super.init()
        shadowNode.alpha = 0.24
        addChild(shadowNode)
        body.anchorPoint = CGPoint(x: 0.5, y: 0.1)
        addChild(body)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Плавно двигается к точке с разгоном и подпрыгивает при ходьбе.
    func move(toward point: CGPoint, dt: Double, speed: Double, stopAt: CGFloat = 8) {
        let dx = point.x - position.x
        let dy = point.y - position.y
        let d = hypot(dx, dy)
        var desired = CGVector.zero
        if d > stopAt {
            let want = min(CGFloat(speed) * min(1.6, max(0.5, d / 90)), (d - stopAt) / CGFloat(max(dt, 0.001)))
            desired = CGVector(dx: dx / d * want, dy: dy / d * want)
        }
        let k = CGFloat(min(1, dt * 9))
        velocity.dx += (desired.dx - velocity.dx) * k
        velocity.dy += (desired.dy - velocity.dy) * k
        position.x += velocity.dx * CGFloat(dt)
        position.y += velocity.dy * CGFloat(dt)
        let moving = hypot(velocity.dx, velocity.dy)
        if moving > 12 {
            phase += dt * 15
            body.position.y = CGFloat(abs(sin(phase))) * 6
            if abs(velocity.dx) > 6 { body.xScale = velocity.dx > 0 ? -1 : 1 }
        } else {
            body.position.y += (0 - body.position.y) * 0.3
        }
    }

    func attack(toward point: CGPoint) {
        let dx = point.x - position.x
        if abs(dx) > 2 { body.xScale = dx > 0 ? -1 : 1 }
        let lunge = CGVector(dx: (point.x - position.x) * 0.18, dy: (point.y - position.y) * 0.18)
        body.run(.sequence([.moveBy(x: lunge.dx, y: lunge.dy, duration: 0.07), .moveBy(x: -lunge.dx, y: -lunge.dy, duration: 0.1)]))
    }

    func cheer() {
        body.run(.sequence([.moveBy(x: 0, y: 10, duration: 0.1), .moveBy(x: 0, y: -10, duration: 0.12)]))
    }
}

final class WildNode: SKNode {
    let animal: AnimalID
    var life: Double
    private let home: CGPoint
    private var goal: CGPoint
    private var wait: Double = 1
    private let body: SKSpriteNode

    init(animal: AnimalID, at point: CGPoint, life: Double) {
        self.animal = animal
        self.life = life
        home = point
        goal = point
        body = SKSpriteNode(texture: Art.emoji(animal.spec.emoji, size: 56), size: CGSize(width: 40, height: 40))
        super.init()
        position = point
        addChild(glowSprite(UIColor(red: 1, green: 0.85, blue: 0.4, alpha: 1), size: 90, y: 18, alpha: 0.4))
        let shadowNode = SKSpriteNode(texture: Art.shadow, size: CGSize(width: 28, height: 10))
        shadowNode.alpha = 0.24
        addChild(shadowNode)
        body.anchorPoint = CGPoint(x: 0.5, y: 0.1)
        addChild(body)

        let mark = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        mark.text = "?"
        mark.fontSize = 18
        mark.fontColor = .white
        mark.verticalAlignmentMode = .center
        let bubble = SKShapeNode(circleOfRadius: 12)
        bubble.fillColor = UIColor(red: 0.95, green: 0.4, blue: 0.6, alpha: 1)
        bubble.strokeColor = .white
        bubble.lineWidth = 2
        bubble.position = CGPoint(x: 0, y: 54)
        bubble.addChild(mark)
        addChild(bobbing(bubble, height: 4, duration: 0.5))

        setScale(0.1)
        let pop = SKAction.scale(to: 1, duration: 0.35)
        pop.timingMode = .easeOut
        run(pop)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func wander(_ dt: Double) {
        life -= dt
        wait -= dt
        let d = distance(position, goal)
        if d < 4 {
            body.position.y += (0 - body.position.y) * 0.3
            if wait <= 0 {
                let a = CGFloat.random(in: 0...(.pi * 2))
                let r = CGFloat.random(in: 20...90)
                goal = CGPoint(x: home.x + cos(a) * r, y: home.y + sin(a) * r)
                wait = Double.random(in: 1.5...3.5)
            }
        } else {
            let step = min(d, CGFloat(40 * dt))
            position.x += (goal.x - position.x) / d * step
            position.y += (goal.y - position.y) / d * step
            body.position.y = CGFloat(abs(sin(life * 12))) * 4
            if abs(goal.x - position.x) > 1 { body.xScale = goal.x > position.x ? -1 : 1 }
        }
    }

    func leave() {
        run(.sequence([.group([.fadeOut(withDuration: 0.4), .scale(to: 0.4, duration: 0.4)]), .removeFromParent()]))
    }
}

/// Клад: появляется время от времени, открывается, если подойти.
final class TreasureNode: SKNode {
    var life: Double

    init(at point: CGPoint, life: Double) {
        self.life = life
        super.init()
        position = point
        addChild(glowSprite(UIColor(red: 1, green: 0.8, blue: 0.2, alpha: 1), size: 110, y: 16, alpha: 0.6))
        addChild(shadowSprite(36))
        let box = emojiSprite("🎁", 40, y: 20)
        let wobble = SKAction.sequence([
            .rotate(toAngle: 0.12, duration: 0.12), .rotate(toAngle: -0.12, duration: 0.12), .rotate(toAngle: 0, duration: 0.1),
            .wait(forDuration: 1.4)
        ])
        box.run(.repeatForever(wobble))
        addChild(bobbing(box, height: 3, duration: 0.7))
        for i in 0..<3 {
            let s = sprite(Art.spark, CGSize(width: 12, height: 12), CGPoint(x: CGFloat(i - 1) * 18, y: 42 + CGFloat(i % 2) * 8))
            s.alpha = 0
            s.run(.sequence([.wait(forDuration: Double(i) * 0.4), .repeatForever(.sequence([
                .group([.fadeIn(withDuration: 0.3), .scale(to: 1.2, duration: 0.3)]),
                .group([.fadeOut(withDuration: 0.5), .scale(to: 0.6, duration: 0.5)]),
                .wait(forDuration: 0.4)
            ]))]))
            addChild(s)
        }
        setScale(0.1)
        let pop = SKAction.scale(to: 1, duration: 0.4)
        pop.timingMode = .easeOut
        run(pop)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// Бабочки и прочая живность для атмосферы.
final class CritterNode: SKSpriteNode {
    private var heading = CGFloat.random(in: 0...(.pi * 2))
    private var phase = Double.random(in: 0...6)
    private let flier: Bool
    private let baseScale: CGFloat

    init(emoji: String, flier: Bool) {
        self.flier = flier
        let size: CGFloat = flier ? 18 : 16
        baseScale = 1
        let tex = Art.emoji(emoji, size: 32)
        super.init(texture: tex, color: .clear, size: CGSize(width: size, height: size))
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(_ dt: Double, bounds: CGSize) {
        phase += dt
        heading += CGFloat(sin(phase * 0.7)) * CGFloat(dt) * 1.4
        let speed: CGFloat = flier ? 34 : 10
        position.x += cos(heading) * speed * CGFloat(dt)
        position.y += sin(heading) * speed * CGFloat(dt)
        if position.x < 60 || position.x > bounds.width - 60 || position.y < 60 || position.y > bounds.height - 60 {
            heading += .pi * CGFloat(dt) * 2
            position.x = max(50, min(bounds.width - 50, position.x))
            position.y = max(50, min(bounds.height - 50, position.y))
        }
        if flier {
            let flap = CGFloat(abs(sin(phase * 14)))
            xScale = (cos(heading) > 0 ? -1 : 1) * (0.55 + 0.45 * flap)
        } else {
            xScale = cos(heading) > 0 ? -1 : 1
        }
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
        knob.fillColor = UIColor.white.withAlphaComponent(0.6)
        knob.strokeColor = UIColor.white.withAlphaComponent(0.85)
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
        setScale(0.85)
        run(.group([.fadeAlpha(to: 1, duration: 0.08), .scale(to: 1, duration: 0.1)]))
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

/// Стрелка у края экрана, указывающая на склад, зверя или клад.
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
        let a = SKAction.scale(to: 1.1, duration: 0.5)
        let b = SKAction.scale(to: 1, duration: 0.5)
        a.timingMode = .easeInEaseOut
        b.timingMode = .easeInEaseOut
        run(.repeatForever(.sequence([a, b])))
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func point(_ angle: CGFloat) {
        pointer.zRotation = angle
        pointer.position = CGPoint(x: cos(angle) * 30, y: sin(angle) * 30)
    }
}
