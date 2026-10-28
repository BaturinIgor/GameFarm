import UIKit

/// Проход между двумя локациями. Его можно открыть с любой стороны.
struct GateSpec {
    let id: String
    let a: LocationID
    let b: LocationID
    let cost: Cost
    /// Проходы одной группы открываются вместе (перекрёсток).
    var group: String? = nil
    /// Ворота в королевский сад: открываются покупкой.
    var royal = false

    var level: Int { max(a.spec.level, b.spec.level) }

    func other(_ from: LocationID) -> LocationID { from == a ? b : a }

    func connects(_ id: LocationID) -> Bool { a == id || b == id }
}

enum WorldGraph {
    static let gates: [GateSpec] = [
        GateSpec(id: "meadow_hills", a: .meadow, b: .hills, cost: Cost(coins: 0, (.wood, 60), (.stone, 40), (.berries, 20))),
        GateSpec(id: "meadow_lake", a: .meadow, b: .lake, cost: Cost(coins: 300, (.wood, 200), (.stone, 150), (.coal, 40), (.carrots, 40))),
        GateSpec(id: "lake_swamp", a: .lake, b: .swamp, cost: Cost(coins: 800, (.wood, 300), (.iron, 40), (.fish, 40), (.bamboo, 30))),
        GateSpec(id: "meadow_desert", a: .meadow, b: .desert, cost: Cost(coins: 2000, (.wood, 400), (.iron, 80), (.fish, 60), (.carrots, 80))),
        GateSpec(id: "swamp_desert", a: .swamp, b: .desert, cost: Cost(coins: 1500, (.wood, 300), (.clay, 40), (.herbs, 60), (.fish, 40))),
        GateSpec(id: "hills_snow", a: .hills, b: .snow, cost: Cost(coins: 6000, (.iron, 200), (.gold, 60), (.coconut, 50), (.clay, 80)),
                 group: "snowpass"),
        GateSpec(id: "desert_snow", a: .desert, b: .snow, cost: Cost(coins: 6000, (.iron, 200), (.gold, 60), (.coconut, 50), (.clay, 80)),
                 group: "snowpass"),
        GateSpec(id: "snow_caves", a: .snow, b: .caves, cost: Cost(coins: 15000, (.gold, 200), (.ice, 150), (.diamond, 15))),
        GateSpec(id: "swamp_island", a: .swamp, b: .island, cost: Cost(coins: 25000, (.crystal, 40), (.diamond, 40), (.cactus, 150), (.coconut, 150))),
        GateSpec(id: "caves_volcano", a: .caves, b: .volcano, cost: Cost(coins: 50000, (.crystal, 60), (.coral, 40), (.pearl, 10), (.banana, 100)),
                 group: "firepass"),
        GateSpec(id: "island_volcano", a: .island, b: .volcano, cost: Cost(coins: 50000, (.crystal, 60), (.coral, 40), (.pearl, 10), (.banana, 100)),
                 group: "firepass"),
        GateSpec(id: "volcano_sky", a: .volcano, b: .sky, cost: Cost(coins: 100000, (.obsidian, 100), (.ruby, 20), (.sulfur, 100), (.pineapple, 200))),
        GateSpec(id: "meadow_garden", a: .meadow, b: .garden, cost: Cost(), royal: true)
    ]

    static func gate(_ id: String) -> GateSpec? { gates.first { $0.id == id } }

    static func gates(of id: LocationID) -> [GateSpec] { gates.filter { $0.connects(id) } }

    /// Все проходы группы (или сам проход, если он не в группе).
    static func bundle(_ gate: GateSpec) -> [GateSpec] {
        guard let group = gate.group else { return [gate] }
        return gates.filter { $0.group == group }
    }

    /// Локации, куда можно дойти от луга через открытые проходы.
    static func reachable(open: Set<String>) -> Set<LocationID> {
        var seen: Set<LocationID> = [.meadow]
        var queue: [LocationID] = [.meadow]
        while let cur = queue.popLast() {
            for gate in gates(of: cur) where !gate.royal && open.contains(gate.id) {
                let next = gate.other(cur)
                if seen.insert(next).inserted { queue.append(next) }
            }
        }
        return seen
    }

    /// Кратчайшая цепочка проходов от луга до локации (для переноса старых сохранений).
    static func path(to target: LocationID, within allowed: Set<LocationID>?) -> [String]? {
        var prev: [LocationID: (LocationID, String)] = [:]
        var seen: Set<LocationID> = [.meadow]
        var queue: [LocationID] = [.meadow]
        var i = 0
        while i < queue.count {
            let cur = queue[i]
            i += 1
            if cur == target { break }
            for gate in gates(of: cur) where !gate.royal {
                let next = gate.other(cur)
                if let allowed, !allowed.contains(next) { continue }
                if seen.insert(next).inserted {
                    prev[next] = (cur, gate.id)
                    queue.append(next)
                }
            }
        }
        guard seen.contains(target) else { return nil }
        var out: [String] = []
        var cur = target
        while cur != .meadow, let step = prev[cur] {
            out.append(step.1)
            cur = step.0
        }
        return out.reversed()
    }
}

// MARK: - Раскладка локации из layout_<id>.json (готовит tools/world.py)

struct GateLayout {
    let id: String
    let to: LocationID
    /// Сторона карты: N, S, W, E.
    let side: String
    let barrier: CGPoint
    let inner: CGPoint
    let edge: CGPoint

    var vertical: Bool { side == "W" || side == "E" }
}

struct PropPlacement {
    let name: String
    let position: CGPoint
    let fixed: Bool
}

struct LocationLayout {
    /// Коды клеток: L трава, P тропа, W вода, I лёд, V пустота, B непроходимый край.
    enum Cell: UInt8 {
        case land, path, water, ice, void, blocked
    }

    let id: LocationID
    let cols: Int
    let rows: Int
    let cell: CGFloat
    let edge: String
    let cells: [Cell]
    let base: CGPoint
    let gates: [GateLayout]
    let spots: [(type: NodeType, position: CGPoint)]
    let props: [PropPlacement]
    let border: [PropPlacement]
    /// Центры грядок огорода (только у дома на поляне).
    var farm: [CGPoint] = []
    /// Где стоит лавка торговца.
    var stall: CGPoint?
    /// Загон для зверей (прямоугольник в точках сцены).
    var pen: CGRect?
    /// Доска заказов и стражник.
    var board: CGPoint?
    /// Дом изнутри: станции (плита, лестницы, кровать...) и места для украшений.
    var stations: [(kind: HomeStation, position: CGPoint)] = []
    var slots: [(id: String, position: CGPoint)] = []

    var size: CGSize { CGSize(width: CGFloat(cols) * cell, height: CGFloat(rows) * cell) }

    var nodeTypes: [NodeType] {
        var seen: [NodeType] = []
        for spot in spots where !seen.contains(spot.type) { seen.append(spot.type) }
        return seen
    }

    /// Клетка по столбцу и ряду (ряд 0 - верхний).
    func at(_ col: Int, _ row: Int) -> Cell {
        guard col >= 0, row >= 0, col < cols, row < rows else { return .void }
        return cells[row * cols + col]
    }

    func colRow(_ p: CGPoint) -> (Int, Int) {
        (Int(floor(p.x / cell)), rows - 1 - Int(floor(p.y / cell)))
    }

    /// Прямоугольник клетки в координатах сцены.
    func rect(_ col: Int, _ row: Int) -> CGRect {
        CGRect(x: CGFloat(col) * cell, y: CGFloat(rows - 1 - row) * cell, width: cell, height: cell)
    }

    func center(_ col: Int, _ row: Int) -> CGPoint {
        CGPoint(x: (CGFloat(col) + 0.5) * cell, y: (CGFloat(rows - 1 - row) + 0.5) * cell)
    }

    func walkable(_ col: Int, _ row: Int) -> Bool {
        switch at(col, row) {
        case .land, .path, .ice: return true
        default: return false
        }
    }

    func walkable(_ p: CGPoint) -> Bool {
        let (c, r) = colRow(p)
        return walkable(c, r)
    }

    func isWater(_ col: Int, _ row: Int) -> Bool { at(col, row) == .water }

    /// Клетки воды (для бликов и пузырей).
    var waterCells: [(Int, Int)] {
        var out: [(Int, Int)] = []
        for r in 0..<rows {
            for c in 0..<cols where at(c, r) == .water {
                out.append((c, r))
            }
        }
        return out
    }

    // MARK: Загрузка

    nonisolated(unsafe) private static var cache: [String: LocationLayout] = [:]
    private static let lock = NSLock()
    /// Какая карта этапа сейчас у ивентов (0 - основная). Меняет состояние игры при смене этапа.
    nonisolated(unsafe) static var eventVariant = 0

    /// Имя файла карты: у ивентов на каждом этапе своя карта.
    static func resourceName(_ id: LocationID) -> String {
        id.spec.kind == .event && eventVariant > 0 ? "\(id.rawValue)_\(eventVariant)" : id.rawValue
    }

    static func get(_ id: LocationID) -> LocationLayout {
        lock.lock()
        defer { lock.unlock() }
        let name = resourceName(id)
        if let layout = cache[name] { return layout }
        let layout = load(id, name: name) ?? load(id, name: id.rawValue) ?? fallback(id)
        cache[name] = layout
        return layout
    }

    private struct Entry: Decodable {
        let name: String
        let x: Double
        let y: Double
        let flag: Int

        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            name = try c.decode(String.self)
            x = try c.decode(Double.self)
            y = try c.decode(Double.self)
            flag = c.isAtEnd ? 0 : (try c.decode(Int.self))
        }
    }

    private struct RawGate: Decodable {
        let id: String
        let to: String
        let side: String
        let barrier: [Double]
        let inner: [Double]
        let edge: [Double]
    }

    private struct Raw: Decodable {
        let w: Int
        let h: Int
        let cell: Double
        let edge: String
        let rows: [String]
        let base: [Double]
        let gates: [RawGate]
        let spots: [Entry]
        let props: [Entry]
        let border: [Entry]
        let farm: [[Double]]?
        let stall: [Double]?
        let pen: [Double]?
        let board: [Double]?
        let stations: [Entry]?
        let slots: [Entry]?
    }

    private static func point(_ v: [Double]) -> CGPoint {
        CGPoint(x: v.count > 0 ? v[0] : 0, y: v.count > 1 ? v[1] : 0)
    }

    private static func load(_ id: LocationID, name: String) -> LocationLayout? {
        guard let url = Bundle.main.url(forResource: "layout_\(name)", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode(Raw.self, from: data) else { return nil }
        var cells: [Cell] = []
        cells.reserveCapacity(raw.w * raw.h)
        for row in raw.rows {
            for ch in row {
                switch ch {
                case "L": cells.append(.land)
                case "P": cells.append(.path)
                case "W": cells.append(.water)
                case "I": cells.append(.ice)
                case "B": cells.append(.blocked)
                default: cells.append(.void)
                }
            }
        }
        guard cells.count == raw.w * raw.h else { return nil }
        let gates = raw.gates.compactMap { g -> GateLayout? in
            guard let to = LocationID(rawValue: g.to) else { return nil }
            return GateLayout(id: g.id, to: to, side: g.side, barrier: point(g.barrier), inner: point(g.inner), edge: point(g.edge))
        }
        let spots = raw.spots.compactMap { e -> (type: NodeType, position: CGPoint)? in
            guard let type = NodeType(rawValue: e.name) else { return nil }
            return (type, CGPoint(x: e.x, y: e.y))
        }
        return LocationLayout(
            id: id, cols: raw.w, rows: raw.h, cell: CGFloat(raw.cell), edge: raw.edge, cells: cells,
            base: point(raw.base), gates: gates, spots: spots,
            props: raw.props.map { PropPlacement(name: $0.name, position: CGPoint(x: $0.x, y: $0.y), fixed: $0.flag == 1) },
            border: raw.border.map { PropPlacement(name: $0.name, position: CGPoint(x: $0.x, y: $0.y), fixed: false) },
            farm: (raw.farm ?? []).map(point),
            stall: raw.stall.map(point),
            pen: raw.pen.flatMap { v in v.count == 4 ? CGRect(x: v[0], y: v[1], width: v[2], height: v[3]) : nil },
            board: raw.board.map(point),
            stations: (raw.stations ?? []).compactMap { e in
                HomeStation(rawValue: e.name).map { (kind: $0, position: CGPoint(x: e.x, y: e.y)) }
            },
            slots: (raw.slots ?? []).map { (id: $0.name, position: CGPoint(x: $0.x, y: $0.y)) }
        )
    }

    /// Запасная прямоугольная поляна, если файла раскладки нет в сборке.
    private static func fallback(_ id: LocationID) -> LocationLayout {
        let cols = 36, rows = 46
        var cells = [Cell](repeating: .land, count: cols * rows)
        for r in 0..<rows {
            for c in 0..<cols where c < 2 || r < 2 || c >= cols - 2 || r >= rows - 2 {
                cells[r * cols + c] = .blocked
            }
        }
        let cell: CGFloat = 32
        return LocationLayout(id: id, cols: cols, rows: rows, cell: cell, edge: "forest", cells: cells,
                              base: CGPoint(x: CGFloat(cols) * cell / 2, y: 8 * cell), gates: [], spots: [],
                              props: [], border: [])
    }
}
