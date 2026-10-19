import SpriteKit
import UIKit

final class GameScene: SKScene {
    private let game = GameState.shared

    private let world = SKNode()
    private let cam = SKCameraNode()
    private let player = PlayerNode()
    private let joystick = Joystick()
    private let fader = SKSpriteNode(color: .black, size: CGSize(width: 5000, height: 5000))
    private let baseArrow = PointerArrow(color: UIColor(red: 1, green: 0.78, blue: 0.2, alpha: 1), icon: "📦")
    private let wildArrow = PointerArrow(color: UIColor(red: 0.95, green: 0.4, blue: 0.6, alpha: 1), icon: "🐾")
    private var darkness: SKSpriteNode?

    private var spec: LocationSpec = LocationID.meadow.spec
    private var loaded: LocationID?
    private var spots: [ResourceSpot] = []
    private var ponds: [(center: CGPoint, radius: CGFloat)] = []
    private var companions: [CompanionNode] = []
    private var companionSignature: [AnimalID] = []
    private var wild: WildNode?
    private var chest = SKNode()
    private var houseCenter = CGPoint.zero

    private var lastTime: TimeInterval = 0
    private var hitTimer: Double = 0
    private var hintTimer: Double = 0
    private var wildTimer: Double = 20
    private var saveTimer: Double = 0
    private var depositCooldown: Double = 0
    private var producerTimers: [AnimalID: Double] = [:]
    private var transitioning = false
    private var touch: UITouch?
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    private static let slots: [CGPoint] = [
        CGPoint(x: -38, y: -26), CGPoint(x: 38, y: -26), CGPoint(x: -64, y: 8), CGPoint(x: 64, y: 8), CGPoint(x: 0, y: -52)
    ]
    private let playerRadius: CGFloat = 13
    private let depositRadius: CGFloat = 92

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
        baseArrow.zPosition = 960
        wildArrow.zPosition = 960
        cam.addChild(baseArrow)
        cam.addChild(wildArrow)
        fader.zPosition = 2000
        fader.alpha = 0
        cam.addChild(fader)
        build(game.save.current)
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
        wild = nil
        wildArrow.isHidden = true
        game.setEncounter(nil)
        backgroundColor = spec.patches.last ?? spec.ground

        let placements = WorldLayout.spots(spec)
        let ground = SKSpriteNode(texture: SKTexture(image: WorldArt.ground(spec, spots: placements)), size: spec.size)
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
        for pond in spec.ponds where !pond.frozen {
            let c = spec.point(pond.x, pond.y)
            for i in 0..<3 {
                let a = CGFloat(i) * 2.1 + 0.4
                let lily = SKSpriteNode(texture: Art.emoji(i == 0 ? "🪷" : "🍃", size: 32), size: CGSize(width: 22, height: 22))
                lily.position = CGPoint(x: c.x + cos(a) * pond.radius * 0.55, y: c.y + sin(a) * pond.radius * 0.5)
                lily.zPosition = 2
                lily.run(.repeatForever(.sequence([.rotate(byAngle: 0.15, duration: 2), .rotate(byAngle: -0.15, duration: 2)])))
                world.addChild(lily)
            }
        }

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
        world.addChild(player)
        syncCompanions()

        darkness?.removeFromParent()
        darkness = nil
        if spec.dark {
            let dark = SKSpriteNode(texture: Art.darkness, size: CGSize(width: 2600, height: 2600))
            dark.zPosition = 940
            cam.addChild(dark)
            darkness = dark
        }

        cam.position = clampedCamera(player.position)
        wildTimer = 18
    }

    private func buildBase() {
        let base = spec.basePoint
        let zone = SKShapeNode(circleOfRadius: depositRadius)
        zone.position = base
        zone.fillColor = UIColor.white.withAlphaComponent(0.08)
        zone.strokeColor = .clear
        zone.zPosition = 2
        world.addChild(zone)
        let dashed = SKShapeNode(path: CGPath(ellipseIn: CGRect(x: -depositRadius, y: -depositRadius, width: depositRadius * 2, height: depositRadius * 2), transform: nil)
            .copy(dashingWithPhase: 0, lengths: [14, 10]))
        dashed.strokeColor = UIColor.white.withAlphaComponent(0.55)
        dashed.lineWidth = 3
        dashed.position = base
        dashed.zPosition = 2
        dashed.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 30)))
        world.addChild(dashed)

        houseCenter = CGPoint(x: base.x - 34, y: base.y + 18)
        let house = SKSpriteNode(texture: Art.emoji("🏡", size: 96), size: CGSize(width: 86, height: 86))
        house.position = CGPoint(x: houseCenter.x, y: houseCenter.y + 26)
        house.zPosition = zFor(houseCenter.y)
        world.addChild(house)

        chest = SKNode()
        chest.position = CGPoint(x: base.x + 40, y: base.y - 6)
        chest.zPosition = zFor(chest.position.y)
        let box = SKSpriteNode(texture: Art.emoji("📦", size: 56), size: CGSize(width: 40, height: 40))
        box.position = CGPoint(x: 0, y: 16)
        chest.addChild(box)
        let title = SKLabelNode()
        title.attributedText = NSAttributedString(string: "Склад", attributes: [
            .font: UIFont.systemFont(ofSize: 13, weight: .heavy),
            .foregroundColor: UIColor.white,
            .strokeColor: UIColor.black.withAlphaComponent(0.6),
            .strokeWidth: -4
        ])
        title.position = CGPoint(x: 0, y: 42)
        chest.addChild(title)
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
            checkBase(dt)
        }
        for spot in spots { spot.tick(dt) }
        updateCompanions(dt, stats)
        updateProducers(dt, stats)
        updateWild(dt, stats)
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
        fader.run(.sequence([
            .fadeAlpha(to: 1, duration: 0.25),
            .run { [weak self] in self?.build(id) },
            .wait(forDuration: 0.1),
            .fadeAlpha(to: 0, duration: 0.35),
            .run { [weak self] in self?.transitioning = false }
        ]))
    }

    // MARK: Движение

    private func movePlayer(_ dt: Double, _ stats: Stats) {
        let v = joystick.vector
        let strength = hypot(v.dx, v.dy)
        if strength > 0.08 {
            let speed = CGFloat(stats.speed * dt)
            var p = player.position
            p.x += v.dx * speed
            p.y += v.dy * speed
            player.position = resolve(p, radius: playerRadius)
            player.animate(walking: true, dx: v.dx, dt: dt)
        } else {
            player.animate(walking: false, dx: 0, dt: dt)
        }
        player.zPosition = zFor(player.position.y)
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
        let target = clampedCamera(player.position)
        let k = CGFloat(min(1, dt * 7))
        cam.position = CGPoint(x: cam.position.x + (target.x - cam.position.x) * k,
                               y: cam.position.y + (target.y - cam.position.y) * k)
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
            if abs(spot.position.x - player.position.x) > 120 || abs(spot.position.y - player.position.y) > 120 { continue }
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
        player.swing(spot.spec.tool, toward: spot.position)
        if crit {
            Effects.text("Крит!", at: CGPoint(x: spot.position.x + 18, y: spot.position.y + 52), in: world,
                         color: UIColor(red: 1, green: 0.6, blue: 0.2, alpha: 1), size: 16)
        }
        apply(damage, to: spot, byHelper: false)
        if stats.quake {
            for other in spots where other !== spot && other.alive && game.canHarvest(other.spec) {
                if distance(other.position, spot.position) < 110 {
                    apply(damage * 0.4, to: other, byHelper: false)
                }
            }
        }
    }

    private func apply(_ damage: Double, to spot: ResourceSpot, byHelper: Bool) {
        guard spot.alive else { return }
        spot.hp -= damage
        spot.playHit()
        Effects.chips(at: spot.position, color: spot.spec.chip, in: world, count: byHelper ? 3 : 5)
        if spot.hp <= 0.0001 {
            harvest(spot, byHelper: byHelper)
        } else {
            spot.showHP()
        }
    }

    private func harvest(_ spot: ResourceSpot, byHelper: Bool) {
        let stats = game.stats
        let doubled = Double.random(in: 0..<1) < stats.doubleChance
        var gained: [(ResourceKind, Int)] = []
        for y in spot.spec.yields {
            guard Double.random(in: 0..<1) < y.chance else { continue }
            let raw = Double(Int.random(in: y.min...y.max)) * stats.yieldMultiplier(for: y.kind)
            var n = Int(raw)
            if Double.random(in: 0..<1) < raw - Double(n) { n += 1 }
            if doubled { n *= 2 }
            if n > 0 { gained.append((y.kind, n)) }
        }
        if spot.spec.tool == .pickaxe && Double.random(in: 0..<1) < stats.gemChance {
            gained.append((.diamond, 1))
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
        }
        if !byHelper && shown.isEmpty && !gained.isEmpty {
            Effects.text("Рюкзак полон!", at: top, in: world, color: UIColor(red: 1, green: 0.45, blue: 0.4, alpha: 1), size: 15)
        }
        if doubled && !shown.isEmpty {
            Effects.text("x2!", at: CGPoint(x: top.x - 34, y: top.y + 6), in: world,
                         color: UIColor(red: 0.5, green: 1, blue: 0.5, alpha: 1), size: 16)
        }
        if coins > 0 {
            Effects.text("+\(coins) 🪙", at: CGPoint(x: top.x + 36, y: top.y - 4), in: world,
                         color: UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1), size: 14, delay: 0.15)
        }

        let regrow = Double.random(in: 0..<1) < stats.regrowChance
        spot.deplete(respawnIn: regrow ? 1.2 : spot.spec.respawn * stats.respawnMult)
        if !byHelper { haptic.impactOccurred(intensity: 0.6) }
    }

    // MARK: Склад

    private func checkBase(_ dt: Double) {
        depositCooldown -= dt
        guard depositCooldown <= 0, game.backpackCount > 0 else { return }
        guard distance(player.position, spec.basePoint) < depositRadius else { return }
        let kinds = ResourceKind.allCases.filter { (game.save.backpack[$0] ?? 0) > 0 }
        let moved = game.depositBackpack()
        guard moved > 0 else { return }
        depositCooldown = 0.6
        Effects.fly(kinds, from: player.position, to: chest.position, in: world)
        Effects.text("+\(moved) на склад", at: CGPoint(x: chest.position.x, y: chest.position.y + 64), in: world,
                     color: UIColor(red: 1, green: 0.9, blue: 0.5, alpha: 1), size: 16, delay: 0.3)
        chest.run(.sequence([.wait(forDuration: 0.4), .scale(to: 1.2, duration: 0.08), .scale(to: 1, duration: 0.12)]))
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
            companion.run(.scale(to: 1, duration: 0.25))
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
        if let t = c.target, !t.alive || distance(t.position, player.position) > 330 {
            c.target = nil
        }
        if c.target == nil {
            c.retargetTimer -= dt
            if c.retargetTimer <= 0 {
                c.retargetTimer = 0.4
                var best: ResourceSpot?
                var bestDistance = CGFloat.greatestFiniteMagnitude
                for spot in spots where spot.alive {
                    guard helper.spec.tools.contains(spot.spec.tool), spot.spec.tier <= helper.spec.maxTier else { continue }
                    let fromPlayer = distance(spot.position, player.position)
                    guard fromPlayer < 260 else { continue }
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
            c.hitTimer -= dt
            if c.hitTimer <= 0 {
                c.hitTimer = helper.spec.interval
                c.attack(toward: target.position)
                apply(helper.damage * stats.helperMult, to: target, byHelper: true)
            }
        }
    }

    private func updateProducers(_ dt: Double, _ stats: Stats) {
        for producer in stats.producers {
            let t = (producerTimers[producer.animal] ?? 0) + dt * stats.producerMult
            if t >= producer.interval {
                producerTimers[producer.animal] = 0
                game.addToStorage(producer.kind, 1)
                if let c = companions.first(where: { $0.animal == producer.animal }) {
                    Effects.gain(producer.kind, 1, at: CGPoint(x: c.position.x, y: c.position.y + 44), in: world, small: true)
                }
            } else {
                producerTimers[producer.animal] = t
            }
        }
    }

    // MARK: Дикие звери

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
            spawnWild()
        }
    }

    private func spawnWild() {
        let candidates = spec.wild.filter { game.stars($0) < AnimalSpec.maxStars }
        guard !candidates.isEmpty else { return }
        var weights: [Double] = candidates.map { id in
            if case .wild(_, _, let weight) = id.spec.source { return weight }
            return 1
        }
        // Тех, кого ещё нет, показываем чаще.
        for (i, id) in candidates.enumerated() where game.stars(id) == 0 { weights[i] *= 1.6 }
        let total = weights.reduce(0, +)
        var roll = Double.random(in: 0..<total)
        var chosen = candidates[0]
        for (i, id) in candidates.enumerated() {
            roll -= weights[i]
            if roll <= 0 { chosen = id; break }
        }

        var point = CGPoint.zero
        var found = false
        for _ in 0..<40 {
            let p = CGPoint(x: CGFloat.random(in: 120...(spec.size.width - 120)),
                            y: CGFloat.random(in: 260...(spec.size.height - 120)))
            if distance(p, player.position) < 260 { continue }
            if ponds.contains(where: { distance(p, $0.center) < $0.radius + 50 }) { continue }
            if spots.contains(where: { distance(p, $0.position) < 50 }) { continue }
            point = p
            found = true
            break
        }
        guard found else { return }
        let node = WildNode(animal: chosen, at: point)
        node.zPosition = zFor(point.y)
        world.addChild(node)
        wild = node
        game.toast(chosen.spec.emoji, "Рядом бродит дикий зверь: \(chosen.spec.name). Иди по стрелке")
    }

    /// Вызывается из интерфейса кнопкой "Приручить".
    func tameNearby() {
        guard let w = wild, game.tame(w.animal) else { return }
        Effects.hearts(at: w.position, in: world)
        w.removeFromParent()
        wild = nil
        game.setEncounter(nil)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: Стрелки

    private func updateArrows() {
        let wantBase = game.backpackFull || (game.backpackCount > 0 && Double(game.backpackCount) >= Double(game.stats.capacity) * 0.85)
        place(baseArrow, target: wantBase ? spec.basePoint : nil)
        place(wildArrow, target: wild?.position)
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
