import SpriteKit
import UIKit

/// Ворота на краю локации: закрыты - преграда с замком, открыты - путь в соседнюю локацию.
final class GateNode: SKNode {
    let gate: GateSpec
    let place: GateLayout
    private(set) var isOpen: Bool
    private var barrier: SKSpriteNode?
    private var frames: [SKTexture] = []
    private let title = SKLabelNode()
    private let lockLabel = SKLabelNode()
    private var builtLanguage = ""
    private let cell: CGFloat

    init(gate: GateSpec, place: GateLayout, open: Bool, cell: CGFloat, stone: Bool) {
        self.gate = gate
        self.place = place
        self.isOpen = open
        self.cell = cell
        super.init()
        position = place.barrier

        let name: String
        if gate.royal {
            name = place.vertical ? "gate_v_anim" : "gate_gold_anim"
        } else if place.vertical {
            name = "gate_v_anim"
        } else {
            name = stone ? "gate_stone_anim" : "gate_anim"
        }
        frames = Sprites.strip(name)
        if let first = frames.first {
            let w = first.size().width * Sprites.scale
            let h = first.size().height * Sprites.scale
            let node = SKSpriteNode(texture: open ? frames.last : first, size: CGSize(width: w, height: h))
            node.anchorPoint = place.vertical ? CGPoint(x: 0.5, y: 0.5) : CGPoint(x: 0.5, y: 0.3)
            if gate.royal && place.vertical {
                node.color = UIColor(red: 1, green: 0.8, blue: 0.2, alpha: 1)
                node.colorBlendFactor = 0.6
            }
            addChild(node)
            barrier = node
        } else {
            let emoji = SKSpriteNode(texture: Art.emoji(gate.royal ? "🏰" : "🚧", size: 64), size: CGSize(width: 54, height: 54))
            emoji.anchorPoint = CGPoint(x: 0.5, y: 0.2)
            addChild(emoji)
            barrier = emoji
        }

        title.position = CGPoint(x: 0, y: place.vertical ? 96 : 62)
        lockLabel.position = CGPoint(x: 0, y: title.position.y - 20)
        addChild(bobbing(title, height: 3, duration: 1.3))
        addChild(lockLabel)
        refreshText()
        if gate.royal { addChild(glowSprite(UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1), size: 150, y: 20, alpha: 0.35)) }
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func label(_ text: String, size: CGFloat, color: UIColor) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: size, weight: .heavy),
            .foregroundColor: color,
            .strokeColor: UIColor.black.withAlphaComponent(0.65),
            .strokeWidth: -4
        ])
    }

    /// Подпись: куда ведут ворота и что нужно, чтобы открыть.
    func refreshText() {
        builtLanguage = Lang.shared.code
        let to = place.to.spec
        title.attributedText = label("\(to.emoji) \(to.name)", size: 14, color: .white)
        if isOpen {
            lockLabel.attributedText = label("→", size: 16, color: UIColor(red: 0.7, green: 1, blue: 0.6, alpha: 1))
        } else if gate.royal {
            lockLabel.attributedText = label("👑", size: 15, color: .white)
        } else {
            lockLabel.attributedText = label("🔒 " + tr("common.lvl", gate.level), size: 12,
                                             color: UIColor(red: 1, green: 0.85, blue: 0.4, alpha: 1))
        }
    }

    func syncLanguage() {
        if builtLanguage != Lang.shared.code { refreshText() }
    }

    func setOpen(_ open: Bool, animated: Bool) {
        guard open != isOpen else { return }
        isOpen = open
        refreshText()
        guard let barrier else { return }
        if animated, frames.count > 1 {
            barrier.run(.animate(with: open ? frames : frames.reversed(), timePerFrame: 0.08))
        } else if let tex = open ? frames.last : frames.first {
            barrier.texture = tex
        }
        if animated && open {
            Effects.scatter(Art.spark, count: 12, at: CGPoint(x: position.x, y: position.y + 20), in: parent ?? self,
                            size: 14, color: UIColor(red: 1, green: 0.9, blue: 0.5, alpha: 1), spread: 70, rise: 30, additive: true)
        }
    }

    /// Прямоугольник, через который нельзя пройти, пока ворота закрыты.
    var blockRect: CGRect {
        let p = place.barrier
        if place.vertical {
            return CGRect(x: p.x - cell * 0.5, y: p.y - cell * 2.5, width: cell, height: cell * 5)
        }
        return CGRect(x: p.x - cell * 2.5, y: p.y - cell * 0.5, width: cell * 5, height: cell)
    }

    /// Персонаж прошёл за открытые ворота к краю карты.
    func passed(_ p: CGPoint) -> Bool {
        let b = place.barrier
        let wide = cell * 2.6
        switch place.side {
        case "N": return p.y > b.y + cell * 0.6 && abs(p.x - b.x) < wide
        case "S": return p.y < b.y - cell * 0.6 && abs(p.x - b.x) < wide
        case "W": return p.x < b.x - cell * 0.6 && abs(p.y - b.y) < wide
        default: return p.x > b.x + cell * 0.6 && abs(p.y - b.y) < wide
        }
    }
}
