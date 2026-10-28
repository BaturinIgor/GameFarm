import SpriteKit
import UIKit

/// Детерминированный генератор случайных чисел.
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

func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
    hypot(a.x - b.x, a.y - b.y)
}

enum WorldArt {
    /// Земля без спрайтов пака: клетки раскрашиваются цветами локации.
    static func fallbackGround(_ layout: LocationLayout, _ spec: LocationSpec) -> UIImage {
        let px: CGFloat = 4
        let size = CGSize(width: CGFloat(layout.cols) * px, height: CGFloat(layout.rows) * px)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let edgeColor: UIColor
        switch layout.edge {
        case "sea", "lava": edgeColor = spec.water
        case "void": edgeColor = spec.dark ? UIColor(white: 0.03, alpha: 1) : UIColor(red: 0.66, green: 0.83, blue: 1, alpha: 1)
        default: edgeColor = spec.ground.withAlphaComponent(1)
        }
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let c = ctx.cgContext
            for r in 0..<layout.rows {
                for col in 0..<layout.cols {
                    let color: UIColor
                    switch layout.at(col, r) {
                    case .land: color = spec.ground
                    case .path: color = spec.path
                    case .water: color = spec.water
                    case .ice: color = UIColor(red: 0.8, green: 0.92, blue: 1, alpha: 1)
                    case .blocked: color = spec.ground.withAlphaComponent(1)
                    case .void: color = edgeColor
                    }
                    color.setFill()
                    c.fill(CGRect(x: CGFloat(col) * px, y: CGFloat(r) * px, width: px, height: px))
                }
            }
        }
    }
}
