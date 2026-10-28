import Foundation

/// Звуки из модели игры: она не привязана к главному потоку, а Sound - привязан.
enum SoundFX {
    static func play(_ sfx: SFX, volume: Float = 1) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { Sound.shared.play(sfx, volume: volume) }
        } else {
            Task { @MainActor in Sound.shared.play(sfx, volume: volume) }
        }
    }
}
