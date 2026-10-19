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
            VStack(spacing: 14) {
                Text("🎉").font(.system(size: 56))
                    .scaleEffect(appeared ? 1 : 0.4)
                    .rotationEffect(.degrees(appeared ? 0 : -30))
                Text("Уровень \(info.to)!")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                if info.to - info.from > 1 {
                    Text("Сразу +\(info.to - info.from) уровня")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(GameRules.rewards(at: info.to)) { line in
                        row(line)
                    }
                    if !lines.isEmpty {
                        Divider().padding(.vertical, 2)
                        Text("Открылось").font(.caption.bold()).foregroundStyle(.secondary)
                        ForEach(lines) { line in
                            row(line)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button("Отлично", action: onClose)
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
                Text("С возвращением!")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                Text("Пока тебя не было \(Fmt.seconds(report.duration)), звери собрали:")
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
                Text("Всё уже на складе")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Забрать", action: onClose)
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
            }
            .padding(22)
            .frame(maxWidth: 360)
            .glassEffect(.regular, in: .rect(cornerRadius: 28))
            .padding(24)
        }
    }
}
