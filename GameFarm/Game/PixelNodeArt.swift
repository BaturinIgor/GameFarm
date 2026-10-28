import SpriteKit
import UIKit

/// Пиксельный вид точек добычи. Для типов без спрайтов возвращает nil,
/// и тогда NodeArt рисует эмодзи.
enum PixelNodeArt {
    /// Лёгкое "дыхание" кроны: дерево чуть тянется вверх от основания.
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
        node.run(.repeatForever(.sequence([.scale(to: 1.08, duration: 0.8), .scale(to: 1, duration: 0.8)])))
        return node
    }

    static func build(_ type: NodeType) -> (alive: SKNode, dead: SKNode)? {
        guard Sprites.available else { return nil }
        let alive = SKNode()
        let dead = SKNode()

        func add(_ parent: SKNode, _ name: String, x: CGFloat = 0, y: CGFloat = 0) -> SKSpriteNode? {
            guard let node = Sprites.node(name, x: x, y: y) else { return nil }
            parent.addChild(node)
            return node
        }

        /// Дерево: крона, при желании свечение, и пень или голое дерево после рубки.
        func tree(_ name: String, dead deadName: String, glow: UIColor? = nil, glowAlpha: CGFloat = 0.4) -> Bool {
            guard let crown = Sprites.node(name) else { return false }
            if let glow { alive.addChild(glowSprite(glow, size: crown.size.width * 1.6, y: crown.size.height * 0.5, alpha: glowAlpha)) }
            alive.addChild(breathe(crown))
            _ = add(dead, deadName)
            return true
        }

        /// Руда: глыба и камешек рядом, после добычи - щебень.
        func ore(_ name: String, chunk: String?, glow: UIColor? = nil, glowAlpha: CGFloat = 0.3) -> Bool {
            guard let rock = Sprites.node(name, x: -4, y: 0) else { return false }
            if let glow { alive.addChild(glowSprite(glow, size: 76, y: 14, alpha: glowAlpha)) }
            if let chunk, let small = Sprites.node(chunk, x: 13, y: -3) {
                alive.addChild(small)
            }
            alive.addChild(rock)
            _ = add(dead, "rubble")
            return true
        }

        /// Рыба под водой: анимированная тень и круги.
        func fish(_ name: String, glow: UIColor? = nil) -> Bool {
            guard let shadow = Sprites.animated(name, fps: 8) else { return false }
            shadow.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            if let glow { alive.addChild(glowSprite(glow, size: 56, y: 0, alpha: 0.45)) }
            alive.addChild(shadow)
            let ripple = sprite(Art.ripple, CGSize(width: 40, height: 20))
            ripple.alpha = 0.5
            ripple.run(.repeatForever(.sequence([.scale(to: 1.15, duration: 1), .scale(to: 0.9, duration: 1)])))
            alive.addChild(ripple)
            let calm = sprite(Art.ripple, CGSize(width: 30, height: 15))
            calm.alpha = 0.25
            dead.addChild(calm)
            return true
        }

        let purple = UIColor(red: 0.62, green: 0.42, blue: 1, alpha: 1)
        var ok = true
        switch type {
        case .tree:
            ok = tree(Bool.random() ? "tree_oak" : "tree_fruit", dead: "stump_oak")
        case .pine:
            ok = tree("tree_spruce", dead: "stump_spruce")
        case .snowPine:
            ok = tree("tree_frost", dead: "stump_frost")
        case .glowTree:
            ok = tree("tree_glow", dead: "stump_oak", glow: purple, glowAlpha: 0.45)
        case .willow:
            ok = tree("tree_willow", dead: "stump_fruit")
        case .ashTree:
            ok = tree("tree_ash", dead: "stump_ash", glow: UIColor(red: 1, green: 0.4, blue: 0.1, alpha: 1), glowAlpha: 0.25)
        case .skyTree:
            ok = tree("tree_sky", dead: "stump_birch", glow: UIColor(red: 0.75, green: 0.85, blue: 1, alpha: 1), glowAlpha: 0.4)
        case .appleTree:
            ok = tree(["tree_apple", "tree_apple", "tree_cherry", "tree_peach", "tree_pear"].randomElement()!, dead: "tree_apple_bare")
        case .goldenTree:
            ok = tree("tree_golden", dead: "tree_golden_bare", glow: ResourceKind.goldenApple.oreColor, glowAlpha: 0.35)
        case .palm:
            ok = tree("palm", dead: "stump_fruit")
        case .bananaPalm:
            ok = tree("palm_banana", dead: "stump_fruit")
        case .bamboo:
            ok = tree("bamboo", dead: "sprout")
        case .cactus:
            ok = tree("cactus", dead: "sprout")
        case .bush:
            guard add(alive, "bush_berry") != nil else { return nil }
            _ = add(dead, "bush")
        case .cloudBush:
            guard add(alive, "bush_cloud_star") != nil else { return nil }
            _ = add(dead, "bush_cloud")
        case .grapeVine:
            guard add(alive, "grapes") != nil else { return nil }
            _ = add(dead, "grapes_bare")
        case .beehive:
            guard add(alive, "beehive_full") != nil else { return nil }
            _ = add(dead, "beehive")
            let bees = Array(Sprites.frames("an_bee", cell: 16).prefix(4))
            if let first = bees.first {
                for i in 0..<2 {
                    let bee = SKSpriteNode(texture: first, size: CGSize(width: 16, height: 16))
                    bee.run(.repeatForever(.animate(with: bees, timePerFrame: 0.06)))
                    let r: CGFloat = 16 + CGFloat(i) * 6
                    let circle = SKAction.customAction(withDuration: 3 + Double(i)) { node, t in
                        let a = t / CGFloat(3 + i) * .pi * 2 + CGFloat(i) * 2
                        node.position = CGPoint(x: cos(a) * r, y: 30 + sin(a) * r * 0.4)
                        node.xScale = -sin(a) >= 0 ? -1 : 1
                    }
                    bee.run(.repeatForever(circle))
                    alive.addChild(bee)
                }
            }
        case .treasureChest:
            guard let box = Sprites.node("chest_gold_anim") else { return nil }
            alive.addChild(glowSprite(UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1), size: 70, y: 12, alpha: 0.4))
            alive.addChild(box)
            let open = Sprites.strip("chest_gold_anim")
            if let last = open.last, let node = Sprites.node("chest_gold_anim") {
                node.texture = last
                dead.addChild(node)
            }
        case .mushroom:
            guard add(alive, "mushroom_red", x: -5) != nil else { return nil }
            _ = add(alive, "mushroom_tiny_red", x: 8, y: -3)
        case .glowShroom:
            let cyan = UIColor(red: 0.35, green: 0.95, blue: 1, alpha: 1)
            alive.addChild(glowSprite(cyan, size: 60, y: 10, alpha: 0.55))
            guard add(alive, "mushroom_blue", x: -5) != nil else { return nil }
            _ = add(alive, "mushroom_tiny_blue", x: 8, y: -3)
        case .carrot:
            guard add(alive, "carrot_ripe", x: -7) != nil, add(alive, "carrot_ripe", x: 8, y: 2) != nil else { return nil }
            _ = add(dead, "sprout")
        case .herbPatch:
            guard add(alive, "leek", x: -4) != nil else { return nil }
            _ = add(alive, "flowers7", x: 9, y: -3)
            _ = add(dead, "leek_young")
        case .fireFlower:
            let orange = UIColor(red: 1, green: 0.45, blue: 0.1, alpha: 1)
            alive.addChild(glowSprite(orange, size: 60, y: 12, alpha: 0.55))
            guard let flowers = Sprites.node("flowers_red") else { return nil }
            alive.addChild(flowers)
            _ = add(dead, "tuft1")
        case .pineapple:
            guard add(alive, "pineapple") != nil else { return nil }
            _ = add(dead, "sprout")
        case .shells:
            guard add(alive, "shells") != nil else { return nil }
        case .rock:
            ok = ore("ore_stone", chunk: "chunk_stone")
        case .boulder:
            guard add(alive, "boulder") != nil else { return nil }
            _ = add(dead, "rubble")
        case .coalOre:
            ok = ore("ore_coal", chunk: "chunk_coal")
        case .ironOre:
            ok = ore("ore_iron", chunk: "chunk_copper")
        case .goldOre:
            ok = ore("ore_gold", chunk: "chunk_gold", glow: ResourceKind.gold.oreColor, glowAlpha: 0.22)
        case .diamondOre:
            ok = ore("ore_diamond", chunk: "chunk_diamond", glow: ResourceKind.diamond.oreColor, glowAlpha: 0.3)
        case .rubyOre:
            ok = ore("ore_ruby", chunk: "chunk_ruby", glow: ResourceKind.ruby.oreColor, glowAlpha: 0.3)
        case .obsidianOre:
            ok = ore("ore_obsidian", chunk: "chunk_obsidian")
        case .crystalOre:
            guard let crystal = Sprites.node("crystal_amethyst", x: -4) else { return nil }
            alive.addChild(glowSprite(purple, size: 80, y: 16, alpha: 0.45))
            alive.addChild(pulse(crystal))
            _ = add(alive, "chunk_amethyst", x: 12, y: -3)
            _ = add(dead, "rubble")
        case .iceBlock:
            ok = ore("ice_block", chunk: "chunk_ice")
        case .starRock:
            let star = UIColor(red: 1, green: 0.92, blue: 0.5, alpha: 1)
            ok = ore("ore_star", chunk: "chunk_star", glow: star, glowAlpha: 0.45)
            if ok {
                let twinkle = sprite(Art.spark, CGSize(width: 14, height: 14), CGPoint(x: 8, y: 34))
                twinkle.blendMode = .add
                twinkle.run(.repeatForever(.sequence([.group([.scale(to: 1.3, duration: 0.7), .fadeAlpha(to: 0.4, duration: 0.7)]),
                                                      .group([.scale(to: 0.8, duration: 0.7), .fadeAlpha(to: 1, duration: 0.7)])])))
                alive.addChild(twinkle)
            }
        case .sulfurVent:
            let yellow = ResourceKind.sulfur.oreColor
            ok = ore("ore_sulfur", chunk: "chunk_sulfur", glow: yellow, glowAlpha: 0.25)
            if ok {
                let smoke = sprite(Art.puff, CGSize(width: 22, height: 22), CGPoint(x: 0, y: 30))
                smoke.color = UIColor(red: 0.95, green: 0.95, blue: 0.7, alpha: 1)
                smoke.colorBlendFactor = 1
                smoke.alpha = 0
                smoke.run(.repeatForever(.sequence([
                    .group([.fadeAlpha(to: 0.6, duration: 0.3), .scale(to: 1, duration: 0.3)]),
                    .group([.moveBy(x: 6, y: 30, duration: 1.4), .fadeOut(withDuration: 1.4), .scale(to: 2.2, duration: 1.4)]),
                    .moveBy(x: -6, y: -30, duration: 0),
                    .scale(to: 0.6, duration: 0),
                    .wait(forDuration: 0.4)
                ])))
                alive.addChild(smoke)
            }
        case .coral:
            guard add(alive, "coral") != nil else { return nil }
            _ = add(dead, "rubble")
        case .clayPit:
            guard let pit = add(alive, "clay_pit") else { return nil }
            pit.anchorPoint = CGPoint(x: 0.5, y: 0.3)
            if let low = add(dead, "clay_pit") {
                low.anchorPoint = CGPoint(x: 0.5, y: 0.3)
                low.alpha = 0.55
            }
        case .fishSpot, .oasisFish:
            ok = fish("fish_anim")
        case .swampFish:
            ok = fish("fish_swamp_anim")
        case .lavaFish:
            ok = fish("fish_lava_anim", glow: UIColor(red: 1, green: 0.5, blue: 0.1, alpha: 1))
        case .starPond:
            ok = fish("fish_star_anim", glow: UIColor(red: 0.7, green: 0.6, blue: 1, alpha: 1))
        case .iceHole:
            guard let hole = Sprites.node("ice_hole") else { return nil }
            hole.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            alive.addChild(hole)
            if let shadow = Sprites.animated("fish_ice_anim", fps: 8) {
                shadow.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                shadow.setScale(0.7)
                alive.addChild(shadow)
            }
            if let still = Sprites.node("ice_hole") {
                still.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                dead.addChild(still)
            }
        case .pumpkinPatch:
            let orange = UIColor(red: 1, green: 0.55, blue: 0.1, alpha: 1)
            alive.addChild(glowSprite(orange, size: 64, y: 8, alpha: 0.3))
            guard add(alive, "crop_pumpkin_3", x: -8) != nil else { return nil }
            _ = add(alive, "crop_pumpkin_3", x: 9, y: -4)
            _ = add(dead, "crop_pumpkin_1")
        case .giftBox:
            let colors = ["gift_red", "gift_blue", "gift_green"].shuffled()
            guard add(alive, colors[0], x: -7) != nil else { return nil }
            _ = add(alive, colors[1], x: 8, y: -3)
            if let top = Sprites.node(colors[2], x: -1, y: 12) {
                top.setScale(0.8)
                alive.addChild(top)
            }
            alive.addChild(glowSprite(UIColor(red: 1, green: 0.9, blue: 0.5, alpha: 1), size: 60, y: 10, alpha: 0.25))
            _ = add(dead, "gift_paper")
        case .sandCastle:
            guard add(alive, "sandcastle") != nil else { return nil }
            _ = add(dead, "sand_pile")
        case .slimeCrystal:
            let green = UIColor(red: 0.45, green: 1, blue: 0.4, alpha: 1)
            guard let crystal = Sprites.node("crystal_slime", x: -4) else { return nil }
            alive.addChild(glowSprite(green, size: 84, y: 16, alpha: 0.5))
            alive.addChild(pulse(crystal))
            _ = add(alive, "slime_blob", x: 12, y: -3)
            _ = add(dead, "rubble")
        case .oyster:
            guard let shell = Sprites.node("oyster") else { return nil }
            shell.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            alive.addChild(shell)
            let calm = sprite(Art.ripple, CGSize(width: 30, height: 15))
            calm.alpha = 0.3
            dead.addChild(calm)
        }
        return ok ? (alive, dead) : nil
    }
}
