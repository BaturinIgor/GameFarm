import SpriteKit
import UIKit

enum Effects {
    private static func label(_ text: String, size: CGFloat, color: UIColor) -> SKLabelNode {
        let node = SKLabelNode()
        node.attributedText = NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: size, weight: .heavy),
            .foregroundColor: color,
            .strokeColor: UIColor.black.withAlphaComponent(0.65),
            .strokeWidth: -4
        ])
        node.verticalAlignmentMode = .center
        node.horizontalAlignmentMode = .center
        return node
    }

    private static func rise(_ node: SKNode, delay: Double, distance: CGFloat = 42, duration: Double = 0.9) {
        node.alpha = 0
        node.setScale(0.6)
        node.run(.sequence([
            .wait(forDuration: delay),
            .group([
                .fadeIn(withDuration: 0.08),
                .scale(to: 1, duration: 0.12),
                .moveBy(x: 0, y: distance, duration: duration)
            ]),
            .fadeOut(withDuration: 0.25),
            .removeFromParent()
        ]))
    }

    static func text(_ text: String, at point: CGPoint, in parent: SKNode, color: UIColor = .white,
                     size: CGFloat = 17, delay: Double = 0) {
        let node = label(text, size: size, color: color)
        node.position = point
        node.zPosition = 900
        parent.addChild(node)
        rise(node, delay: delay)
    }

    static func gain(_ kind: ResourceKind, _ amount: Int, at point: CGPoint, in parent: SKNode,
                     delay: Double = 0, small: Bool = false) {
        let container = SKNode()
        container.position = point
        container.zPosition = 900
        let size: CGFloat = small ? 14 : 18
        let text = label("+\(amount)", size: size, color: .white)
        text.horizontalAlignmentMode = .right
        text.position = CGPoint(x: 2, y: 0)
        container.addChild(text)
        let icon = SKSpriteNode(texture: Art.iconTexture(kind), size: CGSize(width: size * 1.35, height: size * 1.35))
        icon.position = CGPoint(x: 4 + size * 0.7, y: 0)
        container.addChild(icon)
        parent.addChild(container)
        rise(container, delay: delay)
    }

    static func chips(at point: CGPoint, color: UIColor, in parent: SKNode, count: Int = 5) {
        for _ in 0..<count {
            let chip = SKSpriteNode(color: color, size: CGSize(width: 5, height: 5))
            chip.position = CGPoint(x: point.x, y: point.y + 18)
            chip.zPosition = 850
            chip.zRotation = CGFloat.random(in: 0...3)
            parent.addChild(chip)
            let dx = CGFloat.random(in: -30...30)
            let up = CGFloat.random(in: 12...30)
            let jump = SKAction.sequence([
                .moveBy(x: dx * 0.5, y: up, duration: 0.14),
                .moveBy(x: dx * 0.5, y: -up - 14, duration: 0.2)
            ])
            chip.run(.sequence([.group([jump, .rotate(byAngle: 4, duration: 0.34)]), .fadeOut(withDuration: 0.2), .removeFromParent()]))
        }
    }

    static func hearts(at point: CGPoint, in parent: SKNode) {
        for i in 0..<7 {
            let heart = SKSpriteNode(texture: Art.emoji("💖", size: 32), size: CGSize(width: 22, height: 22))
            heart.position = CGPoint(x: point.x, y: point.y + 20)
            heart.zPosition = 900
            parent.addChild(heart)
            let a = CGFloat(i) / 7 * .pi * 2
            heart.run(.sequence([
                .group([.moveBy(x: cos(a) * 46, y: sin(a) * 46 + 30, duration: 0.6), .fadeOut(withDuration: 0.7)]),
                .removeFromParent()
            ]))
        }
    }

    static func burst(at point: CGPoint, emoji: String, in parent: SKNode) {
        for i in 0..<6 {
            let node = SKSpriteNode(texture: Art.emoji(emoji, size: 32), size: CGSize(width: 18, height: 18))
            node.position = point
            node.zPosition = 900
            parent.addChild(node)
            let a = CGFloat(i) / 6 * .pi * 2 + 0.3
            node.run(.sequence([
                .group([.moveBy(x: cos(a) * 40, y: sin(a) * 40, duration: 0.45), .fadeOut(withDuration: 0.5), .scale(to: 0.5, duration: 0.5)]),
                .removeFromParent()
            ]))
        }
    }

    /// Ресурсы улетают из рюкзака в склад.
    static func fly(_ kinds: [ResourceKind], from: CGPoint, to: CGPoint, in parent: SKNode) {
        for (i, kind) in kinds.prefix(6).enumerated() {
            let icon = SKSpriteNode(texture: Art.iconTexture(kind), size: CGSize(width: 22, height: 22))
            icon.position = CGPoint(x: from.x, y: from.y + 30)
            icon.zPosition = 900
            icon.alpha = 0
            parent.addChild(icon)
            let path = UIBezierPath()
            path.move(to: .zero)
            let dx = to.x - from.x
            let dy = to.y + 20 - (from.y + 30)
            path.addQuadCurve(to: CGPoint(x: dx, y: dy), controlPoint: CGPoint(x: dx / 2, y: max(dy, 0) + 70))
            let follow = SKAction.follow(path.cgPath, asOffset: true, orientToPath: false, duration: 0.45)
            icon.run(.sequence([
                .wait(forDuration: Double(i) * 0.06),
                .fadeIn(withDuration: 0.05),
                follow,
                .group([.fadeOut(withDuration: 0.12), .scale(to: 0.4, duration: 0.12)]),
                .removeFromParent()
            ]))
        }
    }
    /// Облачко пыли у ног или после разрушения.
    static func puff(at point: CGPoint, in parent: SKNode, color: UIColor, size: CGFloat = 22, z: CGFloat = 99) {
        let node = SKSpriteNode(texture: Art.puff, size: CGSize(width: size, height: size))
        node.color = color
        node.colorBlendFactor = 1
        node.alpha = 0.55
        node.position = point
        node.zPosition = z
        node.setScale(0.4)
        parent.addChild(node)
        let grow = SKAction.scale(to: 1.3, duration: 0.5)
        grow.timingMode = .easeOut
        node.run(.sequence([.group([grow, .fadeOut(withDuration: 0.5), .moveBy(x: 0, y: 6, duration: 0.5)]), .removeFromParent()]))
    }

    /// Разлетающиеся спрайты: листья, капли, искры.
    static func scatter(_ texture: SKTexture, count: Int, at point: CGPoint, in parent: SKNode, size: CGFloat,
                        color: UIColor? = nil, spread: CGFloat = 50, rise: CGFloat = 30, additive: Bool = false, duration: Double = 0.6) {
        for _ in 0..<count {
            let node = SKSpriteNode(texture: texture, size: CGSize(width: size, height: size))
            if let color {
                node.color = color
                node.colorBlendFactor = 1
            }
            if additive { node.blendMode = .add }
            node.position = point
            node.zPosition = 880
            node.zRotation = CGFloat.random(in: 0...6)
            parent.addChild(node)
            let a = CGFloat.random(in: 0...(.pi * 2))
            let r = CGFloat.random(in: spread * 0.4...spread)
            let dx = cos(a) * r
            let dy = sin(a) * r * 0.6 + rise
            let move = SKAction.moveBy(x: dx, y: dy, duration: duration)
            move.timingMode = .easeOut
            node.run(.sequence([
                .group([move, .rotate(byAngle: CGFloat.random(in: -3...3), duration: duration),
                        .sequence([.wait(forDuration: duration * 0.5), .fadeOut(withDuration: duration * 0.5)])]),
                .removeFromParent()
            ]))
        }
    }

    static func ring(at point: CGPoint, in parent: SKNode, color: UIColor, radius: CGFloat = 30) {
        let node = SKShapeNode(circleOfRadius: radius)
        node.strokeColor = color
        node.lineWidth = 3
        node.fillColor = .clear
        node.position = point
        node.zPosition = 870
        node.setScale(0.3)
        parent.addChild(node)
        let grow = SKAction.scale(to: 1.4, duration: 0.45)
        grow.timingMode = .easeOut
        node.run(.sequence([.group([grow, .fadeOut(withDuration: 0.45)]), .removeFromParent()]))
    }
}
