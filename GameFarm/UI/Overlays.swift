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
            Palette.dim.ignoresSafeArea()
                .onTapGesture(perform: onClose)
            ConfettiView()
                .ignoresSafeArea()
                .allowsHitTesting(false)
            VStack(spacing: 14) {
                ZStack {
                    Image(systemName: "star.fill")
                        .font(.system(size: 92, weight: .black))
                        .foregroundStyle(LinearGradient(colors: [ButtonTone.gold.top, ButtonTone.gold.base], startPoint: .top, endPoint: .bottom))
                        .outlined(Palette.outline, width: 2)
                    Text("\(info.to)")
                        .gameTitle(30, outline: ButtonTone.orange.lip)
                        .offset(y: 4)
                }
                .scaleEffect(appeared ? 1 : 0.4)
                .rotationEffect(.degrees(appeared ? 0 : -30))
                .padding(.top, 14)
                if info.to - info.from > 1 {
                    Text(tr("levelup.multi", info.to - info.from))
                        .font(.game(14, .semibold))
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(GameRules.rewards(from: info.from, to: info.to)) { line in
                        row(line)
                    }
                    if !lines.isEmpty {
                        PaperDivider().padding(.vertical, 2)
                        Text(tr("levelup.unlocked")).font(.game(12)).foregroundStyle(.secondary)
                        ForEach(lines) { line in
                            row(line)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .listBox(radius: 14)
                Button(tr("common.great"), action: onClose)
                    .buttonStyle(.game(.green, wide: true))
            }
            .foregroundStyle(Palette.ink)
            .padding(22)
            .frame(maxWidth: 360)
            .gamePanel()
            .overlay(alignment: .top) {
                RibbonTitle(text: tr("levelup.title", info.to), tone: .orange, size: 22)
                    .padding(.horizontal, 16)
                    .offset(y: -20)
            }
            .padding(24)
            .popIn()
        }
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(duration: 0.5, bounce: 0.5)) { appeared = true }
        }
    }

    private func row(_ line: UnlockLine) -> some View {
        HStack(spacing: 10) {
            IconView(icon: line.icon, size: 22).frame(width: 28)
            Text(line.text).font(.game(14, .semibold))
        }
    }
}

struct OfflineOverlay: View {
    let report: OfflineReport
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Palette.dim.ignoresSafeArea()
                .onTapGesture(perform: onClose)
            VStack(spacing: 14) {
                PixelIcon(name: "bed", size: 54)
                    .padding(.top, 12)
                Text(tr("offline.text", Fmt.seconds(report.duration)))
                    .font(.game(14, .semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                FlowLayout(spacing: 8) {
                    ForEach(report.items) { item in
                        RewardChip(text: "+\(Fmt.n(item.amount))") { ResourceIcon(kind: item.kind, size: 24) }
                    }
                }
                Text(tr("offline.inStorage"))
                    .font(.game(12, .semibold))
                    .foregroundStyle(.secondary)
                if !report.doubled {
                    // Одно нажатие: удваиваем и сразу закрываем окно
                    Button {
                        Ads.shared.show {
                            withAnimation(.spring(duration: 0.3)) { GameState.shared.doubleOffline(fromAd: !GameState.shared.hasPro) }
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    } label: {
                        Label(GameState.shared.hasPro ? tr("offline.double.pro") : tr("offline.double"),
                              systemImage: GameState.shared.hasPro ? "crown.fill" : "play.rectangle.fill")
                    }
                    .buttonStyle(.game(.green, wide: true))
                }
                Button(tr("offline.collect"), action: onClose)
                    .buttonStyle(.game(.wood, small: true))
            }
            .foregroundStyle(Palette.ink)
            .padding(22)
            .frame(maxWidth: 360)
            .gamePanel()
            .overlay(alignment: .top) {
                RibbonTitle(text: tr("offline.title"), tone: .green, size: 20)
                    .padding(.horizontal, 20)
                    .offset(y: -18)
            }
            .padding(24)
            .popIn()
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
    /// Когда всё конфетти упало, перестаём перерисовывать каждый кадр.
    @State private var finished = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: finished)) { timeline in
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
        .opacity(finished ? 0 : 1)
        .task {
            try? await Task.sleep(for: .seconds(6))
            finished = true
        }
    }
}

