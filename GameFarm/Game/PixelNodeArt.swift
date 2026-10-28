import SpriteKit
import UIKit

/// Пиксельный вид точек добычи. Для типов без спрайтов возвращает nil,
/// и тогда NodeArt рисует эмодзи.
enum PixelNodeArt {
    private static let s = Sprites.scale

    /// Лёгкое «дыхание» кроны: дерево чуть тянется вверх от основания.
    private static func breathe(_ node: SKSpriteNode) -> SKSpriteNode {
        let up = SKAction.scaleY(to: 1.025, duration: Double.random(in: 1.6...2.2))
        let down = SKAction.scaleY(to: 1, duration: Double.random(in: 1.6...2.2))
        up.timingMode = .easeInEaseOut
        down.timingMode = .easeInEaseOut
        node.run(.sequence([.wait(forDuration: Double.random(in: 0...2)), .repeatForever(.sequence([up, down]))]))
        return node
    }

    private static func tinted(_ node: SKSpriteNode, _ color: UIColor?, _ amount: CGFloat = 0.55) -> SKSpriteNode {
        if let color {
            node.color = color
            node.colorBlendFactor = amount
        }
        return node
    }

    private static func pulse(_ node: SKNode) -> SKNode {
        node.run(.repeatForever(.sequence([.scale(to: 1.1, duration: 0.8), .scale(to: 1, duration: 0.8)])))
        return node
    }

    static func build(_ type: NodeType) -> (alive: SKNode, dead: SKNode)? {
        guard Sprites.available else { return nil }
        let alive = SKNode()
        let dead = SKNode()

        /// Дерево: крона, при желании тень, свечение и пень своего цвета.
        func tree(_ name: String, scale: CGFloat, shadow: CGFloat? = nil, stump: UIColor? = nil,
                  glow: UIColor? = nil, glowAlpha: CGFloat = 0.45, deadName: String? = nil) -> Bool {
            guard let crown = Sprites.node(name, scale: scale) else { return false }
            if let glow { alive.addChild(glowSprite(glow, size: 130, y: 44, alpha: glowAlpha)) }
            if let shadow { alive.addChild(shadowSprite(shadow)) }
            alive.addChild(breathe(crown))
            if let deadName, let bare = Sprites.node(deadName, scale: scale) {
                if let shadow { dead.addChild(shadowSprite(shadow)) }
                dead.addChild(bare)
            } else if let stumpNode = Sprites.node("stump", scale: s) {
                dead.addChild(tinted(stumpNode, stump, 0.5))
            }
            return true
        }

        /// Камень или руда: спрайт и россыпь камешков после добычи.
        func ore(_ name: String, scale: CGFloat = 2.8, rubble: UIColor? = nil, glow: UIColor? = nil, glowAlpha: CGFloat = 0.3) -> Bool {
            guard let rock = Sprites.node(name, scale: scale) else { return false }
            if let glow { alive.addChild(glowSprite(glow, size: 84, y: 18, alpha: glowAlpha)) }
            alive.addChild(rock)
            if let pebbles = Sprites.node("pebbles", scale: s) {
                pebbles.alpha = 0.9
                dead.addChild(tinted(pebbles, rubble, 0.6))
            }
            return true
        }

        /// Камень с кристаллом спереди.
        func gemRock(_ gem: String, base: String, glow: UIColor, rubble: UIColor? = nil) -> Bool {
            guard let rock = Sprites.node(base, scale: 2.6, x: -7, y: 2),
                  let crystal = Sprites.node(gem, scale: 2.3, x: 9, y: -3) else { return false }
            alive.addChild(glowSprite(glow, size: 90, y: 20, alpha: 0.4))
            alive.addChild(rock)
            alive.addChild(pulse(crystal))
            if let pebbles = Sprites.node("pebbles", scale: s) {
                dead.addChild(tinted(pebbles, rubble, 0.6))
            }
            return true
        }

        func dirt() {
            dead.addChild(sprite(Art.dirt, CGSize(width: 30, height: 14)))
        }

        let purple = UIColor(red: 0.62, green: 0.42, blue: 1, alpha: 1)
        var ok = true
        switch type {
        case .tree:
            ok = tree("oak", scale: 1.4)
        case .pine:
            ok = tree("pine", scale: 1.05, shadow: 46)
        case .snowPine:
            ok = tree("pine_frost", scale: 1.05, shadow: 46, stump: UIColor(red: 0.85, green: 0.92, blue: 1, alpha: 1))
        case .glowTree:
            ok = tree("oak_glow", scale: 1.45, stump: purple, glow: purple)
        case .willow:
            ok = tree("oak_willow", scale: 1.5)
        case .ashTree:
            ok = tree("ash", scale: 0.85, shadow: 48, stump: UIColor(white: 0.2, alpha: 1),
                      glow: UIColor(red: 1, green: 0.4, blue: 0.1, alpha: 1), glowAlpha: 0.3)
        case .skyTree:
            ok = tree("oak_sky", scale: 1.5, stump: UIColor(red: 0.8, green: 0.88, blue: 1, alpha: 1),
                      glow: UIColor(red: 0.7, green: 0.85, blue: 1, alpha: 1), glowAlpha: 0.5)
        case .appleTree:
            ok = tree("oak_apple", scale: 1.4, deadName: "oak")
        case .goldenTree:
            ok = tree("oak_golden", scale: 1.45, glow: ResourceKind.goldenApple.oreColor, glowAlpha: 0.4, deadName: "oak_golden_bare")
        case .bush:
            guard let full = Sprites.node("bush", scale: 1.05), let empty = Sprites.node("bush_empty", scale: 0.95) else { return nil }
            alive.addChild(full)
            empty.alpha = 0.85
            dead.addChild(empty)
        case .mushroom:
            guard let a = Sprites.node("mushroom", scale: s, x: -6, y: 0),
                  let b = Sprites.node("mushroom", scale: 2, x: 9, y: -3) else { return nil }
            alive.addChild(a)
            alive.addChild(b)
            dirt()
        case .glowShroom:
            let cyan = UIColor(red: 0.35, green: 0.95, blue: 1, alpha: 1)
            guard let a = Sprites.node("mushroom", scale: s, x: -6, y: 0),
                  let b = Sprites.node("mushroom", scale: 2, x: 9, y: -3) else { return nil }
            alive.addChild(glowSprite(cyan, size: 72, y: 12, alpha: 0.6))
            alive.addChild(tinted(a, cyan, 0.65))
            alive.addChild(tinted(b, cyan, 0.65))
            dirt()
        case .carrot:
            alive.addChild(sprite(Art.dirt, CGSize(width: 40, height: 16)))
            guard let a = Sprites.node("carrot", scale: s, x: -9, y: 0),
                  let b = Sprites.node("carrot", scale: s, x: 9, y: 2),
                  let sprout = Sprites.node("sprout", scale: s, x: 0, y: 0) else { return nil }
            alive.addChild(b)
            alive.addChild(a)
            dead.addChild(sprite(Art.dirt, CGSize(width: 40, height: 16)))
            dead.addChild(sprout)
        case .herbPatch:
            guard let herb = Sprites.node("herb", scale: s, x: -5, y: 0),
                  let flower = Sprites.node("flowers_yellow", scale: 2, x: 11, y: -4) else { return nil }
            alive.addChild(herb)
            alive.addChild(flower)
            dirt()
        case .fireFlower:
            let orange = UIColor(red: 1, green: 0.45, blue: 0.1, alpha: 1)
            guard let flower = Sprites.node("tulip_red", scale: 2.8),
                  let grass = Sprites.node("grass3", scale: s, x: 10, y: -2) else { return nil }
            alive.addChild(glowSprite(orange, size: 70, y: 14, alpha: 0.6))
            alive.addChild(grass)
            alive.addChild(tinted(flower, orange, 0.3))
            dirt()
        case .rock:
            ok = ore("stone", scale: 2.7)
        case .boulder:
            guard let big = Sprites.node("stone", scale: 3.7, x: -4, y: 0),
                  let small = Sprites.node("stone3", scale: 2.2, x: 20, y: -6) else { return nil }
            alive.addChild(big)
            alive.addChild(small)
            if let pebbles = Sprites.node("pebbles", scale: 3.2) { dead.addChild(pebbles) }
        case .coalOre:
            ok = ore("coal", rubble: UIColor(white: 0.15, alpha: 1))
        case .ironOre:
            ok = ore("iron", rubble: UIColor(red: 0.6, green: 0.4, blue: 0.32, alpha: 1))
        case .goldOre:
            ok = ore("gold", rubble: UIColor(red: 0.95, green: 0.7, blue: 0.2, alpha: 1), glow: ResourceKind.gold.oreColor, glowAlpha: 0.25)
        case .obsidianOre:
            ok = ore("obsidian", rubble: UIColor(red: 0.2, green: 0.15, blue: 0.3, alpha: 1))
        case .iceBlock:
            ok = ore("ice", scale: 3, rubble: UIColor(red: 0.75, green: 0.9, blue: 1, alpha: 1))
        case .crystalOre:
            ok = ore("crystal", scale: 3.1, rubble: UIColor(red: 0.55, green: 0.45, blue: 0.7, alpha: 1), glow: purple, glowAlpha: 0.5)
        case .diamondOre:
            ok = gemRock("diamond", base: "stone", glow: ResourceKind.diamond.oreColor)
        case .rubyOre:
            ok = gemRock("ruby", base: "stone2", glow: ResourceKind.ruby.oreColor)
        case .starRock:
            let star = UIColor(red: 1, green: 0.92, blue: 0.5, alpha: 1)
            ok = ore("star", scale: 3, rubble: star, glow: star, glowAlpha: 0.5)
            if ok {
                let twinkle = sprite(Art.spark, CGSize(width: 16, height: 16), CGPoint(x: 10, y: 40))
                twinkle.blendMode = .add
                twinkle.run(.repeatForever(.sequence([.group([.scale(to: 1.3, duration: 0.7), .fadeAlpha(to: 0.4, duration: 0.7)]),
                                                      .group([.scale(to: 0.8, duration: 0.7), .fadeAlpha(to: 1, duration: 0.7)])])))
                alive.addChild(twinkle)
            }
        case .sulfurVent:
            let yellow = ResourceKind.sulfur.oreColor
            ok = ore("sulfur", rubble: yellow, glow: yellow, glowAlpha: 0.3)
            if ok {
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
            }
        default:
            return nil
        }
        return ok ? (alive, dead) : nil
    }
}
