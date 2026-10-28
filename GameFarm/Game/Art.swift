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
        if let pixel = Sprites.icon(kind) { return pixel }
        if let e = kind.emoji { return emojiImage(e, size: 64) }
        switch kind {
        case .crystal: return crystalImage(size: 64)
        case .ruby, .obsidian: return gemImage(kind.oreColor, size: 64)
        case .pearl: return pearlImage(size: 64)
        case .goldenApple: return tintedEmoji("🍎", tint: kind.oreColor, amount: 0.6, size: 64)
        default: return oreImage(kind.oreColor, size: 64)
        }
    }

    /// Эмодзи, перекрашенный в заданный цвет с сохранением объёма.
    static func tintedEmoji(_ emoji: String, tint: UIColor, amount: CGFloat, size: CGFloat) -> UIImage {
        image("tinted|\(emoji)|\(tint.description)|\(amount)|\(size)") {
            let base = emojiImage(emoji, size: size)
            return renderer(CGSize(width: size, height: size)).image { ctx in
                let rect = CGRect(x: 0, y: 0, width: size, height: size)
                base.draw(in: rect)
                ctx.cgContext.setBlendMode(.sourceAtop)
                tint.withAlphaComponent(amount).setFill()
                ctx.cgContext.fill(rect)
                ctx.cgContext.setBlendMode(.normal)
                UIColor.white.withAlphaComponent(0.45).setFill()
                UIBezierPath(ovalIn: CGRect(x: size * 0.3, y: size * 0.28, width: size * 0.16, height: size * 0.12)).fill()
            }
        }
    }

    static func tintedEmojiTexture(_ emoji: String, tint: UIColor, amount: CGFloat, size: CGFloat) -> SKTexture {
        let px = (size / 8).rounded(.up) * 8
        return texture("tintedTex|\(emoji)|\(tint.description)|\(amount)|\(px)") {
            tintedEmoji(emoji, tint: tint, amount: amount, size: px)
        }
    }

    /// Огранённый камень: рубин, обсидиан.
    static func gemImage(_ color: UIColor, size: CGFloat) -> UIImage {
        image("gem|\(color.description)|\(size)") {
            renderer(CGSize(width: size, height: size)).image { _ in
                let s = size
                let top: [CGPoint] = [
                    CGPoint(x: s * 0.2, y: s * 0.36), CGPoint(x: s * 0.34, y: s * 0.2),
                    CGPoint(x: s * 0.66, y: s * 0.2), CGPoint(x: s * 0.8, y: s * 0.36)
                ]
                let bottom = CGPoint(x: s * 0.5, y: s * 0.86)
                let outline = UIBezierPath()
                outline.move(to: top[0])
                for p in top.dropFirst() { outline.addLine(to: p) }
                outline.addLine(to: bottom)
                outline.close()
                color.setFill()
                outline.fill()
                // Грани
                let left = UIBezierPath()
                left.move(to: top[0]); left.addLine(to: CGPoint(x: s * 0.42, y: s * 0.36)); left.addLine(to: bottom); left.close()
                UIColor.white.withAlphaComponent(0.25).setFill()
                left.fill()
                let right = UIBezierPath()
                right.move(to: top[3]); right.addLine(to: CGPoint(x: s * 0.58, y: s * 0.36)); right.addLine(to: bottom); right.close()
                UIColor.black.withAlphaComponent(0.25).setFill()
                right.fill()
                let crown = UIBezierPath()
                crown.move(to: top[1]); crown.addLine(to: top[2]); crown.addLine(to: CGPoint(x: s * 0.58, y: s * 0.36))
                crown.addLine(to: CGPoint(x: s * 0.42, y: s * 0.36)); crown.close()
                UIColor.white.withAlphaComponent(0.45).setFill()
                crown.fill()
                UIColor.black.withAlphaComponent(0.45).setStroke()
                outline.lineWidth = s * 0.03
                outline.lineJoinStyle = .round
                outline.stroke()
            }
        }
    }

    static func pearlImage(size: CGFloat) -> UIImage {
        image("pearl|\(size)") {
            renderer(CGSize(width: size, height: size)).image { ctx in
                let rect = CGRect(x: size * 0.18, y: size * 0.18, width: size * 0.64, height: size * 0.64)
                let colors = [UIColor.white.cgColor,
                              UIColor(red: 0.93, green: 0.88, blue: 0.95, alpha: 1).cgColor,
                              UIColor(red: 0.78, green: 0.72, blue: 0.86, alpha: 1).cgColor] as CFArray
                let space = CGColorSpaceCreateDeviceRGB()
                ctx.cgContext.saveGState()
                UIBezierPath(ovalIn: rect).addClip()
                if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.5, 1]) {
                    ctx.cgContext.drawRadialGradient(gradient, startCenter: CGPoint(x: rect.minX + rect.width * 0.35, y: rect.minY + rect.height * 0.3),
                                                     startRadius: 0, endCenter: CGPoint(x: rect.midX, y: rect.midY),
                                                     endRadius: rect.width * 0.6, options: [.drawsAfterEndLocation])
                }
                ctx.cgContext.restoreGState()
                UIColor(white: 0.5, alpha: 0.5).setStroke()
                let ring = UIBezierPath(ovalIn: rect)
                ring.lineWidth = size * 0.02
                ring.stroke()
            }
        }
    }

    static var clay: SKTexture {
        texture("clayMound") {
            renderer(CGSize(width: 64, height: 40)).image { _ in
                UIColor(red: 0.6, green: 0.34, blue: 0.22, alpha: 1).setFill()
                UIBezierPath(ovalIn: CGRect(x: 2, y: 10, width: 60, height: 28)).fill()
                UIColor(red: 0.78, green: 0.47, blue: 0.3, alpha: 1).setFill()
                UIBezierPath(ovalIn: CGRect(x: 8, y: 6, width: 48, height: 24)).fill()
                UIColor(red: 0.88, green: 0.6, blue: 0.42, alpha: 1).setFill()
                UIBezierPath(ovalIn: CGRect(x: 16, y: 8, width: 22, height: 9)).fill()
            }
        }
    }

    static var puff: SKTexture {
        texture("puff") {
            renderer(CGSize(width: 32, height: 32)).image { ctx in
                let colors = [UIColor.white.withAlphaComponent(0.8).cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
                if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.2, 1]) {
                    ctx.cgContext.drawRadialGradient(gradient, startCenter: CGPoint(x: 16, y: 16), startRadius: 0,
                                                     endCenter: CGPoint(x: 16, y: 16), endRadius: 16, options: [])
                }
            }
        }
    }

    static var dot: SKTexture {
        texture("dot") {
            renderer(CGSize(width: 16, height: 16)).image { _ in
                UIColor.white.setFill()
                UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 16, height: 16)).fill()
            }
        }
    }

    static var spark: SKTexture {
        texture("spark") {
            renderer(CGSize(width: 24, height: 24)).image { _ in
                let p = UIBezierPath()
                p.move(to: CGPoint(x: 12, y: 0))
                p.addQuadCurve(to: CGPoint(x: 24, y: 12), controlPoint: CGPoint(x: 13.5, y: 10.5))
                p.addQuadCurve(to: CGPoint(x: 12, y: 24), controlPoint: CGPoint(x: 13.5, y: 13.5))
                p.addQuadCurve(to: CGPoint(x: 0, y: 12), controlPoint: CGPoint(x: 10.5, y: 13.5))
                p.addQuadCurve(to: CGPoint(x: 12, y: 0), controlPoint: CGPoint(x: 10.5, y: 10.5))
                UIColor.white.setFill()
                p.fill()
            }
        }
    }

    static var cloudShadow: SKTexture {
        texture("cloudShadow") {
            renderer(CGSize(width: 256, height: 160), scale: 1).image { ctx in
                let colors = [UIColor.black.cgColor, UIColor.black.withAlphaComponent(0).cgColor] as CFArray
                guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return }
                let blobs: [(CGFloat, CGFloat, CGFloat)] = [(90, 80, 70), (150, 70, 60), (125, 100, 55), (180, 95, 45)]
                for (x, y, r) in blobs {
                    ctx.cgContext.drawRadialGradient(gradient, startCenter: CGPoint(x: x, y: y), startRadius: 0,
                                                     endCenter: CGPoint(x: x, y: y), endRadius: r, options: [])
                }
            }
        }
    }

    static func iconTexture(_ kind: ResourceKind) -> SKTexture {
        let tex = texture("iconTex|\(kind.rawValue)") { icon(kind) }
        if Sprites.icon(kind) != nil { tex.filteringMode = .nearest }
        return tex
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
