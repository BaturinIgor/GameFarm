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
    /// Рисует землю локации одной картинкой. Координаты UIKit перевёрнуты относительно SpriteKit.
    static func ground(_ spec: LocationSpec, spots: [SpotPlacement]) -> UIImage {
        let size = spec.size
        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = 1
        format.opaque = true
        var rng = SeededRNG(seed: spec.seed &+ 7)
        func flip(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: size.height - p.y) }

        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let c = ctx.cgContext
            spec.ground.setFill()
            c.fill(CGRect(origin: .zero, size: size))

            // Пятна разных оттенков
            for _ in 0..<320 {
                let color = rng.pick(spec.patches).withAlphaComponent(rng.range(0.35, 0.75))
                color.setFill()
                let r = rng.range(30, 150)
                let p = CGPoint(x: rng.range(0, size.width), y: rng.range(0, size.height))
                c.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r * 0.7, width: r * 2, height: r * 1.4))
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
                spec.path.withAlphaComponent(0.32).setStroke()
                path.lineWidth = 30
                path.stroke()
                spec.path.withAlphaComponent(0.25).setStroke()
                path.lineWidth = 18
                path.stroke()
            }

            // Травинки и крапинки
            spec.speck.withAlphaComponent(0.55).setStroke()
            c.setLineWidth(1.6)
            for _ in 0..<2600 {
                let p = CGPoint(x: rng.range(0, size.width), y: rng.range(0, size.height))
                let len = rng.range(3, 7)
                c.move(to: p)
                c.addLine(to: CGPoint(x: p.x + rng.range(-2, 2), y: p.y - len))
            }
            c.strokePath()

            // Водоёмы
            for pond in spec.ponds {
                let center = flip(spec.point(pond.x, pond.y))
                let r = pond.radius
                if pond.frozen {
                    UIColor(red: 0.78, green: 0.9, blue: 0.98, alpha: 1).setFill()
                    c.fillEllipse(in: CGRect(x: center.x - r - 10, y: center.y - r - 10, width: (r + 10) * 2, height: (r + 10) * 2))
                    UIColor(red: 0.66, green: 0.84, blue: 0.96, alpha: 1).setFill()
                    c.fillEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
                    UIColor.white.withAlphaComponent(0.7).setStroke()
                    c.setLineWidth(2)
                    for _ in 0..<14 {
                        let a = rng.range(0, .pi * 2)
                        let r1 = rng.range(0, r * 0.6)
                        let start = CGPoint(x: center.x + cos(a) * r1, y: center.y + sin(a) * r1)
                        c.move(to: start)
                        c.addLine(to: CGPoint(x: start.x + rng.range(-40, 40), y: start.y + rng.range(-40, 40)))
                    }
                    c.strokePath()
                } else {
                    spec.path.withAlphaComponent(0.9).setFill()
                    c.fillEllipse(in: CGRect(x: center.x - r - 14, y: center.y - r - 14, width: (r + 14) * 2, height: (r + 14) * 2))
                    UIColor(red: 0.2, green: 0.55, blue: 0.85, alpha: 1).setFill()
                    c.fillEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
                    UIColor(red: 0.28, green: 0.66, blue: 0.94, alpha: 1).setFill()
                    c.fillEllipse(in: CGRect(x: center.x - r * 0.8, y: center.y - r * 0.85, width: r * 1.5, height: r * 1.45))
                    UIColor.white.withAlphaComponent(0.35).setStroke()
                    c.setLineWidth(2.5)
                    for _ in 0..<8 {
                        let a = rng.range(0, .pi * 2)
                        let r1 = rng.range(r * 0.2, r * 0.7)
                        let p = CGPoint(x: center.x + cos(a) * r1, y: center.y + sin(a) * r1)
                        c.move(to: p)
                        c.addLine(to: CGPoint(x: p.x + 18, y: p.y))
                    }
                    c.strokePath()
                }
            }

            // Площадка склада
            spec.path.withAlphaComponent(0.55).setFill()
            c.fillEllipse(in: CGRect(x: base.x - 120, y: base.y - 90, width: 240, height: 180))

            // Затемнение по краям
            let space = CGColorSpaceCreateDeviceRGB()
            let colors = [UIColor.black.withAlphaComponent(0.28).cgColor, UIColor.black.withAlphaComponent(0).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) {
                let edge: CGFloat = 70
                c.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: edge), options: [])
                c.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size.height), end: CGPoint(x: 0, y: size.height - edge), options: [])
                c.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: edge, y: 0), options: [])
                c.drawLinearGradient(gradient, start: CGPoint(x: size.width, y: 0), end: CGPoint(x: size.width - edge, y: 0), options: [])
            }
        }
    }
}
