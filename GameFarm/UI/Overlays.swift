import SwiftUI

struct LevelUpOverlay: View {
    let info: LevelUpInfo
    let onClose: () -> Void
    @State private var appeared = false

    private var lines: [UnlockLine] {
        var out: [UnlockLine] = []
        let levels = Array((info.from + 1)...max(info.from + 1, info.to))
        for level in levels {
            out.append(contentsOf: GameRules.unlocks(at: level))
        }
        return out
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
                .onTapGesture(perform: onClose)
            ConfettiView()
                .ignoresSafeArea()
                .allowsHitTesting(false)
            VStack(spacing: 14) {
                Text("🎉").font(.system(size: 56))
                    .scaleEffect(appeared ? 1 : 0.4)
                    .rotationEffect(.degrees(appeared ? 0 : -30))
                Text(tr("levelup.title", info.to))
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                if info.to - info.from > 1 {
                    Text(tr("levelup.multi", info.to - info.from))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(GameRules.rewards(at: info.to)) { line in
                        row(line)
                    }
                    if !lines.isEmpty {
                        Divider().padding(.vertical, 2)
                        Text(tr("levelup.unlocked")).font(.caption.bold()).foregroundStyle(.secondary)
                        ForEach(lines) { line in
                            row(line)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button(tr("common.great"), action: onClose)
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
            }
            .padding(22)
            .frame(maxWidth: 360)
            .glassEffect(.regular, in: .rect(cornerRadius: 28))
            .padding(24)
        }
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(duration: 0.5, bounce: 0.5)) { appeared = true }
        }
    }

    private func row(_ line: UnlockLine) -> some View {
        HStack(spacing: 10) {
            Text(line.icon).font(.system(size: 20)).frame(width: 28)
            Text(line.text).font(.system(size: 14, weight: .medium))
        }
    }
}

struct OfflineOverlay: View {
    let report: OfflineReport
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
                .onTapGesture(perform: onClose)
            VStack(spacing: 14) {
                Text("🏡").font(.system(size: 50))
                Text(tr("offline.title"))
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                Text(tr("offline.text", Fmt.seconds(report.duration)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                FlowLayout(spacing: 8) {
                    ForEach(report.items) { item in
                        HStack(spacing: 5) {
                            ResourceIcon(kind: item.kind, size: 24)
                            Text("+\(Fmt.n(item.amount))")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.green.opacity(0.15)))
                    }
                }
                Text(tr("offline.inStorage"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !report.doubled {
                    Button {
                        Ads.shared.show {
                            withAnimation(.spring(duration: 0.4)) { GameState.shared.doubleOffline(fromAd: !GameState.shared.hasPro) }
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    } label: {
                        Label(GameState.shared.hasPro ? tr("offline.double.pro") : tr("offline.double"),
                              systemImage: GameState.shared.hasPro ? "crown.fill" : "play.rectangle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.green)
                    .controlSize(.large)
                }
                if report.doubled {
                    Button(tr("offline.collect"), action: onClose)
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                } else {
                    Button(tr("offline.collect"), action: onClose)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                }
            }
            .padding(22)
            .frame(maxWidth: 360)
            .glassEffect(.regular, in: .rect(cornerRadius: 28))
            .padding(24)
        }
    }
}

/// Конфетти, падающее сверху. Рисуется через Canvas без отдельных вью на каждую частицу.
struct ConfettiView: View {
    private struct Piece {
        let x: Double
        let delay: Double
        let speed: Double
        let sway: Double
        let spin: Double
        let size: Double
        let color: Color
    }

    private let pieces: [Piece] = (0..<90).map { _ in
        Piece(x: Double.random(in: 0...1), delay: Double.random(in: 0...0.8), speed: Double.random(in: 0.22...0.42),
              sway: Double.random(in: 10...40), spin: Double.random(in: 2...7), size: Double.random(in: 6...11),
              color: [Color.yellow, .orange, .pink, .mint, .cyan, .purple, .red].randomElement() ?? .yellow)
    }
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start)
                for piece in pieces {
                    let local = t - piece.delay
                    guard local > 0 else { continue }
                    let y = -20 + local * piece.speed * size.height
                    guard y < size.height + 20 else { continue }
                    let x = piece.x * size.width + sin(local * 3 + piece.x * 10) * piece.sway
                    var c = context
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .radians(local * piece.spin))
                    let rect = CGRect(x: -piece.size / 2, y: -piece.size / 4, width: piece.size, height: piece.size / 2)
                    c.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(piece.color))
                }
            }
        }
    }
}

