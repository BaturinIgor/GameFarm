import SpriteKit
import UIKit

/// Ресурс, летящий к персонажу после добычи.
private final class LootFly {
    let node: SKSpriteNode
    var velocity: CGVector
    var age: Double = 0

    init(node: SKSpriteNode, velocity: CGVector) {
        self.node = node
        self.velocity = velocity
    }
}

final class GameScene: SKScene {
    private let game = GameState.shared

    private let world = SKNode()
    private let cam = SKCameraNode()
    private let player = PlayerNode()
    private let joystick = Joystick()
    private let fader = SKSpriteNode(color: .black, size: CGSize(width: 5000, height: 5000))
    private let tintNode = SKSpriteNode(color: .clear, size: CGSize(width: 5000, height: 5000))
    private let baseArrow = PointerArrow(color: UIColor(red: 1, green: 0.78, blue: 0.2, alpha: 1), icon: "📦")
    private let wildArrow = PointerArrow(color: UIColor(red: 0.95, green: 0.4, blue: 0.6, alpha: 1), icon: "🐾")
    private let treasureArrow = PointerArrow(color: UIColor(red: 1, green: 0.9, blue: 0.3, alpha: 1), icon: "🎁")
    private var darkness: SKSpriteNode?
    private var weather: SKEmitterNode?

    private var spec: LocationSpec = LocationID.meadow.spec
    private var loaded: LocationID?
    private var spots: [ResourceSpot] = []
    private var ponds: [(center: CGPoint, radius: CGFloat)] = []
    private var companions: [CompanionNode] = []
    private var companionSignature: [AnimalID] = []
    private var critters: [CritterNode] = []
    private var cloudShadows: [SKSpriteNode] = []
    private var loot: [LootFly] = []
    private var wild: WildNode?
    private var treasure: TreasureNode?
    private var chest = SKNode()
    private var houseCenter = CGPoint.zero

    private var lastTime: TimeInterval = 0
    private var velocity = CGVector.zero
    private var hitTimer: Double = 0
    private var hintTimer: Double = 0
    private var wildTimer: Double = 20
    private var treasureTimer: Double = 40
    private var saveTimer: Double = 0
    private var depositCooldown: Double = 0
    private var dustTimer: Double = 0
    private var shake: CGFloat = 0
    private var producerTimers: [AnimalID: Double] = [:]
    private var transitioning = false
    private var touch: UITouch?
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    private let heavyHaptic = UIImpactFeedbackGenerator(style: .medium)

    private static let slots: [CGPoint] = [
        CGPoint(x: -40, y: -28), CGPoint(x: 40, y: -28), CGPoint(x: -68, y: 6), CGPoint(x: 68, y: 6), CGPoint(x: 0, y: -56)
    ]
    private let playerRadius: CGFloat = 13

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .black
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = false
        guard world.parent == nil else { return }
        addChild(world)
        addChild(cam)
        camera = cam
        joystick.zPosition = 1000
        cam.addChild(joystick)
        for arrow in [baseArrow, wildArrow, treasureArrow] {
            arrow.zPosition = 960
            cam.addChild(arrow)
        }
        tintNode.zPosition = 920
        cam.addChild(tintNode)
        fader.zPosition = 2000
        fader.alpha = 0
        cam.addChild(fader)
        build(game.save.current)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        weather?.particlePositionRange = CGVector(dx: size.width * 1.4, dy: size.height * 1.4)
    }

    // MARK: Построение локации

    private func zFor(_ y: CGFloat) -> CGFloat {
        100 + (spec.size.height - y) / spec.size.height * 100
    }

    private func build(_ id: LocationID) {
        loaded = id
        spec = id.spec
        world.removeAllChildren()
        spots.removeAll()
        companions.removeAll()
        companionSignature = []
        critters.removeAll()
        cloudShadows.removeAll()
        loot.removeAll()
        wild = nil
        treasure = nil
        wildArrow.isHidden = true
        treasureArrow.isHidden = true
        game.setEncounter(nil)
        backgroundColor = spec.patches.last ?? spec.ground

        let placements = WorldLayout.spots(spec)
        let groundTexture = SKTexture(image: WorldArt.ground(spec, spots: placements))
        let ground = SKSpriteNode(texture: groundTexture, size: spec.size)
        ground.anchorPoint = .zero
        ground.zPosition = 0
        world.addChild(ground)

        for decor in WorldLayout.decorations(spec, avoiding: placements) {
            let node = SKSpriteNode(texture: Art.emoji(decor.emoji, size: 32), size: CGSize(width: decor.size, height: decor.size))
            node.position = decor.position
            node.alpha = decor.alpha
            node.zPosition = 1
            world.addChild(node)
        }
        for decor in WorldLayout.border(spec) {
            let node = SKSpriteNode(texture: Art.emoji(decor.emoji, size: 72), size: CGSize(width: decor.size, height: decor.size))
            node.position = decor.position
            node.zPosition = zFor(decor.position.y)
            world.addChild(node)
        }

        ponds = spec.ponds.filter { !$0.frozen }.map { (center: spec.point($0.x, $0.y), radius: $0.radius) }
        decoratePonds()
        buildBase()

        for placement in placements {
            let spot = ResourceSpot(type: placement.type)
            spot.position = placement.position
            spot.zPosition = zFor(placement.position.y)
            world.addChild(spot)
            spots.append(spot)
        }

        player.removeAllActions()
        player.position = CGPoint(x: spec.basePoint.x, y: spec.basePoint.y - 70)
        velocity = .zero
        world.addChild(player)
        syncCompanions()
        addAtmosphere()

        cam.position = clampedCamera(player.position)
        wildTimer = Double.random(in: 14...24)
        treasureTimer = Double.random(in: 30...50)
        game.showBanner(id)
    }

    private func decoratePonds() {
        for pond in spec.ponds {
            let c = spec.point(pond.x, pond.y)
            let lava = spec.id == .volcano
            if !pond.frozen && !lava {
                for i in 0..<3 {
                    let a = CGFloat(i) * 2.1 + 0.4
                    let emoji = spec.id == .sky ? "⭐" : (i == 0 ? "🪷" : "🍃")
                    let lily = SKSpriteNode(texture: Art.emoji(emoji, size: 32), size: CGSize(width: 22, height: 22))
                    lily.position = CGPoint(x: c.x + cos(a) * pond.radius * 0.55, y: c.y + sin(a) * pond.radius * 0.5)
                    lily.zPosition = 2
                    let turn = SKAction.rotate(byAngle: 0.15, duration: 2)
                    turn.timingMode = .easeInEaseOut
                    lily.run(.repeatForever(.sequence([turn, turn.reversed()])))
                    world.addChild(lily)
                }
            }
            // Блики на воде или пузыри лавы
            let count = Int(pond.radius / 18)
            for _ in 0..<count {
                let a = CGFloat.random(in: 0...(.pi * 2))
                let r = sqrt(CGFloat.random(in: 0...1)) * pond.radius * 0.85
                let p = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
                if lava {
                    let bubble = SKSpriteNode(texture: Art.dot, size: CGSize(width: 10, height: 10))
                    bubble.color = UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
                    bubble.colorBlendFactor = 1
                    bubble.position = p
                    bubble.zPosition = 2
                    bubble.alpha = 0
                    bubble.run(.sequence([.wait(forDuration: Double.random(in: 0...3)), .repeatForever(.sequence([
                        .group([.fadeIn(withDuration: 0.2), .scale(to: 1.4, duration: 0.8)]),
                        .group([.fadeOut(withDuration: 0.15), .scale(to: 2, duration: 0.15)]),
                        .scale(to: 0.5, duration: 0),
                        .wait(forDuration: Double.random(in: 0.8...2.5))
                    ]))]))
                    world.addChild(bubble)
                } else {
                    let glint = SKSpriteNode(texture: Art.spark, size: CGSize(width: 12, height: 12))
                    glint.position = p
                    glint.zPosition = 2
                    glint.blendMode = .add
                    glint.alpha = 0
                    glint.run(.sequence([.wait(forDuration: Double.random(in: 0...3)), .repeatForever(.sequence([
                        .group([.fadeAlpha(to: 0.8, duration: 0.4), .scale(to: 1.3, duration: 0.4)]),
                        .group([.fadeOut(withDuration: 0.6), .scale(to: 0.6, duration: 0.6)]),
                        .wait(forDuration: Double.random(in: 1...3))
                    ]))]))
                    world.addChild(glint)
                }
            }
            if lava {
                let glow = glowSprite(UIColor(red: 1, green: 0.45, blue: 0.1, alpha: 1), size: pond.radius * 2.8, alpha: 0.45)
                glow.position = c
                glow.zPosition = 3
                world.addChild(glow)
            }
        }
    }

    private func addAtmosphere() {
        // Тени облаков
        if spec.cloudShadows && !spec.dark {
            for _ in 0..<5 {
                let shadow = SKSpriteNode(texture: Art.cloudShadow, size: CGSize(width: CGFloat.random(in: 520...760), height: CGFloat.random(in: 320...440)))
                shadow.position = CGPoint(x: CGFloat.random(in: 0...spec.size.width), y: CGFloat.random(in: 0...spec.size.height))
                shadow.alpha = spec.id == .volcano ? 0.16 : 0.09
                shadow.zPosition = 450
                world.addChild(shadow)
                cloudShadows.append(shadow)
            }
        }
        // Живность
        let groundCritters: Set<String> = ["🐌", "🦂", "🐞"]
        for emoji in spec.critters {
            for _ in 0..<3 {
                let critter = CritterNode(emoji: emoji, flier: !groundCritters.contains(emoji))
                critter.position = CGPoint(x: CGFloat.random(in: 100...(spec.size.width - 100)),
                                           y: CGFloat.random(in: 260...(spec.size.height - 100)))
                critter.zPosition = groundCritters.contains(emoji) ? 99 : 420
                world.addChild(critter)
                critters.append(critter)
            }
        }
        // Погода
        weather?.removeFromParent()
        let emitter = makeWeather(spec.weather)
        emitter.targetNode = world
        emitter.particleZPosition = 930
        emitter.zPosition = 930
        emitter.particlePositionRange = CGVector(dx: max(size.width, 390) * 1.4, dy: max(size.height, 844) * 1.4)
        cam.addChild(emitter)
        emitter.advanceSimulationTime(8)
        weather = emitter
        // Тонировка и темнота
        if let tint = spec.tint {
            tintNode.color = tint
            tintNode.alpha = 1
        } else {
            tintNode.color = .clear
            tintNode.alpha = 0
        }
        darkness?.removeFromParent()
        darkness = nil
        if spec.dark {
            let dark = SKSpriteNode(texture: Art.darkness, size: CGSize(width: 2600, height: 2600))
            dark.zPosition = 940
            cam.addChild(dark)
            darkness = dark
        }
    }

    private func makeWeather(_ kind: Weather) -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleBlendMode = .alpha
        e.particleColorBlendFactor = 1
        e.particleRotationRange = .pi * 2
        switch kind {
        case .petals:
            e.particleTexture = Art.emoji("🌸", size: 24)
            e.particleColorBlendFactor = 0
            e.particleBirthRate = 1.6
            e.particleLifetime = 10
            e.particleSize = CGSize(width: 11, height: 11)
            e.particleScaleRange = 0.5
            e.particleSpeed = 22
            e.emissionAngle = -.pi / 2.4
            e.emissionAngleRange = 0.6
            e.xAcceleration = 4
            e.particleRotationSpeed = 1.2
            e.particleAlpha = 0.85
            e.particleAlphaSpeed = -0.06
        case .leaves:
            e.particleTexture = Art.emoji("🍂", size: 24)
            e.particleColorBlendFactor = 0
            e.particleBirthRate = 1.4
            e.particleLifetime = 9
            e.particleSize = CGSize(width: 12, height: 12)
            e.particleScaleRange = 0.4
            e.particleSpeed = 30
            e.emissionAngle = -.pi / 3
            e.emissionAngleRange = 0.5
            e.particleRotationSpeed = 1.5
            e.particleAlpha = 0.85
            e.particleAlphaSpeed = -0.07
        case .pollen:
            e.particleTexture = Art.dot
            e.particleColor = UIColor(red: 1, green: 0.97, blue: 0.7, alpha: 1)
            e.particleBlendMode = .add
            e.particleBirthRate = 7
            e.particleLifetime = 7
            e.particleSize = CGSize(width: 4, height: 4)
            e.particleScaleRange = 0.6
            e.particleSpeed = 9
            e.emissionAngleRange = .pi * 2
            e.particleAlpha = 0.45
            e.particleAlphaRange = 0.3
            e.particleAlphaSpeed = -0.05
        case .fireflies:
            e.particleTexture = Art.glow
            e.particleColor = UIColor(red: 0.85, green: 1, blue: 0.35, alpha: 1)
            e.particleBlendMode = .add
            e.particleBirthRate = 5
            e.particleLifetime = 6
            e.particleSize = CGSize(width: 14, height: 14)
            e.particleScaleRange = 0.5
            e.particleSpeed = 14
            e.emissionAngleRange = .pi * 2
            e.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 0.9, 0.2, 0.9, 0] as [NSNumber],
                                                         times: [0, 0.2, 0.5, 0.75, 1] as [NSNumber])
        case .sand:
            e.particleTexture = Art.dot
            e.particleColor = UIColor(red: 0.95, green: 0.85, blue: 0.6, alpha: 1)
            e.particleBirthRate = 22
            e.particleLifetime = 4
            e.particleSize = CGSize(width: 3, height: 3)
            e.particleScaleRange = 0.5
            e.particleSpeed = 110
            e.particleSpeedRange = 50
            e.emissionAngle = 0.1
            e.emissionAngleRange = 0.2
            e.particleAlpha = 0.5
            e.particleAlphaRange = 0.3
        case .snow:
            e.particleTexture = Art.dot
            e.particleColor = .white
            e.particleBirthRate = 16
            e.particleLifetime = 10
            e.particleSize = CGSize(width: 6, height: 6)
            e.particleScaleRange = 0.7
            e.particleSpeed = 36
            e.particleSpeedRange = 14
            e.emissionAngle = -.pi / 2
            e.emissionAngleRange = 0.35
            e.xAcceleration = 3
            e.particleAlpha = 0.9
            e.particleAlphaRange = 0.2
        case .motes:
            e.particleTexture = Art.spark
            e.particleColor = UIColor(red: 0.7, green: 0.6, blue: 1, alpha: 1)
            e.particleColorSequence = nil
            e.particleBlendMode = .add
            e.particleBirthRate = 5
            e.particleLifetime = 6
            e.particleSize = CGSize(width: 9, height: 9)
            e.particleScaleRange = 0.5
            e.particleSpeed = 8
            e.emissionAngleRange = .pi * 2
            e.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 0.9, 0] as [NSNumber], times: [0, 0.5, 1] as [NSNumber])
        case .spray:
            e.particleTexture = Art.spark
            e.particleColor = .white
            e.particleBlendMode = .add
            e.particleBirthRate = 3
            e.particleLifetime = 3
            e.particleSize = CGSize(width: 10, height: 10)
            e.particleScaleRange = 0.5
            e.particleSpeed = 4
            e.emissionAngleRange = .pi * 2
            e.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 0.8, 0] as [NSNumber], times: [0, 0.4, 1] as [NSNumber])
        case .embers:
            e.particleTexture = Art.glow
            e.particleColor = UIColor(red: 1, green: 0.55, blue: 0.15, alpha: 1)
            e.particleBlendMode = .add
            e.particleBirthRate = 14
            e.particleLifetime = 5
            e.particleSize = CGSize(width: 9, height: 9)
            e.particleScaleRange = 0.6
            e.particleSpeed = 46
            e.particleSpeedRange = 20
            e.emissionAngle = .pi / 2
            e.emissionAngleRange = 0.5
            e.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 1, 0.6, 0] as [NSNumber], times: [0, 0.15, 0.6, 1] as [NSNumber])
        case .stars:
            e.particleTexture = Art.spark
            e.particleColor = UIColor(red: 1, green: 0.95, blue: 0.7, alpha: 1)
            e.particleBlendMode = .add
            e.particleBirthRate = 6
            e.particleLifetime = 4
            e.particleSize = CGSize(width: 12, height: 12)
            e.particleScaleRange = 0.6
            e.particleSpeed = 6
            e.emissionAngleRange = .pi * 2
            e.particleRotationSpeed = 1
            e.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 1, 0] as [NSNumber], times: [0, 0.5, 1] as [NSNumber])
        }
        return e
    }

    private func buildBase() {
        let base = spec.basePoint
        let radius = CGFloat(game.stats.depositRadius)
        let zone = SKShapeNode(circleOfRadius: radius)
        zone.position = base
        zone.fillColor = UIColor.white.withAlphaComponent(0.07)
        zone.strokeColor = .clear
        zone.zPosition = 2
        zone.name = "depositZone"
        world.addChild(zone)
        let dashed = SKShapeNode(path: CGPath(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2), transform: nil)
            .copy(dashingWithPhase: 0, lengths: [14, 10]))
        dashed.strokeColor = UIColor.white.withAlphaComponent(0.5)
        dashed.lineWidth = 3
        dashed.position = base
        dashed.zPosition = 2
        dashed.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 30)))
        world.addChild(dashed)

        houseCenter = CGPoint(x: base.x - 34, y: base.y + 18)
        let houseShadow = shadowSprite(90)
        houseShadow.position = houseCenter
        houseShadow.zPosition = 3
        world.addChild(houseShadow)
        let house = SKSpriteNode(texture: Art.emoji("🏡", size: 96), size: CGSize(width: 86, height: 86))
        house.anchorPoint = CGPoint(x: 0.5, y: 0.12)
        house.position = CGPoint(x: houseCenter.x, y: houseCenter.y - 6)
        house.zPosition = zFor(houseCenter.y)
        world.addChild(house)
        let smoke = SKSpriteNode(texture: Art.puff, size: CGSize(width: 18, height: 18))
        smoke.position = CGPoint(x: houseCenter.x + 18, y: houseCenter.y + 78)
        smoke.zPosition = 300
        smoke.alpha = 0
        smoke.run(.repeatForever(.sequence([
            .group([.fadeAlpha(to: 0.5, duration: 0.3), .scale(to: 1, duration: 0.3)]),
            .group([.moveBy(x: 14, y: 40, duration: 2), .fadeOut(withDuration: 2), .scale(to: 2.4, duration: 2)]),
            .moveBy(x: -14, y: -40, duration: 0),
            .scale(to: 0.6, duration: 0),
            .wait(forDuration: 0.3)
        ])))
        world.addChild(smoke)

        chest = SKNode()
        chest.position = CGPoint(x: base.x + 40, y: base.y - 6)
        chest.zPosition = zFor(chest.position.y)
        chest.addChild(shadowSprite(40))
        let box = SKSpriteNode(texture: Art.emoji("📦", size: 56), size: CGSize(width: 40, height: 40))
        box.anchorPoint = CGPoint(x: 0.5, y: 0.1)
        chest.addChild(box)
        let title = SKLabelNode()
        title.attributedText = NSAttributedString(string: "Склад", attributes: [
            .font: UIFont.systemFont(ofSize: 13, weight: .heavy),
            .foregroundColor: UIColor.white,
            .strokeColor: UIColor.black.withAlphaComponent(0.6),
            .strokeWidth: -4
        ])
        title.position = CGPoint(x: 0, y: 46)
        chest.addChild(bobbing(title, height: 3, duration: 1.2))
        world.addChild(chest)
    }

    // MARK: Цикл

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? 1.0 / 60 : min(currentTime - lastTime, 1.0 / 20)
        lastTime = currentTime

        if !transitioning && loaded != game.save.current {
            transition(to: game.save.current)
        }

        let stats = game.stats
        syncCompanions()
        if !transitioning {
            movePlayer(dt, stats)
            gather(dt, stats)
            checkBase(dt, stats)
            checkTreasure()
        }
        for spot in spots where spot.tick(dt) {
            if distance(spot.position, player.position) < 500 {
                Effects.scatter(Art.spark, count: 4, at: CGPoint(x: spot.position.x, y: spot.position.y + 20), in: world,
                                size: 10, color: .white, spread: 26, rise: 16, additive: true, duration: 0.5)
            }
        }
        updateLoot(dt)
        updateCompanions(dt, stats)
        updateProducers(dt, stats)
        updateWild(dt, stats)
        updateTreasure(dt, stats)
        updateAmbient(dt)
        updateCamera(dt)
        updateArrows()

        saveTimer += dt
        if saveTimer > 5 {
            saveTimer = 0
            game.saveIfNeeded()
        }
    }

    private func transition(to id: LocationID) {
        transitioning = true
        touch = nil
        joystick.end()
        fader.removeAllActions()
        let fadeIn = SKAction.fadeAlpha(to: 1, duration: 0.3)
        fadeIn.timingMode = .easeIn
        let fadeOut = SKAction.fadeAlpha(to: 0, duration: 0.45)
        fadeOut.timingMode = .easeOut
        fader.run(.sequence([
            fadeIn,
            .run { [weak self] in self?.build(id) },
            .wait(forDuration: 0.1),
            fadeOut,
            .run { [weak self] in self?.transitioning = false }
        ]))
    }

    // MARK: Движение

    private func movePlayer(_ dt: Double, _ stats: Stats) {
        let v = joystick.vector
        let maxSpeed = CGFloat(stats.speed)
        let target = CGVector(dx: v.dx * maxSpeed, dy: v.dy * maxSpeed)
        let accel = CGFloat(1 - exp(-dt * (hypot(v.dx, v.dy) > 0.05 ? 12 : 16)))
        velocity.dx += (target.dx - velocity.dx) * accel
        velocity.dy += (target.dy - velocity.dy) * accel
        let speed = hypot(velocity.dx, velocity.dy)
        if speed < 2 { velocity = .zero }

        if speed > 0 {
            var p = player.position
            p.x += velocity.dx * CGFloat(dt)
            p.y += velocity.dy * CGFloat(dt)
            let resolved = resolve(p, radius: playerRadius)
            // Если упёрлись в препятствие, гасим скорость, чтобы не дрожать.
            if distance(resolved, p) > 0.5 {
                velocity.dx = (resolved.x - player.position.x) / CGFloat(dt)
                velocity.dy = (resolved.y - player.position.y) / CGFloat(dt)
            }
            player.position = resolved
        }
        let ratio = min(1, speed / max(1, maxSpeed))
        player.animate(velocity: velocity, speedRatio: ratio, dt: dt)
        player.zPosition = zFor(player.position.y)

        dustTimer -= dt
        if ratio > 0.55 && dustTimer <= 0 {
            dustTimer = 0.17
            let dustColor = spec.dark ? UIColor(white: 0.7, alpha: 1) : spec.path
            Effects.puff(at: CGPoint(x: player.position.x - velocity.dx * 0.04, y: player.position.y + 2), in: world,
                         color: dustColor, size: 18, z: player.zPosition - 0.5)
        }
    }

    private func push(_ p: CGPoint, from center: CGPoint, minDistance: CGFloat) -> CGPoint {
        let d = distance(p, center)
        guard d < minDistance else { return p }
        if d < 0.01 { return CGPoint(x: center.x, y: center.y - minDistance) }
        let k = minDistance / d
        return CGPoint(x: center.x + (p.x - center.x) * k, y: center.y + (p.y - center.y) * k)
    }

    private func resolve(_ point: CGPoint, radius: CGFloat) -> CGPoint {
        var p = point
        for pond in ponds {
            p = push(p, from: pond.center, minDistance: pond.radius + radius)
        }
        for spot in spots where spot.isSolid {
            if abs(spot.position.x - p.x) > 60 || abs(spot.position.y - p.y) > 60 { continue }
            p = push(p, from: spot.position, minDistance: spot.spec.radius + radius)
        }
        p = push(p, from: houseCenter, minDistance: 30 + radius)
        p.x = max(28, min(spec.size.width - 28, p.x))
        p.y = max(28, min(spec.size.height - 28, p.y))
        return p
    }

    private func clampedCamera(_ target: CGPoint) -> CGPoint {
        let halfW = size.width / 2
        let halfH = size.height / 2
        var p = target
        if spec.size.width > size.width {
            p.x = max(halfW - 40, min(spec.size.width - halfW + 40, p.x))
        } else {
            p.x = spec.size.width / 2
        }
        if spec.size.height > size.height {
            p.y = max(halfH - 60, min(spec.size.height - halfH + 60, p.y))
        } else {
            p.y = spec.size.height / 2
        }
        return p
    }

    private func updateCamera(_ dt: Double) {
        let lookahead = CGPoint(x: player.position.x + velocity.dx * 0.25, y: player.position.y + velocity.dy * 0.25)
        let target = clampedCamera(lookahead)
        let k = CGFloat(1 - exp(-dt * 5.5))
        var p = CGPoint(x: cam.position.x + (target.x - cam.position.x) * k,
                        y: cam.position.y + (target.y - cam.position.y) * k)
        if shake > 0.1 {
            p.x += CGFloat.random(in: -shake...shake)
            p.y += CGFloat.random(in: -shake...shake)
            shake *= CGFloat(exp(-dt * 14))
        } else {
            shake = 0
        }
        cam.position = p
    }

    // MARK: Добыча

    private func gather(_ dt: Double, _ stats: Stats) {
        hitTimer -= dt
        hintTimer -= dt
        let full = !stats.autoDeposit && game.backpackFree <= 0
        game.setBackpackFull(full)
        guard hitTimer <= 0 else { return }

        var best: ResourceSpot?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        var locked: ResourceSpot?
        var lockedDistance = CGFloat.greatestFiniteMagnitude
        let reach = CGFloat(stats.reach)
        for spot in spots where spot.alive {
            if abs(spot.position.x - player.position.x) > 140 || abs(spot.position.y - player.position.y) > 140 { continue }
            let d = distance(spot.position, player.position) - spot.spec.radius
            guard d <= reach else { continue }
            if game.canHarvest(spot.spec) {
                if d < bestDistance { best = spot; bestDistance = d }
            } else if d < lockedDistance {
                locked = spot
                lockedDistance = d
            }
        }

        if let target = best {
            if full {
                if hintTimer <= 0 {
                    hintTimer = 2.5
                    Effects.text("Рюкзак полон! Неси на склад", at: CGPoint(x: player.position.x, y: player.position.y + 70),
                                 in: world, color: UIColor(red: 1, green: 0.45, blue: 0.4, alpha: 1), size: 15)
                }
                return
            }
            strike(target, stats)
            hitTimer = stats.hitInterval
        } else if let spot = locked, hintTimer <= 0 {
            hintTimer = 2.5
            Effects.text("Нужен \(spot.spec.tool.emoji) ур. \(spot.spec.tier)",
                         at: CGPoint(x: spot.position.x, y: spot.position.y + spot.spec.barHeight + 10),
                         in: world, color: UIColor(red: 1, green: 0.85, blue: 0.4, alpha: 1), size: 15)
        }
    }

    private func strike(_ spot: ResourceSpot, _ stats: Stats) {
        player.swing(spot.spec.tool, toward: spot.position)
        hitOnce(spot, stats)
        if spot.alive && Double.random(in: 0..<1) < stats.doubleStrikeChance {
            run(.sequence([.wait(forDuration: 0.12), .run { [weak self, weak spot] in
                guard let self, let spot, spot.alive else { return }
                Effects.text("x2 удар", at: CGPoint(x: spot.position.x - 20, y: spot.position.y + 56), in: self.world,
                             color: UIColor(red: 0.8, green: 0.9, blue: 1, alpha: 1), size: 13)
                self.hitOnce(spot, self.game.stats)
            }]))
        }
    }

    private func hitOnce(_ spot: ResourceSpot, _ stats: Stats) {
        var damage = game.damage(against: spot.spec)
        var crit = false
        if Double.random(in: 0..<1) < stats.critChance {
            damage *= stats.critMult
            crit = true
        }
        if Double.random(in: 0..<1) < stats.shatterChance {
            damage = max(damage, spot.hp)
            Effects.text("Раскол!", at: CGPoint(x: spot.position.x, y: spot.position.y + 46), in: world,
                         color: UIColor(red: 0.6, green: 0.9, blue: 1, alpha: 1), size: 16)
        }
        if crit {
            shake = max(shake, 5)
            Effects.text("Крит!", at: CGPoint(x: spot.position.x + 18, y: spot.position.y + 52), in: world,
                         color: UIColor(red: 1, green: 0.6, blue: 0.2, alpha: 1), size: 17)
            heavyHaptic.impactOccurred(intensity: 0.7)
        }
        apply(damage, to: spot, byHelper: false, strong: crit)
        if stats.quake {
            var shook = false
            for other in spots where other !== spot && other.alive && game.canHarvest(other.spec) {
                if distance(other.position, spot.position) < CGFloat(stats.quakeRadius) {
                    apply(damage * stats.quakePower, to: other, byHelper: false, strong: false)
                    shook = true
                }
            }
            if shook {
                Effects.ring(at: CGPoint(x: spot.position.x, y: spot.position.y + 6), in: world,
                             color: UIColor.white.withAlphaComponent(0.6), radius: CGFloat(stats.quakeRadius) * 0.7)
            }
        }
    }

    private func apply(_ damage: Double, to spot: ResourceSpot, byHelper: Bool, strong: Bool) {
        guard spot.alive else { return }
        spot.hp -= damage
        let stats = game.stats
        if stats.executeThreshold > 0 && spot.hp > 0 && spot.hp < spot.spec.hp * stats.executeThreshold {
            spot.hp = 0
        }
        spot.playHit(strong: strong)
        Effects.chips(at: spot.position, color: spot.spec.chip, in: world, count: byHelper ? 3 : (strong ? 8 : 5))
        if spot.hp <= 0.0001 {
            harvest(spot, byHelper: byHelper)
        } else {
            spot.showHP()
        }
    }

    private func harvest(_ spot: ResourceSpot, byHelper: Bool) {
        let stats = game.stats
        let roll = Double.random(in: 0..<1)
        let multiplier = roll < stats.tripleChance ? 3 : (roll < stats.tripleChance + stats.doubleChance ? 2 : 1)
        var gained: [(ResourceKind, Int)] = []
        for y in spot.spec.yields {
            guard Double.random(in: 0..<1) < y.chance else { continue }
            var raw = Double(Int.random(in: y.min...y.max)) * stats.yieldMultiplier(for: y.kind)
            if byHelper { raw *= stats.helperYield }
            var n = Int(raw)
            if Double.random(in: 0..<1) < raw - Double(n) { n += 1 }
            n *= multiplier
            if n > 0 { gained.append((y.kind, n)) }
        }
        if spot.spec.tool == .pickaxe && Double.random(in: 0..<1) < stats.gemChance {
            gained.append((.diamond, 1))
        }
        if Double.random(in: 0..<1) < stats.finderChance, let found = spec.resources.randomElement() {
            gained.append((found, Int.random(in: 1...3)))
        }

        var shown: [(ResourceKind, Int)] = []
        for (kind, n) in gained {
            let added = byHelper ? game.addToStorage(kind, n) : game.addToBackpack(kind, n)
            if added > 0 { shown.append((kind, added)) }
        }
        let coins = game.registerHarvest(xp: spot.spec.xp)

        let top = CGPoint(x: spot.position.x, y: spot.position.y + min(70, spot.spec.barHeight))
        for (i, item) in shown.enumerated() {
            Effects.gain(item.0, item.1, at: CGPoint(x: top.x, y: top.y + CGFloat(i) * 24), in: world,
                         delay: Double(i) * 0.1, small: byHelper)
            if !byHelper { spawnLoot(item.0, count: min(item.1, 4), from: top) }
        }
        if !byHelper && shown.isEmpty && !gained.isEmpty {
            Effects.text("Рюкзак полон!", at: top, in: world, color: UIColor(red: 1, green: 0.45, blue: 0.4, alpha: 1), size: 15)
        }
        if multiplier > 1 && !shown.isEmpty {
            Effects.text("x\(multiplier)!", at: CGPoint(x: top.x - 36, y: top.y + 6), in: world,
                         color: UIColor(red: 0.5, green: 1, blue: 0.5, alpha: 1), size: 18)
        }
        if coins > 0 {
            Effects.text("+\(coins) 🪙", at: CGPoint(x: top.x + 38, y: top.y - 4), in: world,
                         color: UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1), size: 14, delay: 0.15)
        }

        let regrow = Double.random(in: 0..<1) < stats.regrowChance
        let from = byHelper ? (companions.first(where: { $0.target === spot })?.position ?? player.position) : player.position
        spot.deplete(respawnIn: regrow ? 1.2 : spot.spec.respawn * stats.respawnMult, from: from)
        depletionEffects(spot)
        if !byHelper { haptic.impactOccurred(intensity: 0.6) }
    }

    private func depletionEffects(_ spot: ResourceSpot) {
        let p = spot.position
        switch spot.style {
        case .fall:
            let leaf = spot.spec.type == .ashTree ? "🔥" : (spot.spec.type == .snowPine ? "❄️" : "🍃")
            run(.sequence([.wait(forDuration: 0.42), .run { [weak self] in
                guard let self else { return }
                let side: CGFloat = spot.position.x >= self.player.position.x ? 30 : -30
                Effects.scatter(Art.emoji(leaf, size: 24), count: 6, at: CGPoint(x: p.x + side, y: p.y + 10), in: self.world,
                                size: 13, spread: 46, rise: 12)
                Effects.puff(at: CGPoint(x: p.x + side, y: p.y), in: self.world, color: self.spec.path, size: 40, z: spot.zPosition + 1)
                self.shake = max(self.shake, 2.5)
            }]))
        case .crumble:
            Effects.scatter(Art.dot, count: 8, at: CGPoint(x: p.x, y: p.y + 16), in: world, size: 6,
                            color: spot.spec.chip, spread: 44, rise: 20)
            Effects.puff(at: p, in: world, color: UIColor(white: 0.8, alpha: 1), size: 46, z: spot.zPosition + 1)
        case .pop:
            Effects.scatter(Art.spark, count: 5, at: CGPoint(x: p.x, y: p.y + 14), in: world, size: 11,
                            color: .white, spread: 30, rise: 18, additive: true, duration: 0.45)
        case .splash:
            Effects.scatter(Art.dot, count: 9, at: p, in: world, size: 5, color: spot.spec.chip, spread: 30, rise: 26, duration: 0.5)
            Effects.ring(at: p, in: world, color: UIColor.white.withAlphaComponent(0.7), radius: 20)
        case .fade:
            Effects.scatter(Art.spark, count: 4, at: CGPoint(x: p.x, y: p.y + 40), in: world, size: 11,
                            color: .white, spread: 30, rise: 10, additive: true, duration: 0.45)
        }
    }

    // MARK: Добыча летит к персонажу

    private func spawnLoot(_ kind: ResourceKind, count: Int, from point: CGPoint) {
        for _ in 0..<count {
            let node = SKSpriteNode(texture: Art.iconTexture(kind), size: CGSize(width: 18, height: 18))
            node.position = CGPoint(x: point.x + CGFloat.random(in: -8...8), y: point.y - 10)
            node.zPosition = 860
            world.addChild(node)
            let a = CGFloat.random(in: 0.3...(.pi - 0.3))
            let v = CGFloat.random(in: 110...190)
            loot.append(LootFly(node: node, velocity: CGVector(dx: cos(a) * v, dy: sin(a) * v)))
        }
    }

    private func updateLoot(_ dt: Double) {
        guard !loot.isEmpty else { return }
        let target = CGPoint(x: player.position.x, y: player.position.y + 22)
        var finished = false
        for item in loot {
            item.age += dt
            let p = item.node.position
            if item.age < 0.22 {
                item.velocity.dy -= CGFloat(600 * dt)
                item.velocity.dx *= CGFloat(exp(-dt * 3))
            } else {
                let dx = target.x - p.x
                let dy = target.y - p.y
                let d = max(1, hypot(dx, dy))
                let pull = CGFloat(2400 * dt) * min(3, CGFloat(item.age) * 2)
                item.velocity.dx = item.velocity.dx * CGFloat(exp(-dt * 6)) + dx / d * pull
                item.velocity.dy = item.velocity.dy * CGFloat(exp(-dt * 6)) + dy / d * pull
                if d < 16 || item.age > 1.6 {
                    item.node.removeFromParent()
                    item.age = -1
                    finished = true
                    continue
                }
            }
            item.node.position = CGPoint(x: p.x + item.velocity.dx * CGFloat(dt), y: p.y + item.velocity.dy * CGFloat(dt))
        }
        if finished {
            loot.removeAll { $0.age < 0 }
        }
    }

    // MARK: Склад

    private func checkBase(_ dt: Double, _ stats: Stats) {
        depositCooldown -= dt
        guard depositCooldown <= 0, game.backpackCount > 0 else { return }
        guard distance(player.position, spec.basePoint) < CGFloat(stats.depositRadius) else { return }
        let kinds = ResourceKind.allCases.filter { (game.save.backpack[$0] ?? 0) > 0 }
        let moved = game.depositBackpack()
        guard moved > 0 else { return }
        depositCooldown = 0.6
        Effects.fly(kinds, from: player.position, to: chest.position, in: world)
        Effects.text("+\(moved) на склад", at: CGPoint(x: chest.position.x, y: chest.position.y + 70), in: world,
                     color: UIColor(red: 1, green: 0.9, blue: 0.5, alpha: 1), size: 16, delay: 0.3)
        chest.run(.sequence([.wait(forDuration: 0.4), .scaleX(to: 1.25, y: 0.85, duration: 0.07),
                             .scaleX(to: 0.92, y: 1.12, duration: 0.08), .scale(to: 1, duration: 0.1)]))
        run(.sequence([.wait(forDuration: 0.45), .run { [weak self] in
            guard let self else { return }
            Effects.scatter(Art.spark, count: 6, at: CGPoint(x: self.chest.position.x, y: self.chest.position.y + 30), in: self.world,
                            size: 12, color: UIColor(red: 1, green: 0.9, blue: 0.4, alpha: 1), spread: 34, rise: 24, additive: true)
        }]))
        haptic.impactOccurred(intensity: 0.9)
        game.saveNow()
    }

    // MARK: Животные

    private func syncCompanions() {
        let ids = game.save.active
        guard ids != companionSignature, loaded != nil else { return }
        companionSignature = ids
        companions.removeAll { companion in
            if !ids.contains(companion.animal) {
                Effects.burst(at: companion.position, emoji: "✨", in: world)
                companion.removeFromParent()
                return true
            }
            return false
        }
        for id in ids where !companions.contains(where: { $0.animal == id }) {
            let companion = CompanionNode(animal: id)
            companion.position = CGPoint(x: player.position.x + CGFloat.random(in: -30...30),
                                         y: player.position.y + CGFloat.random(in: -30...0))
            companion.setScale(0.2)
            let pop = SKAction.scale(to: 1, duration: 0.3)
            pop.timingMode = .easeOut
            companion.run(pop)
            world.addChild(companion)
            companions.append(companion)
            Effects.burst(at: companion.position, emoji: "✨", in: world)
        }
        companions.sort { a, b in
            (ids.firstIndex(of: a.animal) ?? 0) < (ids.firstIndex(of: b.animal) ?? 0)
        }
    }

    private func updateCompanions(_ dt: Double, _ stats: Stats) {
        var helpers: [AnimalID: Helper] = [:]
        for h in stats.helpers { helpers[h.animal] = h }
        let followSpeed = max(stats.speed * 1.05, 170)
        for (i, companion) in companions.enumerated() {
            let offset = Self.slots[i % Self.slots.count]
            let slot = CGPoint(x: player.position.x + offset.x, y: player.position.y + offset.y)
            if let helper = helpers[companion.animal], !transitioning {
                updateHelper(companion, helper, slot: slot, dt: dt, stats: stats, followSpeed: followSpeed)
            } else {
                companion.move(toward: slot, dt: dt, speed: followSpeed)
            }
            companion.zPosition = zFor(companion.position.y)
        }
    }

    private func updateHelper(_ c: CompanionNode, _ helper: Helper, slot: CGPoint, dt: Double, stats: Stats, followSpeed: Double) {
        let range = CGFloat(stats.helperRange)
        let maxTier = helper.spec.maxTier + stats.helperTierBonus
        if let t = c.target, !t.alive || distance(t.position, player.position) > range + 70 {
            c.target = nil
        }
        if c.target == nil {
            c.retargetTimer -= dt
            if c.retargetTimer <= 0 {
                c.retargetTimer = 0.4
                var best: ResourceSpot?
                var bestDistance = CGFloat.greatestFiniteMagnitude
                for spot in spots where spot.alive {
                    guard helper.spec.tools.contains(spot.spec.tool), spot.spec.tier <= maxTier else { continue }
                    guard distance(spot.position, player.position) < range else { continue }
                    if companions.contains(where: { $0 !== c && $0.target === spot }) { continue }
                    let d = distance(spot.position, c.position)
                    if d < bestDistance { best = spot; bestDistance = d }
                }
                c.target = best
            }
        }
        guard let target = c.target else {
            c.move(toward: slot, dt: dt, speed: followSpeed)
            return
        }
        let reach = target.spec.radius + 16
        if distance(c.position, target.position) > reach + 4 {
            c.move(toward: target.position, dt: dt, speed: max(followSpeed, 190), stopAt: reach)
        } else {
            c.move(toward: c.position, dt: dt, speed: 0)
            c.hitTimer -= dt * stats.helperSpeed
            if c.hitTimer <= 0 {
                c.hitTimer = helper.spec.interval
                c.attack(toward: target.position)
                apply(helper.damage * stats.helperMult, to: target, byHelper: true, strong: false)
                if !target.alive { c.cheer() }
            }
        }
    }

    private func updateProducers(_ dt: Double, _ stats: Stats) {
        for producer in stats.producers {
            let t = (producerTimers[producer.animal] ?? 0) + dt * stats.producerMult
            if t >= producer.interval {
                producerTimers[producer.animal] = 0
                let n = Double.random(in: 0..<1) < stats.doubleProductChance ? 2 : 1
                game.addToStorage(producer.kind, n)
                if let c = companions.first(where: { $0.animal == producer.animal }) {
                    Effects.gain(producer.kind, n, at: CGPoint(x: c.position.x, y: c.position.y + 46), in: world, small: true)
                    c.cheer()
                }
            } else {
                producerTimers[producer.animal] = t
            }
        }
    }

    // MARK: Атмосфера

    private func updateAmbient(_ dt: Double) {
        for critter in critters {
            critter.update(dt, bounds: spec.size)
            if critter.zPosition < 400 { critter.zPosition = zFor(critter.position.y) }
        }
        for shadow in cloudShadows {
            shadow.position.x += CGFloat(16 * dt)
            shadow.position.y += CGFloat(5 * dt)
            if shadow.position.x - shadow.size.width / 2 > spec.size.width {
                shadow.position.x = -shadow.size.width / 2
                shadow.position.y = CGFloat.random(in: 0...spec.size.height)
            }
            if shadow.position.y - shadow.size.height / 2 > spec.size.height {
                shadow.position.y = -shadow.size.height / 2
            }
        }
    }

    // MARK: Дикие звери

    private func randomOpenPoint(minFromPlayer: CGFloat) -> CGPoint? {
        for _ in 0..<40 {
            let p = CGPoint(x: CGFloat.random(in: 120...(spec.size.width - 120)),
                            y: CGFloat.random(in: 280...(spec.size.height - 120)))
            if distance(p, player.position) < minFromPlayer { continue }
            if ponds.contains(where: { distance(p, $0.center) < $0.radius + 50 }) { continue }
            if spots.contains(where: { distance(p, $0.position) < 50 }) { continue }
            return p
        }
        return nil
    }

    private func updateWild(_ dt: Double, _ stats: Stats) {
        if let w = wild {
            w.wander(dt)
            w.zPosition = zFor(w.position.y)
            let d = distance(w.position, player.position)
            if d < 85 {
                game.setEncounter(Encounter(animal: w.animal))
            } else if d > 110 {
                game.setEncounter(nil)
            }
            if w.life <= 0 {
                w.leave()
                wild = nil
                game.setEncounter(nil)
            }
            return
        }
        guard !transitioning else { return }
        wildTimer -= dt * stats.spawnMult
        if wildTimer <= 0 {
            wildTimer = Double.random(in: 45...80)
            spawnWild(stats)
        }
    }

    private func spawnWild(_ stats: Stats) {
        let candidates = spec.wild.filter { game.stars($0) < AnimalSpec.maxStars }
        guard !candidates.isEmpty else { return }
        var weights: [Double] = candidates.map { id in
            if case .wild(_, _, let weight) = id.spec.source { return weight }
            return 1
        }
        for (i, id) in candidates.enumerated() where game.stars(id) == 0 { weights[i] *= 1.6 }
        let total = weights.reduce(0, +)
        var roll = Double.random(in: 0..<total)
        var chosen = candidates[0]
        for (i, id) in candidates.enumerated() {
            roll -= weights[i]
            if roll <= 0 { chosen = id; break }
        }
        guard let point = randomOpenPoint(minFromPlayer: 260) else { return }
        let node = WildNode(animal: chosen, at: point, life: 160 * stats.spawnMult)
        node.zPosition = zFor(point.y)
        world.addChild(node)
        wild = node
        game.toast(chosen.spec.emoji, "Рядом бродит дикий зверь: \(chosen.spec.name). Иди по стрелке")
    }

    /// Вызывается из интерфейса кнопкой "Приручить".
    func tameNearby() {
        guard let w = wild, game.tame(w.animal) else { return }
        Effects.hearts(at: w.position, in: world)
        Effects.ring(at: w.position, in: world, color: UIColor(red: 1, green: 0.5, blue: 0.7, alpha: 1), radius: 34)
        w.removeFromParent()
        wild = nil
        game.setEncounter(nil)
        player.celebrate()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: Клады

    private func updateTreasure(_ dt: Double, _ stats: Stats) {
        if let t = treasure {
            t.life -= dt
            t.zPosition = zFor(t.position.y)
            if t.life <= 0 {
                t.run(.sequence([.group([.fadeOut(withDuration: 0.4), .scale(to: 0.3, duration: 0.4)]), .removeFromParent()]))
                treasure = nil
            }
            return
        }
        guard !transitioning else { return }
        treasureTimer -= dt * stats.spawnMult
        if treasureTimer <= 0 {
            treasureTimer = Double.random(in: 60...110)
            guard let point = randomOpenPoint(minFromPlayer: 300) else { return }
            let node = TreasureNode(at: point, life: 120)
            node.zPosition = zFor(point.y)
            world.addChild(node)
            treasure = node
            game.toast("🎁", "Где-то появился клад! Иди по жёлтой стрелке")
        }
    }

    private func checkTreasure() {
        guard let t = treasure, distance(t.position, player.position) < 46 else { return }
        treasure = nil
        let reward = game.openTreasure()
        let p = t.position
        Effects.scatter(Art.emoji("🪙", size: 32), count: 10, at: CGPoint(x: p.x, y: p.y + 20), in: world, size: 18, spread: 60, rise: 40, duration: 0.8)
        Effects.scatter(Art.spark, count: 8, at: CGPoint(x: p.x, y: p.y + 24), in: world, size: 14,
                        color: UIColor(red: 1, green: 0.9, blue: 0.4, alpha: 1), spread: 50, rise: 30, additive: true)
        Effects.ring(at: p, in: world, color: UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1), radius: 40)
        Effects.text("+\(reward.coins) 🪙", at: CGPoint(x: p.x, y: p.y + 60), in: world,
                     color: UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1), size: 18)
        t.run(.sequence([.scale(to: 1.4, duration: 0.12), .group([.fadeOut(withDuration: 0.2), .scale(to: 0.2, duration: 0.2)]), .removeFromParent()]))
        shake = max(shake, 4)
        player.celebrate()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: Стрелки

    private func updateArrows() {
        let capacity = Double(game.stats.capacity)
        let wantBase = game.backpackFull || (game.backpackCount > 0 && Double(game.backpackCount) >= capacity * 0.85)
        place(baseArrow, target: wantBase ? spec.basePoint : nil)
        place(wildArrow, target: wild?.position)
        place(treasureArrow, target: treasure?.position)
        darkness?.position = CGPoint(x: player.position.x - cam.position.x, y: player.position.y + 20 - cam.position.y)
    }

    private func place(_ arrow: PointerArrow, target: CGPoint?) {
        guard let target else {
            arrow.isHidden = true
            return
        }
        let halfW = size.width / 2
        let halfH = size.height / 2
        let rel = CGPoint(x: target.x - cam.position.x, y: target.y - cam.position.y)
        if abs(rel.x) < halfW - 20 && rel.y < halfH - 150 && rel.y > -halfH + 170 {
            arrow.isHidden = true
            return
        }
        let insetX = halfW - 36
        let insetTop = halfH - 150
        let insetBottom = halfH - 170
        let sx = insetX / max(abs(rel.x), 0.001)
        let sy = (rel.y > 0 ? insetTop : insetBottom) / max(abs(rel.y), 0.001)
        let k = min(sx, sy, 1)
        arrow.position = CGPoint(x: rel.x * k, y: rel.y * k)
        arrow.point(atan2(rel.y, rel.x))
        arrow.isHidden = false
    }

    // MARK: Касания: плавающий джойстик в любом месте экрана

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard touch == nil, !transitioning, let t = touches.first else { return }
        touch = t
        joystick.begin(at: t.location(in: cam))
        if !game.save.tutorialDone { game.finishTutorial() }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touch, touches.contains(t) else { return }
        joystick.move(to: t.location(in: cam))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touch, touches.contains(t) else { return }
        touch = nil
        joystick.end()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }
}
