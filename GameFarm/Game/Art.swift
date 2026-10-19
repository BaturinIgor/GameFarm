import SpriteKit
import UIKit

/// Картинки и текстуры, нарисованные кодом. Всё кэшируется.
enum Art {
    private static var images: [String: UIImage] = [:]
    private static var textures: [String: SKTexture] = [:]

    private static func renderer(_ size: CGSize, scale: CGFloat? = nil) -> UIGraphicsImageRenderer {
        let format = UIGraphicsImageRendererFormat.preferred()
        format.opaque = false
        if let scale { format.scale = scale }
        return UIGraphicsImageRenderer(size: size, format: format)
    }

    static func image(_ key: String, _ make: () -> UIImage) -> UIImage {
        if let cached = images[key] { return cached }
        let img = make()
        images[key] = img
        return img
    }

    static func texture(_ key: String, _ make: () -> UIImage) -> SKTexture {
        if let cached = textures[key] { return cached }
        let tex = SKTexture(image: image(key, make))
        textures[key] = tex
        return tex
    }

    // MARK: Эмодзи

    static func emojiImage(_ emoji: String, size: CGFloat) -> UIImage {
        image("emoji|\(emoji)|\(size)") {
            renderer(CGSize(width: size, height: size)).image { _ in
                let font = UIFont.systemFont(ofSize: size * 0.8)
                let text = NSAttributedString(string: emoji, attributes: [.font: font])
                let bounds = text.boundingRect(with: CGSize(width: size * 3, height: size * 3),
                                               options: [.usesLineFragmentOrigin], context: nil)
                text.draw(at: CGPoint(x: (size - bounds.width) / 2, y: (size - bounds.height) / 2))
            }
        }
    }

    static func emoji(_ emoji: String, size: CGFloat) -> SKTexture {
        let px = (size / 8).rounded(.up) * 8
        return texture("emojiTex|\(emoji)|\(px)") { emojiImage(emoji, size: px) }
    }

    // MARK: Иконки ресурсов

    static func icon(_ kind: ResourceKind) -> UIImage {
        if let e = kind.emoji { return emojiImage(e, size: 64) }
        if kind == .crystal { return crystalImage(size: 64) }
        return oreImage(kind.oreColor, size: 64)
    }

    static func iconTexture(_ kind: ResourceKind) -> SKTexture {
        texture("iconTex|\(kind.rawValue)") { icon(kind) }
    }

    // MARK: Руды и кристаллы

    private static func rockPath(in rect: CGRect) -> UIBezierPath {
        let points: [(CGFloat, CGFloat)] = [
            (0.12, 0.62), (0.2, 0.28), (0.42, 0.1), (0.66, 0.14), (0.88, 0.34), (0.95, 0.66), (0.78, 0.92), (0.3, 0.94)
        ]
        let path = UIBezierPath()
        for (i, p) in points.enumerated() {
            let pt = CGPoint(x: rect.minX + p.0 * rect.width, y: rect.minY + p.1 * rect.height)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.close()
        path.lineJoinStyle = .round
        return path
    }

    static func oreImage(_ color: UIColor, size: CGFloat, plain: Bool = false) -> UIImage {
        image("ore|\(color.description)|\(size)|\(plain)") {
            renderer(CGSize(width: size, height: size)).image { ctx in
                let c = ctx.cgContext
                let rect = CGRect(x: size * 0.06, y: size * 0.14, width: size * 0.88, height: size * 0.78)
                let path = rockPath(in: rect)
                UIColor(white: 0.52, alpha: 1).setFill()
                path.fill()
                c.saveGState()
                path.addClip()
                UIColor(white: 0.66, alpha: 1).setFill()
                UIBezierPath(ovalIn: CGRect(x: rect.minX - size * 0.1, y: rect.minY - size * 0.3,
                                            width: rect.width * 0.95, height: rect.height * 0.8)).fill()
                UIColor(white: 0.38, alpha: 1).setFill()
                UIBezierPath(ovalIn: CGRect(x: rect.minX + rect.width * 0.35, y: rect.minY + rect.height * 0.6,
                                            width: rect.width, height: rect.height)).fill()
                c.restoreGState()
                UIColor(white: 0.24, alpha: 1).setStroke()
                path.lineWidth = size * 0.035
                path.stroke()
                guard !plain else { return }
                let specks: [(CGFloat, CGFloat, CGFloat)] = [
                    (0.32, 0.42, 0.11), (0.6, 0.34, 0.09), (0.5, 0.62, 0.12), (0.74, 0.6, 0.08), (0.28, 0.7, 0.07)
                ]
                for (x, y, r) in specks {
                    let cx = size * x, cy = size * y, rr = size * r
                    let gem = UIBezierPath()
                    gem.move(to: CGPoint(x: cx, y: cy - rr))
                    gem.addLine(to: CGPoint(x: cx + rr, y: cy))
                    gem.addLine(to: CGPoint(x: cx, y: cy + rr))
                    gem.addLine(to: CGPoint(x: cx - rr, y: cy))
                    gem.close()
                    color.setFill()
                    gem.fill()
                    UIColor.white.withAlphaComponent(0.55).setFill()
                    UIBezierPath(ovalIn: CGRect(x: cx - rr * 0.45, y: cy - rr * 0.55, width: rr * 0.5, height: rr * 0.4)).fill()
                    UIColor.black.withAlphaComponent(0.35).setStroke()
                    gem.lineWidth = size * 0.012
                    gem.stroke()
                }
            }
        }
    }

    static func crystalImage(size: CGFloat) -> UIImage {
        image("crystal|\(size)") {
            renderer(CGSize(width: size, height: size)).image { _ in
                let shards: [(CGFloat, CGFloat, CGFloat, CGFloat, UIColor)] = [
                    (0.3, 0.86, 0.16, 0.5, UIColor(red: 0.62, green: 0.4, blue: 0.98, alpha: 1)),
                    (0.68, 0.88, 0.15, 0.46, UIColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 1)),
                    (0.5, 0.9, 0.2, 0.74, UIColor(red: 0.78, green: 0.5, blue: 1.0, alpha: 1))
                ]
                UIColor(white: 0.3, alpha: 0.6).setFill()
                UIBezierPath(ovalIn: CGRect(x: size * 0.14, y: size * 0.8, width: size * 0.72, height: size * 0.16)).fill()
                for (x, bottom, w, h, color) in shards {
                    let cx = size * x, by = size * bottom, hw = size * w / 2, hh = size * h
                    let top = CGPoint(x: cx, y: by - hh)
                    let shard = UIBezierPath()
                    shard.move(to: CGPoint(x: cx - hw, y: by))
                    shard.addLine(to: CGPoint(x: cx - hw, y: by - hh * 0.72))
                    shard.addLine(to: top)
                    shard.addLine(to: CGPoint(x: cx + hw, y: by - hh * 0.72))
                    shard.addLine(to: CGPoint(x: cx + hw, y: by))
                    shard.close()
                    color.setFill()
                    shard.fill()
                    let light = UIBezierPath()
                    light.move(to: CGPoint(x: cx - hw, y: by))
                    light.addLine(to: CGPoint(x: cx - hw, y: by - hh * 0.72))
                    light.addLine(to: top)
                    light.addLine(to: CGPoint(x: cx, y: by))
                    light.close()
                    UIColor.white.withAlphaComponent(0.35).setFill()
                    light.fill()
                    UIColor(red: 0.2, green: 0.1, blue: 0.35, alpha: 0.7).setStroke()
                    shard.lineWidth = size * 0.02
                    shard.lineJoinStyle = .round
                    shard.stroke()
                }
            }
        }
    }

    // MARK: Мелкие детали

    static var shadow: SKTexture {
        texture("shadow") {
            renderer(CGSize(width: 64, height: 24)).image { _ in
                UIColor.black.setFill()
                UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 64, height: 24)).fill()
            }
        }
    }

    static func stump(_ tint: UIColor = UIColor(red: 0.55, green: 0.36, blue: 0.2, alpha: 1)) -> SKTexture {
        texture("stump|\(tint.description)") {
            renderer(CGSize(width: 40, height: 30)).image { _ in
                tint.withAlphaComponent(1).setFill()
                UIBezierPath(roundedRect: CGRect(x: 6, y: 10, width: 28, height: 16), cornerRadius: 4).fill()
                UIColor(red: 0.85, green: 0.68, blue: 0.45, alpha: 1).setFill()
                UIBezierPath(ovalIn: CGRect(x: 6, y: 4, width: 28, height: 12)).fill()
                UIColor(red: 0.6, green: 0.42, blue: 0.25, alpha: 1).setStroke()
                let ring = UIBezierPath(ovalIn: CGRect(x: 12, y: 6.5, width: 16, height: 7))
                ring.lineWidth = 1.4
                ring.stroke()
            }
        }
    }

    static func rubble(_ color: UIColor) -> SKTexture {
        texture("rubble|\(color.description)") {
            renderer(CGSize(width: 44, height: 26)).image { _ in
                let pieces: [CGRect] = [
                    CGRect(x: 4, y: 10, width: 14, height: 11), CGRect(x: 16, y: 6, width: 13, height: 12),
                    CGRect(x: 27, y: 11, width: 12, height: 10), CGRect(x: 12, y: 15, width: 10, height: 8)
                ]
                for r in pieces {
                    color.setFill()
                    UIBezierPath(ovalIn: r).fill()
                    UIColor.white.withAlphaComponent(0.25).setFill()
                    UIBezierPath(ovalIn: r.insetBy(dx: r.width * 0.3, dy: r.height * 0.3).offsetBy(dx: -2, dy: -2)).fill()
                }
            }
        }
    }

    static var dirt: SKTexture {
        texture("dirt") {
            renderer(CGSize(width: 34, height: 16)).image { _ in
                UIColor(red: 0.45, green: 0.32, blue: 0.2, alpha: 0.55).setFill()
                UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 34, height: 16)).fill()
            }
        }
    }

    static var ripple: SKTexture {
        texture("ripple") {
            renderer(CGSize(width: 60, height: 30)).image { _ in
                UIColor.white.withAlphaComponent(0.75).setStroke()
                for i in 0..<3 {
                    let inset = CGFloat(i) * 9
                    let p = UIBezierPath(ovalIn: CGRect(x: inset, y: inset / 2, width: 60 - inset * 2, height: 30 - inset))
                    p.lineWidth = 2
                    p.stroke()
                }
            }
        }
    }

    static var iceHole: SKTexture {
        texture("iceHole") {
            renderer(CGSize(width: 54, height: 30)).image { _ in
                UIColor.white.setFill()
                UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 54, height: 30)).fill()
                UIColor(red: 0.12, green: 0.35, blue: 0.6, alpha: 1).setFill()
                UIBezierPath(ovalIn: CGRect(x: 6, y: 5, width: 42, height: 20)).fill()
                UIColor.white.withAlphaComponent(0.4).setFill()
                UIBezierPath(ovalIn: CGRect(x: 14, y: 8, width: 14, height: 5)).fill()
            }
        }
    }

    static var glow: SKTexture {
        texture("glow") {
            renderer(CGSize(width: 64, height: 64)).image { ctx in
                let colors = [UIColor.white.withAlphaComponent(0.9).cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
                let space = CGColorSpaceCreateDeviceRGB()
                if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) {
                    ctx.cgContext.drawRadialGradient(gradient, startCenter: CGPoint(x: 32, y: 32), startRadius: 0,
                                                     endCenter: CGPoint(x: 32, y: 32), endRadius: 32, options: [])
                }
            }
        }
    }

    static var arrow: SKTexture {
        texture("arrow") {
            renderer(CGSize(width: 40, height: 40)).image { _ in
                let p = UIBezierPath()
                p.move(to: CGPoint(x: 38, y: 20))
                p.addLine(to: CGPoint(x: 8, y: 4))
                p.addLine(to: CGPoint(x: 15, y: 20))
                p.addLine(to: CGPoint(x: 8, y: 36))
                p.close()
                UIColor.white.setFill()
                p.fill()
            }
        }
    }

    static var darkness: SKTexture {
        texture("darkness") {
            let s: CGFloat = 512
            return renderer(CGSize(width: s, height: s), scale: 1).image { ctx in
                let colors = [UIColor.black.withAlphaComponent(0).cgColor,
                              UIColor.black.withAlphaComponent(0.35).cgColor,
                              UIColor.black.withAlphaComponent(0.72).cgColor] as CFArray
                let space = CGColorSpaceCreateDeviceRGB()
                if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.45, 1]) {
                    let center = CGPoint(x: s / 2, y: s / 2)
                    ctx.cgContext.drawRadialGradient(gradient, startCenter: center, startRadius: s * 0.06,
                                                     endCenter: center, endRadius: s * 0.24,
                                                     options: [.drawsAfterEndLocation])
                }
            }
        }
    }
}
