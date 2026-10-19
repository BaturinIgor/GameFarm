import SpriteKit
import UIKit

/// Детерминированный генератор: одна и та же локация всегда выглядит одинаково,
/// а ресурсы появляются на тех же местах.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &* 0x9E3779B97F4A7C15 &+ 0x2545F4914F6CDD1D
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> CGFloat {
        CGFloat(Double(next() >> 11) / Double(1 << 53))
    }

    mutating func range(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        a + (b - a) * unit()
    }

    mutating func pick<T>(_ items: [T]) -> T {
        items[Int(next() % UInt64(items.count))]
    }
}

struct SpotPlacement {
    let type: NodeType
    let position: CGPoint
}

struct DecorPlacement {
    let emoji: String
    let position: CGPoint
    let size: CGFloat
    let alpha: CGFloat
}

func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
    hypot(a.x - b.x, a.y - b.y)
}

enum WorldLayout {
    static let baseClearance: CGFloat = 175

    static func spots(_ spec: LocationSpec) -> [SpotPlacement] {
        var rng = SeededRNG(seed: spec.seed)
        var placed: [SpotPlacement] = []
        let w = spec.size.width, h = spec.size.height
        let base = spec.basePoint

        for cluster in spec.clusters {
            let node = cluster.node.spec
            let center = spec.point(cluster.x, cluster.y)
            var made = 0
            var attempts = 0
            while made < cluster.count && attempts < cluster.count * 80 {
                attempts += 1
                let angle = rng.range(0, .pi * 2)
                var p: CGPoint
                if let index = cluster.pond, index < spec.ponds.count {
                    let pond = spec.ponds[index]
                    let pc = spec.point(pond.x, pond.y)
                    let r = pond.frozen ? sqrt(rng.unit()) * pond.radius * 0.78 : pond.radius - 26
                    p = CGPoint(x: pc.x + cos(angle) * r, y: pc.y + sin(angle) * r)
                } else {
                    let r = sqrt(rng.unit()) * cluster.radius
                    p = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
                    let inPond = spec.ponds.contains { pond in
                        distance(p, spec.point(pond.x, pond.y)) < pond.radius + node.radius + 18
                    }
                    if inPond { continue }
                }
                guard p.x > 70, p.x < w - 70, p.y > 80, p.y < h - 70 else { continue }
                if distance(p, base) < baseClearance { continue }
                let crowded = placed.contains { other in
                    let gap = max(48, other.type.spec.radius + node.radius + 24)
                    return distance(other.position, p) < gap
                }
                if crowded { continue }
                placed.append(SpotPlacement(type: cluster.node, position: p))
                made += 1
            }
        }
        return placed
    }

    static func decorations(_ spec: LocationSpec, avoiding spots: [SpotPlacement]) -> [DecorPlacement] {
        var rng = SeededRNG(seed: spec.seed &+ 999)
        var out: [DecorPlacement] = []
        let w = spec.size.width, h = spec.size.height
        var attempts = 0
        while out.count < spec.decorCount && attempts < spec.decorCount * 10 {
            attempts += 1
            let p = CGPoint(x: rng.range(40, w - 40), y: rng.range(40, h - 40))
            if spots.contains(where: { distance($0.position, p) < 34 }) { continue }
            let wet = spec.ponds.contains { distance(p, spec.point($0.x, $0.y)) < $0.radius + 12 }
            if wet && !spec.ponds.contains(where: { $0.frozen }) { continue }
            if distance(p, spec.basePoint) < 120 { continue }
            out.append(DecorPlacement(emoji: rng.pick(spec.decor), position: p,
                                      size: rng.range(14, 22), alpha: rng.range(0.7, 1)))
        }
        return out
    }

    /// Деревья и камни по краю карты, чтобы мир не обрывался.
    static func border(_ spec: LocationSpec) -> [DecorPlacement] {
        var rng = SeededRNG(seed: spec.seed &+ 4242)
        var out: [DecorPlacement] = []
        let w = spec.size.width, h = spec.size.height
        let step: CGFloat = 46
        var x: CGFloat = -10
        while x <= w + 10 {
            out.append(DecorPlacement(emoji: rng.pick(spec.border), position: CGPoint(x: x, y: rng.range(-14, 6)), size: rng.range(56, 72), alpha: 1))
            out.append(DecorPlacement(emoji: rng.pick(spec.border), position: CGPoint(x: x, y: h + rng.range(-6, 14)), size: rng.range(56, 72), alpha: 1))
            x += step + rng.range(-8, 8)
        }
        var y: CGFloat = 30
        while y <= h - 20 {
            out.append(DecorPlacement(emoji: rng.pick(spec.border), position: CGPoint(x: rng.range(-14, 6), y: y), size: rng.range(56, 72), alpha: 1))
            out.append(DecorPlacement(emoji: rng.pick(spec.border), position: CGPoint(x: w + rng.range(-6, 14), y: y), size: rng.range(56, 72), alpha: 1))
            y += step + rng.range(-8, 8)
        }
        return out
    }
}

enum WorldArt {
    static let scale: CGFloat = 1.5

    private static func softBlob(_ c: CGContext, center: CGPoint, radius: CGFloat, color: UIColor, squash: CGFloat = 0.7) {
        let colors = [color.cgColor, color.withAlphaComponent(0).cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.35, 1]) else { return }
        c.saveGState()
        c.translateBy(x: center.x, y: center.y)
        c.scaleBy(x: 1, y: squash)
        c.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: radius, options: [])
        c.restoreGState()
    }

    private static func isGreen(_ color: UIColor) -> Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return g > r + 0.08 && g > b + 0.05
    }

    /// Рисует землю локации одной картинкой. Координаты UIKit перевёрнуты относительно SpriteKit.
    static func ground(_ spec: LocationSpec, spots: [SpotPlacement]) -> UIImage {
        let size = spec.size
        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = scale
        format.opaque = true
        var rng = SeededRNG(seed: spec.seed &+ 7)
        func flip(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: size.height - p.y) }
        let green = isGreen(spec.ground)

        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let c = ctx.cgContext
            spec.ground.setFill()
            c.fill(CGRect(origin: .zero, size: size))

            // Мягкие пятна разных оттенков
            for _ in 0..<260 {
                let color = rng.pick(spec.patches).withAlphaComponent(rng.range(0.45, 0.85))
                let p = CGPoint(x: rng.range(-60, size.width + 60), y: rng.range(-60, size.height + 60))
                softBlob(c, center: p, radius: rng.range(50, 190), color: color, squash: rng.range(0.55, 0.85))
            }

            // Тропинки от склада к группам ресурсов
            let base = flip(spec.basePoint)
            c.setLineCap(.round)
            c.setLineJoin(.round)
            var seenCenters: [CGPoint] = []
            for cluster in spec.clusters where cluster.pond == nil {
                let target = flip(spec.point(cluster.x, cluster.y))
                if seenCenters.contains(where: { distance($0, target) < 120 }) { continue }
                seenCenters.append(target)
                let mid = CGPoint(x: (base.x + target.x) / 2 + rng.range(-120, 120), y: (base.y + target.y) / 2 + rng.range(-60, 60))
                let path = UIBezierPath()
                path.move(to: base)
                path.addQuadCurve(to: target, controlPoint: mid)
                spec.speck.withAlphaComponent(0.18).setStroke()
                path.lineWidth = 36
                path.stroke()
                spec.path.withAlphaComponent(0.45).setStroke()
                path.lineWidth = 28
                path.stroke()
                spec.path.withAlphaComponent(0.35).setStroke()
                path.lineWidth = 16
                path.stroke()
            }

            // Пучки травы из трёх травинок
            let dark = spec.speck.withAlphaComponent(0.6)
            let light = spec.patches.last?.withAlphaComponent(0.7) ?? dark
            c.setLineWidth(1.5)
            for i in 0..<2200 {
                let p = CGPoint(x: rng.range(0, size.width), y: rng.range(0, size.height))
                let h = rng.range(4, 9)
                (i % 3 == 0 ? light : dark).setStroke()
                c.move(to: p); c.addLine(to: CGPoint(x: p.x - 3, y: p.y - h * 0.8))
                c.move(to: p); c.addLine(to: CGPoint(x: p.x, y: p.y - h))
                c.move(to: p); c.addLine(to: CGPoint(x: p.x + 3, y: p.y - h * 0.75))
                c.strokePath()
            }

            // Камешки
            for _ in 0..<220 {
                let p = CGPoint(x: rng.range(0, size.width), y: rng.range(0, size.height))
                let w = rng.range(3, 8)
                UIColor.black.withAlphaComponent(0.12).setFill()
                c.fillEllipse(in: CGRect(x: p.x - w / 2 + 1, y: p.y - w * 0.3 + 1.5, width: w, height: w * 0.6))
                UIColor.white.withAlphaComponent(0.28).setFill()
                c.fillEllipse(in: CGRect(x: p.x - w / 2, y: p.y - w * 0.3, width: w, height: w * 0.6))
            }

            // Цветочки на зелёной земле
            if green {
                let petals = [UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1), UIColor(red: 1, green: 0.6, blue: 0.75, alpha: 1),
                              UIColor.white, UIColor(red: 0.7, green: 0.6, blue: 1, alpha: 1)]
                for _ in 0..<420 {
                    let p = CGPoint(x: rng.range(0, size.width), y: rng.range(0, size.height))
                    rng.pick(petals).withAlphaComponent(0.9).setFill()
                    let r = rng.range(1.6, 3)
                    c.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
                }
            }

            // Водоёмы
            for pond in spec.ponds {
                let center = flip(spec.point(pond.x, pond.y))
                let r = pond.radius
                if pond.frozen {
                    UIColor(red: 0.84, green: 0.93, blue: 0.99, alpha: 1).setFill()
                    c.fillEllipse(in: CGRect(x: center.x - r - 12, y: center.y - r - 12, width: (r + 12) * 2, height: (r + 12) * 2))
                    softBlob(c, center: center, radius: r, color: UIColor(red: 0.6, green: 0.8, blue: 0.95, alpha: 1), squash: 1)
                    UIColor(red: 0.66, green: 0.84, blue: 0.96, alpha: 0.6).setFill()
                    c.fillEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
                    UIColor.white.withAlphaComponent(0.75).setStroke()
                    c.setLineWidth(2)
                    for _ in 0..<16 {
                        let a = rng.range(0, .pi * 2)
                        let r1 = rng.range(0, r * 0.7)
                        let start = CGPoint(x: center.x + cos(a) * r1, y: center.y + sin(a) * r1)
                        c.move(to: start)
                        c.addLine(to: CGPoint(x: start.x + rng.range(-40, 40), y: start.y + rng.range(-40, 40)))
                    }
                    c.strokePath()
                } else {
                    let shore = spec.shore ?? spec.path
                    softBlob(c, center: center, radius: r + 46, color: shore.withAlphaComponent(0.8), squash: 1)
                    shore.setFill()
                    c.fillEllipse(in: CGRect(x: center.x - r - 14, y: center.y - r - 14, width: (r + 14) * 2, height: (r + 14) * 2))
                    spec.water.setFill()
                    c.fillEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
                    c.saveGState()
                    c.addEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
                    c.clip()
                    softBlob(c, center: CGPoint(x: center.x - r * 0.15, y: center.y - r * 0.2), radius: r * 0.95, color: spec.waterLight, squash: 0.85)
                    UIColor.black.withAlphaComponent(0.18).setStroke()
                    c.setLineWidth(10)
                    c.strokeEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
                    c.restoreGState()
                    UIColor.white.withAlphaComponent(0.35).setStroke()
                    c.setLineWidth(2.5)
                    for _ in 0..<10 {
                        let a = rng.range(0, .pi * 2)
                        let r1 = rng.range(r * 0.2, r * 0.75)
                        let p = CGPoint(x: center.x + cos(a) * r1, y: center.y + sin(a) * r1)
                        c.move(to: p)
                        c.addLine(to: CGPoint(x: p.x + rng.range(10, 24), y: p.y))
                    }
                    c.strokePath()
                }
            }

            // Площадка склада: мощёный круг
            softBlob(c, center: base, radius: 150, color: spec.path.withAlphaComponent(0.6), squash: 0.8)
            spec.path.withAlphaComponent(0.85).setFill()
            c.fillEllipse(in: CGRect(x: base.x - 105, y: base.y - 82, width: 210, height: 164))
            for i in 0..<26 {
                let a = CGFloat(i) / 26 * .pi * 2
                let p = CGPoint(x: base.x + cos(a) * 100, y: base.y + sin(a) * 78)
                UIColor.black.withAlphaComponent(0.12).setFill()
                c.fillEllipse(in: CGRect(x: p.x - 9, y: p.y - 5, width: 18, height: 11))
                UIColor.white.withAlphaComponent(0.3).setFill()
                c.fillEllipse(in: CGRect(x: p.x - 9, y: p.y - 6, width: 18, height: 10))
            }

            // Затемнение по краям
            let space = CGColorSpaceCreateDeviceRGB()
            let colors = [UIColor.black.withAlphaComponent(0.3).cgColor, UIColor.black.withAlphaComponent(0).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) {
                let edge: CGFloat = 80
                c.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: edge), options: [])
                c.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size.height), end: CGPoint(x: 0, y: size.height - edge), options: [])
                c.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: edge, y: 0), options: [])
                c.drawLinearGradient(gradient, start: CGPoint(x: size.width, y: 0), end: CGPoint(x: size.width - edge, y: 0), options: [])
            }
        }
    }
}
