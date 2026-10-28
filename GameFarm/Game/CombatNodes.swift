import SpriteKit
import UIKit

/// Монстр: бродит у своего логова, гонится за героем, если тот близко, и кусает при касании.
final class MonsterNode: SKNode {
    let kind: MonsterKind
    let level: Int
    let stats: MonsterStats
    let home: CGPoint
    private(set) var hp: Double
    private(set) var alive = true
    var attackCooldown: Double = 0.8

    private let body: SKSpriteNode
    private let bar = HPBar()
    private var idle: [SKTexture] = []
    private var move: [SKTexture] = []
    private var hurt: [SKTexture] = []
    private var death: [SKTexture] = []
    private var goal: CGPoint
    private var wait = Double.random(in: 0.5...2.5)
    private var chasing = false
    private var showing: Int = -1
    private var barTime: Double = 0
    private var knock = CGVector.zero

    static let aggro: CGFloat = 150
    static let leash: CGFloat = 320

    init(kind: MonsterKind, level: Int, at point: CGPoint) {
        self.kind = kind
        self.level = level
        stats = MonsterStats(kind: kind, level: level)
        hp = stats.hp
        home = point
        goal = point
        let cell: CGFloat = kind.isSlime ? 64 : 32
        let all = Sprites.frames(kind.sprite, cell: cell)
        let cols = kind.isSlime ? 8 : 6
        func row(_ r: Int, _ range: Range<Int>) -> [SKTexture] {
            let start = r * cols
            return range.compactMap { start + $0 < all.count ? all[start + $0] : nil }
        }
        if kind.isSlime {
            idle = row(0, 0..<4)
            move = row(1, 0..<8)
            hurt = row(2, 1..<4)
            death = row(2, 4..<8)
        } else {
            idle = row(1, 0..<6)
            move = row(4, 0..<6)
            hurt = row(8, 0..<4)
            death = row(6, 0..<4)
        }
        if let first = idle.first {
            body = SKSpriteNode(texture: first, size: CGSize(width: cell * Sprites.scale, height: cell * Sprites.scale))
            body.anchorPoint = Sprites.anchor(kind.sprite)
        } else {
            body = SKSpriteNode(texture: Art.emoji(kind.emoji, size: 48), size: CGSize(width: 34, height: 34))
            body.anchorPoint = CGPoint(x: 0.5, y: 0.1)
        }
        super.init()
        position = point
        addChild(body)
        bar.position = CGPoint(x: 0, y: kind.isSlime ? 40 : 56)
        bar.alpha = 0
        bar.zPosition = 5
        addChild(bar)
        play(idle, key: 0, fps: 6)
        setScale(0.2)
        run(.scale(to: 1, duration: 0.3))
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func play(_ frames: [SKTexture], key: Int, fps: Double) {
        guard showing != key, !frames.isEmpty else { return }
        showing = key
        body.removeAction(forKey: "anim")
        body.run(.repeatForever(.animate(with: frames, timePerFrame: 1 / fps)), withKey: "anim")
    }

    /// Шаг монстра. walkable проверяет, можно ли стоять в точке.
    /// Возвращает true, если монстр рядом с героем и может укусить.
    func update(_ dt: Double, hero: CGPoint, walkable: (CGPoint) -> Bool) -> Bool {
        guard alive else { return false }
        attackCooldown -= dt
        if barTime > 0 {
            barTime -= dt
            if barTime <= 0 { bar.run(.fadeOut(withDuration: 0.3)) }
        }
        let toHero = distance(position, hero)
        let fromHome = distance(position, home)
        if chasing {
            if fromHome > Self.leash || toHero > Self.aggro * 1.8 { chasing = false; goal = home }
        } else if toHero < Self.aggro && distance(hero, home) < Self.leash {
            chasing = true
        }
        if chasing { goal = hero }

        var step = CGVector.zero
        let d = distance(position, goal)
        if d > (chasing ? 18 : 4) {
            let speed = CGFloat(stats.speed) * (chasing ? 1.25 : 0.6)
            step = CGVector(dx: (goal.x - position.x) / d * speed * CGFloat(dt), dy: (goal.y - position.y) / d * speed * CGFloat(dt))
        } else if !chasing {
            wait -= dt
            if wait <= 0 {
                wait = Double.random(in: 1.5...4)
                let a = CGFloat.random(in: 0...(.pi * 2))
                let r = CGFloat.random(in: 20...90)
                let p = CGPoint(x: home.x + cos(a) * r, y: home.y + sin(a) * r)
                if walkable(p) { goal = p }
            }
        }
        // Отбрасывание после удара
        step.dx += knock.dx * CGFloat(dt)
        step.dy += knock.dy * CGFloat(dt)
        knock.dx *= CGFloat(exp(-dt * 10))
        knock.dy *= CGFloat(exp(-dt * 10))
        let next = CGPoint(x: position.x + step.dx, y: position.y + step.dy)
        if walkable(next) { position = next }
        let moving = hypot(step.dx, step.dy) > 0.2
        if body.action(forKey: "hurt") == nil {
            play(moving ? move : idle, key: moving ? 1 : 0, fps: moving ? 10 : 6)
        }
        if abs(step.dx) > 0.1 { body.xScale = step.dx < 0 ? -1 : 1 }
        return chasing && toHero < 26 && attackCooldown <= 0
    }

    /// Получить урон. Возвращает true, если монстр погиб.
    func hit(_ damage: Double, from point: CGPoint) -> Bool {
        guard alive else { return false }
        hp -= damage
        chasing = true
        bar.set(hp / stats.hp)
        bar.removeAllActions()
        bar.alpha = 1
        barTime = 2
        let d = max(1, distance(point, position))
        knock = CGVector(dx: (position.x - point.x) / d * 260, dy: (position.y - point.y) / d * 260)
        body.removeAction(forKey: "hurt")
        if !hurt.isEmpty {
            showing = -1
            body.removeAction(forKey: "anim")
            body.run(.animate(with: hurt, timePerFrame: 0.06), withKey: "hurt")
        }
        body.run(.sequence([.colorize(with: .white, colorBlendFactor: 0.8, duration: 0.03),
                            .colorize(withColorBlendFactor: 0, duration: 0.12)]))
        if hp <= 0 {
            alive = false
            bar.removeFromParent()
            body.removeAllActions()
            let fall: SKAction = death.isEmpty ? .fadeOut(withDuration: 0.3) : .animate(with: death, timePerFrame: 0.08)
            run(.sequence([.run { [weak self] in self?.body.run(fall) }, .wait(forDuration: 0.4),
                           .fadeOut(withDuration: 0.25), .removeFromParent()]))
            return true
        }
        return false
    }

    func biteDone() { attackCooldown = 1.1 }
}
