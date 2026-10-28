import SpriteKit
import UIKit

/// Укус монстра: сколько урона и был ли крит.
struct MonsterBite {
    let damage: Double
    let crit: Bool
    let traits: [MonsterTrait]
}

/// Чем закончился удар героя.
enum MonsterHit {
    case dodged
    case damaged
    case killed
}

/// Монстр: бродит у логова, гонится за героем, замахивается и кусает.
/// Особые свойства (крит, уклонение, щит, ярость...) видны значками над ним.
final class MonsterNode: SKNode {
    let kind: MonsterKind
    let level: Int
    let stats: MonsterStats
    let home: CGPoint
    let traits: [MonsterTrait]
    let boss: Bool
    private(set) var hp: Double
    private(set) var alive = true
    var attackCooldown: Double = 0.8
    /// В подземелье монстры видят героя через всю арену и не возвращаются домой.
    var aggroRange: CGFloat = 150
    var leashRange: CGFloat = 320

    private let body: SKSpriteNode
    private let bar = HPBar()
    private var shieldBar: HPBar?
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
    private var baseScale: CGFloat = 1
    private let tintColor: UIColor?

    // Замах перед укусом: герой успевает отойти.
    private var windup: Double = 0
    // Щит, ярость, восстановление
    private(set) var shield: Double = 0
    private var shieldMax: Double = 0
    private var shieldRegen: Double = 0
    private var sinceHit: Double = 99
    private(set) var enraged = false
    // Эффекты от оружия героя
    private var poisonLeft: Double = 0
    private var poisonDPS: Double = 0
    private var dotTick: Double = 0
    private var slowLeft: Double = 0
    private var slowFactor: Double = 1
    private var stunLeft: Double = 0

    static let windupTime = 0.38
    static let biteRange: CGFloat = 34

    init(kind: MonsterKind, level: Int, at point: CGPoint, traits: [MonsterTrait] = [], boss: Bool = false, tint: UIColor? = nil) {
        self.kind = kind
        self.level = level
        self.traits = traits
        self.boss = boss
        tintColor = tint
        stats = MonsterStats(kind: kind, level: level, boss: boss)
        hp = stats.hp
        home = point
        goal = point
        let sheet = kind.sheet
        let all = Sprites.frames(kind.sprite, cell: sheet.cell)
        func frames(_ spec: (row: Int, frames: Range<Int>)) -> [SKTexture] {
            let start = spec.row * sheet.cols
            return spec.frames.compactMap { start + $0 < all.count ? all[start + $0] : nil }
        }
        idle = frames(sheet.idle)
        move = frames(sheet.move)
        hurt = sheet.hurt.map(frames) ?? []
        death = frames(sheet.death)
        if let first = idle.first {
            body = SKSpriteNode(texture: first, size: CGSize(width: sheet.cell * Sprites.scale, height: sheet.cell * Sprites.scale))
            body.anchorPoint = Sprites.anchor(kind.sprite)
        } else {
            body = SKSpriteNode(texture: Art.emoji(kind.emoji, size: 48), size: CGSize(width: 34, height: 34))
            body.anchorPoint = CGPoint(x: 0.5, y: 0.1)
        }
        super.init()
        position = point
        addChild(body)
        if let tint {
            body.color = tint
            body.colorBlendFactor = 0.55
        }
        baseScale = boss ? 1.8 : 1
        let barY = sheet.bar * baseScale
        bar.position = CGPoint(x: 0, y: barY)
        bar.alpha = boss || !traits.isEmpty ? 1 : 0
        bar.zPosition = 5
        if boss { bar.setScale(1.5) }
        addChild(bar)
        if traits.contains(.shield) {
            shieldMax = stats.hp * 0.25
            shield = shieldMax
            let s = HPBar(color: UIColor(red: 0.55, green: 0.8, blue: 1, alpha: 1))
            s.position = CGPoint(x: 0, y: barY + 7 * (boss ? 1.5 : 1))
            s.zPosition = 5
            if boss { s.setScale(1.5) }
            addChild(s)
            shieldBar = s
        }
        // Значки свойств над полоской здоровья
        for (i, trait) in traits.enumerated() {
            guard let tex = Sprites.texture("ic_\(trait.icon)") else { continue }
            let icon = SKSpriteNode(texture: tex, size: CGSize(width: 12, height: 12))
            let count = CGFloat(traits.count)
            icon.position = CGPoint(x: (CGFloat(i) - (count - 1) / 2) * 13, y: barY + (shieldBar == nil ? 11 : 18) * (boss ? 1.5 : 1))
            icon.zPosition = 6
            addChild(icon)
        }
        play(idle, key: 0, fps: 6)
        setScale(0.2)
        run(.scale(to: 1, duration: 0.3))
        body.setScale(baseScale)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func play(_ frames: [SKTexture], key: Int, fps: Double) {
        guard showing != key, !frames.isEmpty else { return }
        showing = key
        body.removeAction(forKey: "anim")
        body.run(.repeatForever(.animate(with: frames, timePerFrame: 1 / fps)), withKey: "anim")
    }

    private var speedMult: Double {
        var m = 1.0
        if traits.contains(.swift) { m *= 1.4 }
        if enraged { m *= 1.3 }
        if slowLeft > 0 { m *= slowFactor }
        return m
    }

    /// Урон от яда и ожога за этот кадр (сцена списывает его как обычный урон).
    func tickEffects(_ dt: Double) -> Double {
        guard alive else { return 0 }
        sinceHit += dt
        slowLeft = max(0, slowLeft - dt)
        stunLeft = max(0, stunLeft - dt)
        // Регенерация и щит восстанавливаются, если по монстру давно не били.
        if traits.contains(.regen) && sinceHit > 2 && hp < stats.hp {
            hp = min(stats.hp, hp + stats.hp * 0.02 * dt)
            bar.set(hp / stats.hp)
        }
        if shieldMax > 0 && sinceHit > 6 && shield < shieldMax {
            shield = min(shieldMax, shield + shieldMax * 0.25 * dt)
            shieldBar?.set(shield / shieldMax)
        }
        guard poisonLeft > 0 else { return 0 }
        poisonLeft -= dt
        dotTick -= dt
        guard dotTick <= 0 else { return 0 }
        dotTick = 0.5
        return poisonDPS * 0.5
    }

    /// Шаг монстра. walkable проверяет, можно ли стоять в точке.
    /// Возвращает укус, если монстр закончил замах рядом с героем.
    func update(_ dt: Double, hero: CGPoint, walkable: (CGPoint) -> Bool) -> MonsterBite? {
        guard alive else { return nil }
        attackCooldown -= dt
        if barTime > 0 && !boss && traits.isEmpty {
            barTime -= dt
            if barTime <= 0 { bar.run(.fadeOut(withDuration: 0.3)) }
        }
        if stunLeft > 0 { return nil }
        let toHero = distance(position, hero)
        let fromHome = distance(position, home)

        // Замах: стоим и наливаемся красным, потом кусаем, если герой не отошёл.
        if windup > 0 {
            windup -= dt
            if windup <= 0 {
                body.run(.colorize(with: tintColor ?? .white, colorBlendFactor: tintColor == nil ? 0 : 0.55, duration: 0.08))
                attackCooldown = 1.1
                guard toHero < Self.biteRange + 10 else { return nil }
                let crit = traits.contains(.crit) && Double.random(in: 0..<1) < 0.2
                var damage = stats.damage * (enraged ? 1.5 : 1)
                if crit { damage *= 2 }
                body.run(.sequence([.moveBy(x: (hero.x - position.x) * 0.15, y: (hero.y - position.y) * 0.15, duration: 0.06),
                                    .moveBy(x: -(hero.x - position.x) * 0.15, y: -(hero.y - position.y) * 0.15, duration: 0.1)]))
                return MonsterBite(damage: damage, crit: crit, traits: traits)
            }
            return nil
        }

        if chasing {
            if fromHome > leashRange || toHero > aggroRange * 1.8 { chasing = false; goal = home }
        } else if toHero < aggroRange && distance(hero, home) < leashRange {
            chasing = true
        }
        if chasing { goal = hero }

        var step = CGVector.zero
        let d = distance(position, goal)
        if d > (chasing ? 22 : 4) {
            let speed = CGFloat(stats.speed * speedMult) * (chasing ? 1.25 : 0.6)
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
        if abs(step.dx) > 0.1 { body.xScale = (step.dx < 0 ? -1 : 1) * baseScale }
        if chasing && toHero < Self.biteRange && attackCooldown <= 0 {
            windup = Self.windupTime
            body.run(.colorize(with: UIColor(red: 1, green: 0.25, blue: 0.2, alpha: 1), colorBlendFactor: 0.7, duration: Self.windupTime * 0.8))
        }
        return nil
    }

    /// Получить урон. Уклонение и щит срабатывают здесь.
    func hit(_ damage: Double, from point: CGPoint, canDodge: Bool = true) -> MonsterHit {
        guard alive else { return .damaged }
        sinceHit = 0
        chasing = true
        if canDodge && traits.contains(.dodge) && Double.random(in: 0..<1) < 0.2 {
            body.run(.sequence([.moveBy(x: 8, y: 0, duration: 0.06), .moveBy(x: -8, y: 0, duration: 0.1)]))
            return .dodged
        }
        var left = damage
        if shield > 0 {
            let absorbed = min(shield, left)
            shield -= absorbed
            left -= absorbed
            shieldBar?.set(shield / max(1, shieldMax))
        }
        hp -= left
        bar.set(hp / stats.hp)
        bar.removeAllActions()
        bar.alpha = 1
        barTime = 2
        if traits.contains(.enrage) && !enraged && hp < stats.hp * 0.4 && hp > 0 {
            enraged = true
            let red = SKSpriteNode(texture: Effects.ringTexture, size: CGSize(width: 46 * baseScale, height: 22 * baseScale))
            red.color = UIColor(red: 1, green: 0.2, blue: 0.1, alpha: 1)
            red.colorBlendFactor = 1
            red.alpha = 0.6
            red.zPosition = -1
            red.run(.repeatForever(.sequence([.fadeAlpha(to: 0.2, duration: 0.4), .fadeAlpha(to: 0.6, duration: 0.4)])))
            addChild(red)
        }
        let d = max(1, distance(point, position))
        let push: CGFloat = boss ? 60 : 260
        knock = CGVector(dx: (position.x - point.x) / d * push, dy: (position.y - point.y) / d * push)
        body.removeAction(forKey: "hurt")
        if !hurt.isEmpty {
            showing = -1
            body.removeAction(forKey: "anim")
            body.run(.animate(with: hurt, timePerFrame: 0.06), withKey: "hurt")
        }
        body.run(.sequence([.colorize(with: .white, colorBlendFactor: 0.8, duration: 0.03),
                            .colorize(with: tintColor ?? .white, colorBlendFactor: tintColor == nil ? 0 : 0.55, duration: 0.12)]))
        if hp <= 0 {
            alive = false
            bar.removeFromParent()
            shieldBar?.removeFromParent()
            body.removeAllActions()
            let fall: SKAction = death.isEmpty ? .fadeOut(withDuration: 0.3) : .animate(with: death, timePerFrame: 0.08)
            run(.sequence([.run { [weak self] in self?.body.run(fall) }, .wait(forDuration: 0.5),
                           .fadeOut(withDuration: 0.25), .removeFromParent()]))
            return .killed
        }
        return .damaged
    }

    /// Восстановить здоровье (вампиризм).
    func heal(_ amount: Double) {
        guard alive else { return }
        hp = min(stats.hp, hp + amount)
        bar.set(hp / stats.hp)
    }

    func applyPoison(dps: Double, seconds: Double) {
        poisonDPS = max(poisonDPS, dps)
        poisonLeft = max(poisonLeft, seconds)
        body.run(.sequence([.colorize(with: UIColor(red: 0.4, green: 1, blue: 0.3, alpha: 1), colorBlendFactor: 0.6, duration: 0.1),
                            .colorize(with: tintColor ?? .white, colorBlendFactor: tintColor == nil ? 0 : 0.55, duration: 0.4)]))
    }

    func applySlow(_ factor: Double, seconds: Double) {
        slowFactor = factor
        slowLeft = max(slowLeft, seconds)
        body.run(.sequence([.colorize(with: UIColor(red: 0.5, green: 0.8, blue: 1, alpha: 1), colorBlendFactor: 0.6, duration: 0.1),
                            .colorize(with: tintColor ?? .white, colorBlendFactor: tintColor == nil ? 0 : 0.55, duration: 0.6)]))
    }

    func stun(_ seconds: Double) {
        stunLeft = max(stunLeft, seconds)
        windup = 0
    }

    var hpFraction: Double { max(0, hp / stats.hp) }
}
