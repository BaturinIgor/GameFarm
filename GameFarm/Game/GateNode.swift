import SpriteKit
import UIKit

/// Ворота на краю локации: закрыты - преграда с замком, открыты - путь в соседнюю локацию.
final class GateNode: SKNode {
    let gate: GateSpec
    let place: GateLayout
    private(set) var isOpen: Bool
    private var barrier: SKSpriteNode?
    private var frames: [SKTexture] = []
    /// Табличка над воротами: качается вверх-вниз.
    private let signHolder = SKNode()
    /// Стрелка в сторону соседней локации, когда проход открыт.
    private var arrow: SKSpriteNode?
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

        signHolder.position = CGPoint(x: 0, y: place.vertical ? 92 : 60)
        signHolder.zPosition = 30
        addChild(bobbing(signHolder, height: 3, duration: 1.3))
        refreshText()
        if gate.royal { addChild(glowSprite(UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1), size: 150, y: 20, alpha: 0.35)) }
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Подпись: куда ведут ворота и что нужно, чтобы открыть.
    func refreshText() {
        builtLanguage = Lang.shared.code
        let to = place.to.spec
        let tag: SignArt.Tag
        if isOpen {
            tag = .none
        } else if gate.royal {
            tag = .royal
        } else {
            tag = .locked("🔒 " + tr("common.lvl", gate.level))
        }
        signHolder.removeAllChildren()
        signHolder.addChild(SignArt.sign(title: "\(to.emoji) \(to.name)", tag: tag, royal: gate.royal))
        refreshArrow()
    }

    /// Стрелка у открытого прохода: показывает, куда идти, и покачивается в ту сторону.
    private func refreshArrow() {
        arrow?.removeFromParent()
        arrow = nil
        guard isOpen else { return }
        let node = SignArt.arrow()
        let step: CGFloat = 7
        let dir: CGVector
        switch place.side {
        case "N":
            node.position = CGPoint(x: 0, y: 24)
            node.zRotation = .pi / 2
            dir = CGVector(dx: 0, dy: step)
        case "S":
            node.position = CGPoint(x: 0, y: -8)
            node.zRotation = -.pi / 2
            dir = CGVector(dx: 0, dy: -step)
        case "W":
            node.position = CGPoint(x: -6, y: 0)
            node.zRotation = .pi
            dir = CGVector(dx: -step, dy: 0)
        default:
            node.position = CGPoint(x: 6, y: 0)
            dir = CGVector(dx: step, dy: 0)
        }
        node.zPosition = 25
        let out = SKAction.move(by: dir, duration: 0.45)
        let back = SKAction.move(by: CGVector(dx: -dir.dx, dy: -dir.dy), duration: 0.45)
        out.timingMode = .easeInEaseOut
        back.timingMode = .easeInEaseOut
        node.run(.repeatForever(.sequence([out, back])))
        addChild(node)
        arrow = node
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

/// Деревянные таблички и стрелки для ворот, нарисованные один раз и закешированные.
enum SignArt {
    enum Tag {
        case none, royal
        case locked(String)

        var key: String {
            switch self {
            case .none: "n"
            case .royal: "r"
            case .locked(let text): "l" + text
            }
        }
    }

    nonisolated(unsafe) private static var cache: [String: (SKTexture, CGSize)] = [:]

    private static let outline = UIColor(red: 0.17, green: 0.10, blue: 0.06, alpha: 1)

    private static func font(_ size: CGFloat) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: .heavy)
        if let rounded = base.fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: rounded, size: size)
        }
        return base
    }

    private static func node(_ key: String, draw: () -> UIImage) -> SKSpriteNode {
        if let (tex, size) = cache[key] { return SKSpriteNode(texture: tex, size: size) }
        let image = draw()
        let tex = SKTexture(image: image)
        tex.filteringMode = .linear
        cache[key] = (tex, image.size)
        return SKSpriteNode(texture: tex, size: image.size)
    }

    /// Табличка: доска с гвоздиками, белая надпись с обводкой, снизу ярлык с замком или короной.
    static func sign(title: String, tag: Tag, royal: Bool) -> SKSpriteNode {
        node("sign|\(title)|\(tag.key)|\(royal)") {
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: font(14), .foregroundColor: UIColor.white,
                .strokeColor: outline, .strokeWidth: -5
            ]
            let titleSize = (title as NSString).size(withAttributes: titleAttrs)
            let plank = CGSize(width: ceil(titleSize.width) + 30, height: 30)

            var tagText = ""
            var tagFill = UIColor.clear
            var tagInk = UIColor.white
            switch tag {
            case .none: break
            case .royal:
                tagText = "👑"
                tagFill = UIColor(red: 0.97, green: 0.79, blue: 0.28, alpha: 1)
                tagInk = outline
            case .locked(let text):
                tagText = text
                tagFill = UIColor(red: 0.82, green: 0.25, blue: 0.18, alpha: 1)
            }
            let tagAttrs: [NSAttributedString.Key: Any] = [
                .font: font(11), .foregroundColor: tagInk,
                .strokeColor: tagInk == .white ? UIColor(red: 0.45, green: 0.1, blue: 0.07, alpha: 1) : UIColor.clear,
                .strokeWidth: tagInk == .white ? -4 : 0
            ]
            let tagTextSize = (tagText as NSString).size(withAttributes: tagAttrs)
            let tagSize = tagText.isEmpty ? .zero : CGSize(width: ceil(tagTextSize.width) + 18, height: 20)

            let width = max(plank.width, tagSize.width) + 6
            let height = plank.height + (tagText.isEmpty ? 0 : tagSize.height - 5) + 7
            let format = UIGraphicsImageRendererFormat()
            format.opaque = false
            return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { ctx in
                let c = ctx.cgContext
                let plankRect = CGRect(x: (width - plank.width) / 2, y: 2, width: plank.width, height: plank.height)
                let path = UIBezierPath(roundedRect: plankRect, cornerRadius: 7)

                // Жёсткая тень
                c.saveGState()
                c.translateBy(x: 0, y: 3)
                outline.withAlphaComponent(0.45).setFill()
                path.fill()
                c.restoreGState()

                // Доска с градиентом
                c.saveGState()
                path.addClip()
                let top = royal ? UIColor(red: 1, green: 0.88, blue: 0.48, alpha: 1) : UIColor(red: 0.77, green: 0.54, blue: 0.33, alpha: 1)
                let bottom = royal ? UIColor(red: 0.85, green: 0.6, blue: 0.16, alpha: 1) : UIColor(red: 0.63, green: 0.40, blue: 0.23, alpha: 1)
                if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                             colors: [top.cgColor, bottom.cgColor] as CFArray, locations: [0, 1]) {
                    c.drawLinearGradient(gradient, start: CGPoint(x: 0, y: plankRect.minY), end: CGPoint(x: 0, y: plankRect.maxY), options: [])
                }
                // Волокна дерева
                UIColor.white.withAlphaComponent(0.22).setFill()
                c.fill(CGRect(x: plankRect.minX + 4, y: plankRect.minY + 3, width: plankRect.width - 8, height: 1.5))
                outline.withAlphaComponent(0.18).setFill()
                c.fill(CGRect(x: plankRect.minX + 10, y: plankRect.midY + 5, width: plankRect.width * 0.35, height: 1))
                c.fill(CGRect(x: plankRect.midX + 6, y: plankRect.midY - 6, width: plankRect.width * 0.3, height: 1))
                c.restoreGState()

                outline.setStroke()
                path.lineWidth = 2
                path.stroke()

                // Гвоздики
                outline.withAlphaComponent(0.75).setFill()
                for x in [plankRect.minX + 6, plankRect.maxX - 8] {
                    c.fillEllipse(in: CGRect(x: x, y: plankRect.midY - 1, width: 2.5, height: 2.5))
                }

                (title as NSString).draw(at: CGPoint(x: plankRect.midX - titleSize.width / 2, y: plankRect.midY - titleSize.height / 2),
                                         withAttributes: titleAttrs)

                if !tagText.isEmpty {
                    let tagRect = CGRect(x: (width - tagSize.width) / 2, y: plankRect.maxY - 5, width: tagSize.width, height: tagSize.height)
                    let tagPath = UIBezierPath(roundedRect: tagRect, cornerRadius: tagSize.height / 2)
                    tagFill.setFill()
                    tagPath.fill()
                    outline.setStroke()
                    tagPath.lineWidth = 1.5
                    tagPath.stroke()
                    (tagText as NSString).draw(at: CGPoint(x: tagRect.midX - tagTextSize.width / 2, y: tagRect.midY - tagTextSize.height / 2),
                                               withAttributes: tagAttrs)
                }
            }
        }
    }

    /// Толстая зелёная стрелка вправо с тёмной обводкой.
    static func arrow() -> SKSpriteNode {
        node("arrow") {
            let size = CGSize(width: 36, height: 30)
            let format = UIGraphicsImageRendererFormat()
            format.opaque = false
            return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
                let c = ctx.cgContext
                let path = UIBezierPath()
                path.move(to: CGPoint(x: 3, y: 10))
                path.addLine(to: CGPoint(x: 17, y: 10))
                path.addLine(to: CGPoint(x: 17, y: 3))
                path.addLine(to: CGPoint(x: 33, y: 15))
                path.addLine(to: CGPoint(x: 17, y: 27))
                path.addLine(to: CGPoint(x: 17, y: 20))
                path.addLine(to: CGPoint(x: 3, y: 20))
                path.close()
                path.lineJoinStyle = .round

                c.saveGState()
                c.translateBy(x: 0, y: 2)
                outline.withAlphaComponent(0.45).setFill()
                path.fill()
                c.restoreGState()

                c.saveGState()
                path.addClip()
                let top = UIColor(red: 0.62, green: 0.9, blue: 0.38, alpha: 1)
                let bottom = UIColor(red: 0.27, green: 0.62, blue: 0.2, alpha: 1)
                if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                             colors: [top.cgColor, bottom.cgColor] as CFArray, locations: [0, 1]) {
                    c.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 3), end: CGPoint(x: 0, y: 27), options: [])
                }
                UIColor.white.withAlphaComponent(0.4).setFill()
                c.fill(CGRect(x: 5, y: 11.5, width: 12, height: 2))
                c.restoreGState()

                outline.setStroke()
                path.lineWidth = 2.5
                path.stroke()
            }
        }
    }
}
