import SpriteKit
import UIKit

func sprite(_ texture: SKTexture, _ size: CGSize, _ position: CGPoint = .zero) -> SKSpriteNode {
    let node = SKSpriteNode(texture: texture, size: size)
    node.position = position
    return node
}

func emojiSprite(_ emoji: String, _ size: CGFloat, x: CGFloat = 0, y: CGFloat = 0,
                 tint: UIColor? = nil, blend: CGFloat = 0) -> SKSpriteNode {
    let node = sprite(Art.emoji(emoji, size: size), CGSize(width: size, height: size), CGPoint(x: x, y: y))
    if let tint {
        node.color = tint
        node.colorBlendFactor = blend
    }
    return node
}

func shadowSprite(_ width: CGFloat, y: CGFloat = 0) -> SKSpriteNode {
    let node = sprite(Art.shadow, CGSize(width: width, height: width * 0.36), CGPoint(x: 0, y: y))
    node.alpha = 0.22
    return node
}

func glowSprite(_ color: UIColor, size: CGFloat, y: CGFloat = 0, alpha: CGFloat = 0.5, pulse: Bool = true) -> SKSpriteNode {
    let node = sprite(Art.glow, CGSize(width: size, height: size), CGPoint(x: 0, y: y))
    node.color = color
    node.colorBlendFactor = 1
    node.alpha = alpha
    node.blendMode = .add
    if pulse {
        let a = SKAction.fadeAlpha(to: alpha * 0.5, duration: Double.random(in: 1.1...1.6))
        let b = SKAction.fadeAlpha(to: alpha, duration: Double.random(in: 1.1...1.6))
        a.timingMode = .easeInEaseOut
        b.timingMode = .easeInEaseOut
        node.run(.repeatForever(.sequence([a, b])))
    }
    return node
}

/// Дерево качается от ветра: точка вращения у основания.
func swaying(_ node: SKSpriteNode, amount: CGFloat = 0.035) -> SKSpriteNode {
    let h = node.size.height
    node.anchorPoint = CGPoint(x: 0.5, y: 0.06)
    node.position.y -= h * 0.44
    let duration = Double.random(in: 1.6...2.4)
    let a = SKAction.rotate(toAngle: amount, duration: duration, shortestUnitArc: true)
    let b = SKAction.rotate(toAngle: -amount, duration: duration, shortestUnitArc: true)
    a.timingMode = .easeInEaseOut
    b.timingMode = .easeInEaseOut
    node.run(.sequence([.wait(forDuration: Double.random(in: 0...2)), .repeatForever(.sequence([a, b]))]))
    return node
}

func bobbing(_ node: SKNode, height: CGFloat = 4, duration: Double = 0.9) -> SKNode {
    let up = SKAction.moveBy(x: 0, y: height, duration: duration)
    let down = SKAction.moveBy(x: 0, y: -height, duration: duration)
    up.timingMode = .easeInEaseOut
    down.timingMode = .easeInEaseOut
    node.run(.sequence([.wait(forDuration: Double.random(in: 0...duration)), .repeatForever(.sequence([up, down]))]))
    return node
}

enum DepleteStyle {
    case fall, crumble, pop, splash, fade
}

enum NodeArt {
    static func style(_ type: NodeType) -> DepleteStyle {
        switch type {
        case .tree, .pine, .palm, .snowPine, .glowTree, .willow, .bananaPalm, .ashTree, .skyTree, .bamboo, .cactus:
            return .fall
        case .rock, .boulder, .coalOre, .ironOre, .goldOre, .iceBlock, .diamondOre, .crystalOre,
             .coral, .sulfurVent, .obsidianOre, .rubyOre, .starRock, .clayPit:
            return .crumble
        case .fishSpot, .oasisFish, .iceHole, .swampFish, .oyster, .lavaFish, .starPond:
            return .splash
        case .appleTree, .goldenTree:
            return .fade
        default:
            return .pop
        }
    }

    private static func ore(_ key: String, _ color: UIColor, plain: Bool = false) -> SKTexture {
        Art.texture("oreTex|\(key)|\(plain)") { Art.oreImage(color, size: 128, plain: plain) }
    }

    private static func water(_ alive: SKNode, _ dead: SKNode, tint: UIColor?, fish: String, fishTint: UIColor? = nil) {
        let ripple = sprite(Art.ripple, CGSize(width: 54, height: 27))
        if let tint {
            ripple.color = tint
            ripple.colorBlendFactor = 0.6
        }
        let grow = SKAction.scale(to: 1.15, duration: 1.0)
        let shrink = SKAction.scale(to: 0.9, duration: 1.0)
        grow.timingMode = .easeInEaseOut
        shrink.timingMode = .easeInEaseOut
        ripple.run(.repeatForever(.sequence([grow, shrink])))
        alive.addChild(ripple)
        let fishNode = emojiSprite(fish, 20, x: 0, y: 4, tint: fishTint, blend: fishTint == nil ? 0 : 0.5)
        alive.addChild(bobbing(fishNode, height: 4, duration: 0.6))
        let calm = sprite(Art.ripple, CGSize(width: 40, height: 20))
        calm.alpha = 0.3
        dead.addChild(calm)
    }

    /// Живой вид точки и вид после добычи.
    static func build(_ type: NodeType) -> (alive: SKNode, dead: SKNode) {
        let alive = SKNode()
        let dead = SKNode()
        let snow = UIColor.white
        let purple = UIColor(red: 0.62, green: 0.42, blue: 1, alpha: 1)
        let gray = UIColor(white: 0.55, alpha: 1)
        let brownStump = Art.stump()

        switch type {
        case .tree:
            alive.addChild(shadowSprite(48))
            alive.addChild(swaying(emojiSprite("🌳", 72, y: 28)))
            dead.addChild(sprite(brownStump, CGSize(width: 30, height: 22), CGPoint(x: 0, y: 4)))
        case .pine:
            alive.addChild(shadowSprite(44))
            alive.addChild(swaying(emojiSprite("🌲", 76, y: 30)))
            dead.addChild(sprite(brownStump, CGSize(width: 28, height: 21), CGPoint(x: 0, y: 4)))
        case .palm:
            alive.addChild(shadowSprite(46))
            alive.addChild(swaying(emojiSprite("🌴", 78, y: 30), amount: 0.05))
            dead.addChild(sprite(Art.stump(UIColor(red: 0.7, green: 0.5, blue: 0.3, alpha: 1)), CGSize(width: 26, height: 20), CGPoint(x: 0, y: 4)))
        case .snowPine:
            alive.addChild(shadowSprite(48))
            alive.addChild(swaying(emojiSprite("🌲", 80, y: 32, tint: snow, blend: 0.42)))
            dead.addChild(sprite(Art.stump(UIColor(red: 0.6, green: 0.5, blue: 0.45, alpha: 1)), CGSize(width: 30, height: 22), CGPoint(x: 0, y: 4)))
        case .glowTree:
            alive.addChild(glowSprite(purple, size: 120, y: 34, alpha: 0.45))
            alive.addChild(shadowSprite(48))
            alive.addChild(swaying(emojiSprite("🌳", 80, y: 30, tint: purple, blend: 0.55)))
            dead.addChild(sprite(Art.stump(purple), CGSize(width: 30, height: 22), CGPoint(x: 0, y: 4)))
        case .willow:
            alive.addChild(shadowSprite(50))
            alive.addChild(swaying(emojiSprite("🌳", 78, y: 30, tint: UIColor(red: 0.25, green: 0.45, blue: 0.35, alpha: 1), blend: 0.4), amount: 0.05))
            dead.addChild(sprite(brownStump, CGSize(width: 30, height: 22), CGPoint(x: 0, y: 4)))
        case .bananaPalm:
            alive.addChild(shadowSprite(50))
            let palm = swaying(emojiSprite("🌴", 84, y: 32), amount: 0.05)
            for (x, y) in [(-10.0, 58.0), (9.0, 62.0)] {
                let banana = emojiSprite("🍌", 22, x: CGFloat(x), y: CGFloat(y))
                banana.zPosition = 1
                palm.addChild(banana)
            }
            alive.addChild(palm)
            dead.addChild(sprite(Art.stump(UIColor(red: 0.7, green: 0.5, blue: 0.3, alpha: 1)), CGSize(width: 28, height: 21), CGPoint(x: 0, y: 4)))
        case .ashTree:
            alive.addChild(glowSprite(UIColor(red: 1, green: 0.4, blue: 0.1, alpha: 1), size: 90, y: 20, alpha: 0.35))
            alive.addChild(shadowSprite(50))
            alive.addChild(swaying(emojiSprite("🌳", 80, y: 30, tint: UIColor(white: 0.22, alpha: 1), blend: 0.75), amount: 0.02))
            dead.addChild(sprite(Art.stump(UIColor(white: 0.25, alpha: 1)), CGSize(width: 30, height: 22), CGPoint(x: 0, y: 4)))
        case .skyTree:
            alive.addChild(glowSprite(UIColor(red: 0.7, green: 0.85, blue: 1, alpha: 1), size: 130, y: 36, alpha: 0.5))
            alive.addChild(shadowSprite(50))
            alive.addChild(swaying(emojiSprite("🌳", 84, y: 32, tint: UIColor(red: 0.75, green: 0.9, blue: 1, alpha: 1), blend: 0.5)))
            dead.addChild(sprite(Art.stump(UIColor(red: 0.8, green: 0.85, blue: 0.95, alpha: 1)), CGSize(width: 30, height: 22), CGPoint(x: 0, y: 4)))
        case .bush:
            alive.addChild(shadowSprite(36))
            alive.addChild(emojiSprite("🌿", 44, y: 14))
            alive.addChild(emojiSprite("🫐", 22, x: -6, y: 16))
            alive.addChild(emojiSprite("🫐", 18, x: 9, y: 22))
            dead.addChild(emojiSprite("🌿", 34, y: 10))
            dead.alpha = 0.8
        case .appleTree:
            alive.addChild(shadowSprite(48))
            let tree = swaying(emojiSprite("🌳", 72, y: 28))
            for (x, y) in [(-14.0, 55.0), (12.0, 61.0), (0.0, 43.0)] {
                let apple = emojiSprite("🍎", 16, x: CGFloat(x), y: CGFloat(y))
                apple.zPosition = 1
                tree.addChild(apple)
            }
            alive.addChild(tree)
            dead.addChild(shadowSprite(48))
            dead.addChild(swaying(emojiSprite("🌳", 72, y: 28)))
        case .goldenTree:
            let gold = ResourceKind.goldenApple.oreColor
            alive.addChild(glowSprite(gold, size: 130, y: 36, alpha: 0.4))
            alive.addChild(shadowSprite(50))
            let tree = swaying(emojiSprite("🌳", 78, y: 30, tint: gold, blend: 0.3))
            for (x, y) in [(-15.0, 58.0), (13.0, 64.0), (0.0, 45.0), (-4.0, 70.0)] {
                let apple = sprite(Art.tintedEmojiTexture("🍎", tint: gold, amount: 0.6, size: 18), CGSize(width: 17, height: 17), CGPoint(x: CGFloat(x), y: CGFloat(y)))
                apple.zPosition = 1
                tree.addChild(apple)
            }
            alive.addChild(tree)
            dead.addChild(shadowSprite(50))
            dead.addChild(swaying(emojiSprite("🌳", 78, y: 30, tint: gold, blend: 0.3)))
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
        case .herbPatch:
            alive.addChild(emojiSprite("🌿", 36, x: -6, y: 12))
            alive.addChild(emojiSprite("🌱", 26, x: 10, y: 8))
            alive.addChild(emojiSprite("🌼", 14, x: 2, y: 22))
            dead.addChild(sprite(Art.dirt, CGSize(width: 28, height: 13)))
        case .cactus:
            alive.addChild(shadowSprite(36))
            alive.addChild(swaying(emojiSprite("🌵", 58, y: 22), amount: 0.015))
            dead.addChild(emojiSprite("🌱", 20, y: 6))
        case .bamboo:
            alive.addChild(shadowSprite(36))
            alive.addChild(swaying(emojiSprite("🎋", 64, y: 26), amount: 0.06))
            dead.addChild(emojiSprite("🌱", 20, y: 6))
        case .glowShroom:
            let cyan = UIColor(red: 0.35, green: 0.95, blue: 1, alpha: 1)
            alive.addChild(glowSprite(cyan, size: 72, y: 12, alpha: 0.6))
            alive.addChild(emojiSprite("🍄", 34, x: -6, y: 12, tint: cyan, blend: 0.5))
            alive.addChild(emojiSprite("🍄", 24, x: 10, y: 8, tint: cyan, blend: 0.5))
            dead.addChild(sprite(Art.dirt, CGSize(width: 28, height: 13)))
        case .pineapple:
            alive.addChild(shadowSprite(30))
            alive.addChild(swaying(emojiSprite("🍍", 40, y: 16), amount: 0.04))
            dead.addChild(emojiSprite("🌱", 20, y: 6))
        case .shells:
            let a = emojiSprite("🐚", 24, x: -7, y: 6)
            a.zRotation = 0.4
            alive.addChild(a)
            alive.addChild(emojiSprite("🐚", 18, x: 9, y: 4))
            let sparkleNode = sprite(Art.spark, CGSize(width: 12, height: 12), CGPoint(x: 4, y: 16))
            sparkleNode.run(.repeatForever(.sequence([.fadeAlpha(to: 0, duration: 0.7), .fadeAlpha(to: 1, duration: 0.7)])))
            alive.addChild(sparkleNode)
            let mark = sprite(Art.dirt, CGSize(width: 22, height: 10))
            mark.alpha = 0.3
            dead.addChild(mark)
        case .fireFlower:
            let orange = UIColor(red: 1, green: 0.45, blue: 0.1, alpha: 1)
            alive.addChild(glowSprite(orange, size: 70, y: 14, alpha: 0.6))
            alive.addChild(swaying(emojiSprite("🌺", 34, y: 14, tint: orange, blend: 0.35), amount: 0.08))
            alive.addChild(emojiSprite("🌿", 24, x: 10, y: 6))
            dead.addChild(sprite(Art.dirt, CGSize(width: 28, height: 13)))
        case .cloudBush:
            alive.addChild(glowSprite(.white, size: 90, y: 20, alpha: 0.45))
            alive.addChild(bobbing(emojiSprite("☁️", 58, y: 20), height: 6, duration: 1.4))
            let wisp = emojiSprite("☁️", 20, y: 8)
            wisp.alpha = 0.35
            dead.addChild(wisp)
        case .rock:
            alive.addChild(shadowSprite(42))
            alive.addChild(emojiSprite("🪨", 48, y: 14))
            dead.addChild(sprite(Art.rubble(gray), CGSize(width: 30, height: 18), CGPoint(x: 0, y: 4)))
        case .boulder:
            alive.addChild(shadowSprite(64))
            alive.addChild(emojiSprite("🪨", 76, y: 22))
            dead.addChild(sprite(Art.rubble(gray), CGSize(width: 44, height: 26), CGPoint(x: 0, y: 4)))
        case .clayPit:
            alive.addChild(sprite(Art.clay, CGSize(width: 60, height: 38), CGPoint(x: 0, y: 8)))
            alive.addChild(emojiSprite("🧱", 18, x: 12, y: 18))
            let wet = sprite(Art.dirt, CGSize(width: 44, height: 18))
            wet.alpha = 0.7
            dead.addChild(wet)
        case .coalOre, .ironOre, .goldOre:
            let kind: ResourceKind = type == .coalOre ? .coal : (type == .ironOre ? .iron : .gold)
            if kind == .gold { alive.addChild(glowSprite(kind.oreColor, size: 80, y: 18, alpha: 0.25)) }
            alive.addChild(shadowSprite(54))
            alive.addChild(sprite(ore(kind.rawValue, kind.oreColor), CGSize(width: 58, height: 58), CGPoint(x: 0, y: 18)))
            dead.addChild(sprite(Art.rubble(UIColor(white: 0.5, alpha: 1)), CGSize(width: 38, height: 22), CGPoint(x: 0, y: 4)))
        case .sulfurVent:
            let yellow = ResourceKind.sulfur.oreColor
            alive.addChild(glowSprite(yellow, size: 80, y: 18, alpha: 0.3))
            alive.addChild(shadowSprite(54))
            alive.addChild(sprite(ore("sulfur", yellow), CGSize(width: 58, height: 58), CGPoint(x: 0, y: 18)))
            let smoke = sprite(Art.puff, CGSize(width: 26, height: 26), CGPoint(x: 4, y: 40))
            smoke.color = UIColor(red: 0.95, green: 0.95, blue: 0.7, alpha: 1)
            smoke.colorBlendFactor = 1
            smoke.alpha = 0
            smoke.run(.repeatForever(.sequence([
                .group([.fadeAlpha(to: 0.6, duration: 0.3), .scale(to: 1, duration: 0.3)]),
                .group([.moveBy(x: 6, y: 34, duration: 1.4), .fadeOut(withDuration: 1.4), .scale(to: 2.2, duration: 1.4)]),
                .moveBy(x: -6, y: -34, duration: 0),
                .scale(to: 0.6, duration: 0),
                .wait(forDuration: 0.4)
            ])))
            alive.addChild(smoke)
            dead.addChild(sprite(Art.rubble(yellow), CGSize(width: 38, height: 22), CGPoint(x: 0, y: 4)))
        case .obsidianOre:
            let color = ResourceKind.obsidian.oreColor
            alive.addChild(shadowSprite(54))
            alive.addChild(sprite(ore("obsidianRock", UIColor(white: 0.2, alpha: 1), plain: true), CGSize(width: 58, height: 58), CGPoint(x: 0, y: 18)))
            alive.addChild(sprite(Art.texture("gemTex|obsidian") { Art.gemImage(color, size: 64) }, CGSize(width: 30, height: 30), CGPoint(x: -6, y: 30)))
            alive.addChild(sprite(Art.texture("gemTex|obsidian") { Art.gemImage(color, size: 64) }, CGSize(width: 22, height: 22), CGPoint(x: 12, y: 22)))
            dead.addChild(sprite(Art.rubble(UIColor(white: 0.25, alpha: 1)), CGSize(width: 38, height: 22), CGPoint(x: 0, y: 4)))
        case .rubyOre:
            let red = ResourceKind.ruby.oreColor
            alive.addChild(glowSprite(red, size: 86, y: 22, alpha: 0.35))
            alive.addChild(shadowSprite(54))
            alive.addChild(sprite(ore("rubyRock", UIColor(white: 0.35, alpha: 1), plain: true), CGSize(width: 58, height: 58), CGPoint(x: 0, y: 18)))
            let gem = sprite(Art.texture("gemTex|ruby") { Art.gemImage(red, size: 64) }, CGSize(width: 30, height: 30), CGPoint(x: 4, y: 32))
            gem.run(.repeatForever(.sequence([.scale(to: 1.12, duration: 0.8), .scale(to: 1, duration: 0.8)])))
            alive.addChild(gem)
            dead.addChild(sprite(Art.rubble(UIColor(white: 0.4, alpha: 1)), CGSize(width: 38, height: 22), CGPoint(x: 0, y: 4)))
        case .iceBlock:
            alive.addChild(shadowSprite(46))
            alive.addChild(emojiSprite("🧊", 52, y: 18))
            dead.addChild(sprite(Art.rubble(UIColor(red: 0.75, green: 0.9, blue: 1, alpha: 1)), CGSize(width: 34, height: 20), CGPoint(x: 0, y: 4)))
        case .diamondOre:
            alive.addChild(glowSprite(ResourceKind.diamond.oreColor, size: 80, y: 24, alpha: 0.3))
            alive.addChild(shadowSprite(54))
            alive.addChild(sprite(ore("diamond", ResourceKind.diamond.oreColor), CGSize(width: 58, height: 58), CGPoint(x: 0, y: 18)))
            let gem = emojiSprite("💎", 26, x: 12, y: 36)
            gem.run(.repeatForever(.sequence([.scale(to: 1.12, duration: 0.8), .scale(to: 1, duration: 0.8)])))
            alive.addChild(gem)
            dead.addChild(sprite(Art.rubble(UIColor(white: 0.5, alpha: 1)), CGSize(width: 38, height: 22), CGPoint(x: 0, y: 4)))
        case .crystalOre:
            alive.addChild(glowSprite(purple, size: 100, y: 24, alpha: 0.5))
            alive.addChild(shadowSprite(54))
            alive.addChild(sprite(Art.texture("crystalTex") { Art.crystalImage(size: 128) }, CGSize(width: 66, height: 66), CGPoint(x: 0, y: 24)))
            dead.addChild(sprite(Art.rubble(UIColor(red: 0.55, green: 0.45, blue: 0.7, alpha: 1)), CGSize(width: 38, height: 22), CGPoint(x: 0, y: 4)))
        case .coral:
            alive.addChild(shadowSprite(46))
            alive.addChild(swaying(emojiSprite("🪸", 58, y: 22), amount: 0.03))
            dead.addChild(sprite(Art.rubble(UIColor(red: 1, green: 0.6, blue: 0.6, alpha: 1)), CGSize(width: 36, height: 20), CGPoint(x: 0, y: 4)))
        case .starRock:
            let star = UIColor(red: 1, green: 0.92, blue: 0.5, alpha: 1)
            alive.addChild(glowSprite(star, size: 110, y: 26, alpha: 0.5))
            alive.addChild(shadowSprite(54))
            alive.addChild(sprite(ore("star", star), CGSize(width: 60, height: 60), CGPoint(x: 0, y: 18)))
            let twinkle = emojiSprite("🌟", 24, x: 10, y: 40)
            twinkle.run(.repeatForever(.sequence([.group([.scale(to: 1.2, duration: 0.7), .rotate(byAngle: 0.4, duration: 0.7)]),
                                                  .group([.scale(to: 0.9, duration: 0.7), .rotate(byAngle: -0.4, duration: 0.7)])])))
            alive.addChild(twinkle)
            dead.addChild(sprite(Art.rubble(UIColor(red: 0.9, green: 0.85, blue: 0.6, alpha: 1)), CGSize(width: 38, height: 22), CGPoint(x: 0, y: 4)))
        case .fishSpot, .oasisFish:
            water(alive, dead, tint: nil, fish: "🐟")
        case .swampFish:
            water(alive, dead, tint: UIColor(red: 0.7, green: 0.9, blue: 0.6, alpha: 1), fish: "🐟", fishTint: UIColor(red: 0.4, green: 0.6, blue: 0.3, alpha: 1))
        case .oyster:
            water(alive, dead, tint: nil, fish: "🦪")
        case .lavaFish:
            alive.addChild(glowSprite(UIColor(red: 1, green: 0.5, blue: 0.1, alpha: 1), size: 60, y: 2, alpha: 0.6))
            water(alive, dead, tint: UIColor(red: 1, green: 0.8, blue: 0.3, alpha: 1), fish: "🐟", fishTint: UIColor(red: 1, green: 0.3, blue: 0.1, alpha: 1))
        case .starPond:
            alive.addChild(glowSprite(UIColor(red: 0.7, green: 0.6, blue: 1, alpha: 1), size: 60, y: 2, alpha: 0.5))
            water(alive, dead, tint: UIColor(red: 0.85, green: 0.8, blue: 1, alpha: 1), fish: "🐠")
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
