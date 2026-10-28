import SpriteKit
import UIKit

/// Карта текущей локации: форма земли, вода, тропы, ресурсы, склад и проходы.
/// Рисуется один раз на локацию и кешируется, поэтому почти ничего не стоит.
enum MiniMap {
    /// Пикселей картинки на одну клетку.
    static let pixelsPerCell: CGFloat = 6
    /// Толщина деревянной рамки в пикселях картинки.
    static let border: CGFloat = 10

    nonisolated(unsafe) private static var cache: [String: UIImage] = [:]

    /// Цвет точки ресурса: деревья зелёные, руда своего цвета, рыба голубая, ягоды и прочее красное.
    static func dotColor(_ type: NodeType) -> UIColor {
        let spec = type.spec
        if type == .treasureChest { return UIColor(red: 1, green: 0.82, blue: 0.2, alpha: 1) }
        if Events.points(for: type) > 1 { return UIColor(red: 1, green: 0.55, blue: 0.1, alpha: 1) }
        switch spec.tool {
        case .axe: return UIColor(red: 0.12, green: 0.42, blue: 0.15, alpha: 1)
        case .pickaxe:
            switch spec.mainResource {
            case .stone, .clay: return UIColor(white: 0.62, alpha: 1)
            case .ice: return UIColor(red: 0.75, green: 0.92, blue: 1, alpha: 1)
            case .diamond: return UIColor(red: 0.45, green: 0.9, blue: 1, alpha: 1)
            case .crystal: return UIColor(red: 0.85, green: 0.55, blue: 1, alpha: 1)
            case .ruby: return UIColor(red: 0.95, green: 0.2, blue: 0.3, alpha: 1)
            default: return spec.mainResource.oreColor
            }
        case .rod: return UIColor(red: 0.6, green: 0.88, blue: 1, alpha: 1)
        case .hand: return UIColor(red: 0.95, green: 0.35, blue: 0.45, alpha: 1)
        case .sword, .armor, .helmet, .boots: return .white
        }
    }

    static func image(_ id: LocationID, framed: Bool) -> UIImage {
        let key = "\(LocationLayout.resourceName(id))|\(framed)"
        if let cached = cache[key] { return cached }
        let image = render(id.layout, id.spec, framed: framed)
        cache[key] = image
        return image
    }

    private static func render(_ layout: LocationLayout, _ spec: LocationSpec, framed: Bool) -> UIImage {
        let ppc = pixelsPerCell
        let b: CGFloat = framed ? border : 0
        let mapW = CGFloat(layout.cols) * ppc
        let mapH = CGFloat(layout.rows) * ppc
        let size = CGSize(width: mapW + b * 2, height: mapH + b * 2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        let edgeColor: UIColor
        switch layout.edge {
        case "sea", "lava": edgeColor = spec.water
        case "void": edgeColor = spec.dark ? UIColor(white: 0.05, alpha: 1) : UIColor(red: 0.7, green: 0.85, blue: 1, alpha: 1)
        default: edgeColor = darker(spec.ground, 0.62)
        }
        let land = lighter(spec.ground, 0.06)
        let forest = darker(spec.ground, 0.62)
        let ice = UIColor(red: 0.82, green: 0.93, blue: 1, alpha: 1)
        let outline = UIColor(red: 0.17, green: 0.10, blue: 0.06, alpha: 1)

        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let c = ctx.cgContext
            let mapRect = CGRect(x: b, y: b, width: mapW, height: mapH)
            let radius: CGFloat = framed ? 14 : 0

            if framed {
                // Рамка: тень, дерево, обводка
                let outer = UIBezierPath(roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1), cornerRadius: radius + b * 0.6)
                UIColor(red: 0.63, green: 0.40, blue: 0.23, alpha: 1).setFill()
                outer.fill()
                UIColor.white.withAlphaComponent(0.18).setFill()
                c.fill(CGRect(x: b * 0.6, y: 3, width: size.width - b * 1.2, height: 2))
                outline.setStroke()
                outer.lineWidth = 3
                outer.stroke()
            }

            c.saveGState()
            UIBezierPath(roundedRect: mapRect, cornerRadius: radius).addClip()
            edgeColor.setFill()
            c.fill(mapRect)
            for r in 0..<layout.rows {
                for col in 0..<layout.cols {
                    let color: UIColor
                    switch layout.at(col, r) {
                    case .land: color = land
                    case .path: color = spec.path
                    case .water: color = spec.water
                    case .ice: color = ice
                    case .blocked: color = forest
                    case .void: continue
                    }
                    color.setFill()
                    c.fill(CGRect(x: b + CGFloat(col) * ppc, y: b + CGFloat(r) * ppc, width: ppc, height: ppc))
                }
            }

            func point(_ p: CGPoint) -> CGPoint {
                CGPoint(x: b + p.x / layout.cell * ppc, y: b + (CGFloat(layout.rows) - p.y / layout.cell) * ppc)
            }

            // Огород и лавка
            UIColor(red: 0.72, green: 0.45, blue: 0.3, alpha: 1).setFill()
            for bed in layout.farm {
                let p = point(bed)
                c.fill(CGRect(x: p.x - ppc * 0.4, y: p.y - ppc * 0.4, width: ppc * 0.8, height: ppc * 0.8))
            }
            if let pen = layout.pen {
                let a = point(CGPoint(x: pen.minX, y: pen.maxY))
                let b = point(CGPoint(x: pen.maxX, y: pen.minY))
                let r = CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y).insetBy(dx: 1, dy: 1)
                UIColor(red: 0.55, green: 0.36, blue: 0.2, alpha: 1).setStroke()
                c.setLineWidth(2)
                c.stroke(r)
            }
            if let stall = layout.stall {
                let p = point(stall)
                let w = ppc * 2.2
                let awning = CGRect(x: p.x - w / 2, y: p.y - w * 0.9, width: w, height: w * 0.5)
                UIColor(red: 0.95, green: 0.35, blue: 0.35, alpha: 1).setFill()
                c.fill(awning)
                UIColor.white.setFill()
                c.fill(CGRect(x: awning.minX + w * 0.33, y: awning.minY, width: w * 0.33, height: awning.height))
                outline.setStroke()
                c.setLineWidth(1.5)
                c.stroke(awning)
            }

            // Ресурсы
            let dot = ppc * 1.15
            for spot in layout.spots {
                let p = point(spot.position)
                let rect = CGRect(x: p.x - dot / 2, y: p.y - dot / 2, width: dot, height: dot)
                outline.withAlphaComponent(0.85).setFill()
                c.fillEllipse(in: rect.insetBy(dx: -1.5, dy: -1.5))
                dotColor(spot.type).setFill()
                c.fillEllipse(in: rect)
            }

            // Проходы: золотые ромбы
            for gate in layout.gates {
                let p = point(gate.barrier)
                let s = ppc * 1.4
                let diamond = UIBezierPath()
                diamond.move(to: CGPoint(x: p.x, y: p.y - s))
                diamond.addLine(to: CGPoint(x: p.x + s, y: p.y))
                diamond.addLine(to: CGPoint(x: p.x, y: p.y + s))
                diamond.addLine(to: CGPoint(x: p.x - s, y: p.y))
                diamond.close()
                UIColor(red: 1, green: 0.83, blue: 0.25, alpha: 1).setFill()
                diamond.fill()
                outline.setStroke()
                diamond.lineWidth = 1.5
                diamond.stroke()
            }

            // Склад: домик
            let home = point(layout.base)
            let w = ppc * 2.6
            let body = CGRect(x: home.x - w / 2, y: home.y - w * 0.3, width: w, height: w * 0.75)
            let roof = UIBezierPath()
            roof.move(to: CGPoint(x: home.x - w * 0.62, y: body.minY + 1))
            roof.addLine(to: CGPoint(x: home.x, y: body.minY - w * 0.55))
            roof.addLine(to: CGPoint(x: home.x + w * 0.62, y: body.minY + 1))
            roof.close()
            let bodyPath = UIBezierPath(rect: body)
            UIColor(red: 0.98, green: 0.93, blue: 0.82, alpha: 1).setFill()
            bodyPath.fill()
            outline.setStroke()
            bodyPath.lineWidth = 1.5
            bodyPath.stroke()
            UIColor(red: 0.82, green: 0.25, blue: 0.18, alpha: 1).setFill()
            roof.fill()
            roof.lineWidth = 1.5
            roof.stroke()
            c.restoreGState()

            if framed {
                outline.setStroke()
                let inner = UIBezierPath(roundedRect: mapRect, cornerRadius: radius)
                inner.lineWidth = 2
                inner.stroke()
            }
        }
    }

    private static func darker(_ color: UIColor, _ k: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: r * k, green: g * k, blue: b * k, alpha: 1)
    }

    private static func lighter(_ color: UIColor, _ k: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: r + (1 - r) * k, green: g + (1 - g) * k, blue: b + (1 - b) * k, alpha: 1)
    }
}

/// Мини-карта в углу экрана. Двигается только точка персонажа.
final class MiniMapNode: SKNode {
    private let map = SKSpriteNode()
    private let dot = SKSpriteNode()
    private var mapOrigin = CGPoint.zero
    private var pointsPerCell: CGFloat = 1
    private var cell: CGFloat = 32
    private(set) var size = CGSize.zero

    static let maxSize = CGSize(width: 82, height: 104)

    override init() {
        super.init()
        addChild(map)
        dot.texture = MiniMapNode.dotTexture
        dot.size = CGSize(width: 9, height: 9)
        dot.zPosition = 2
        let grow = SKAction.scale(to: 1.3, duration: 0.5)
        let shrink = SKAction.scale(to: 1, duration: 0.5)
        grow.timingMode = .easeInEaseOut
        shrink.timingMode = .easeInEaseOut
        dot.run(.repeatForever(.sequence([grow, shrink])))
        map.addChild(dot)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private static let dotTexture: SKTexture = {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: CGSize(width: 18, height: 18), format: format).image { ctx in
            let c = ctx.cgContext
            UIColor(red: 0.17, green: 0.10, blue: 0.06, alpha: 1).setFill()
            c.fillEllipse(in: CGRect(x: 1, y: 1, width: 16, height: 16))
            UIColor.white.setFill()
            c.fillEllipse(in: CGRect(x: 3.5, y: 3.5, width: 11, height: 11))
            UIColor(red: 0.2, green: 0.6, blue: 1, alpha: 1).setFill()
            c.fillEllipse(in: CGRect(x: 6, y: 6, width: 6, height: 6))
        }
        return SKTexture(image: image)
    }()

    func configure(_ id: LocationID) {
        let layout = id.layout
        let image = MiniMap.image(id, framed: true)
        let k = min(Self.maxSize.width / CGFloat(layout.cols), Self.maxSize.height / CGFloat(layout.rows))
        let border = MiniMap.border / MiniMap.pixelsPerCell * k
        size = CGSize(width: CGFloat(layout.cols) * k + border * 2, height: CGFloat(layout.rows) * k + border * 2)
        let tex = SKTexture(image: image)
        tex.filteringMode = .linear
        map.texture = tex
        map.size = size
        pointsPerCell = k
        cell = layout.cell
        // Левый нижний угол самой карты внутри рамки, относительно центра спрайта.
        mapOrigin = CGPoint(x: -size.width / 2 + border, y: -size.height / 2 + border)
    }

    func update(player: CGPoint) {
        dot.position = CGPoint(x: mapOrigin.x + player.x / cell * pointsPerCell,
                               y: mapOrigin.y + player.y / cell * pointsPerCell)
    }

    /// Прямоугольник мини-карты в координатах камеры.
    var frameRect: CGRect {
        CGRect(x: position.x - size.width / 2, y: position.y - size.height / 2, width: size.width, height: size.height)
    }
}
