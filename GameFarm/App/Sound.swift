import AVFoundation

/// Короткие звуки. Файлы в бандле: sfx_<rawValue>_<n>.m4a, n = 0, 1, 2... (варианты).
enum SFX: String, CaseIterable {
    case chop, mine, pick, splash, treeFall, rockBreak, coin, coinBig, pickup, deposit
    case levelUp, success, treasure, unlock, purchase, tap, open, close, error
    case tame, wildAppear, luck, whoosh, gateOpen, crit, quack
    case footstepGrass, footstepSnow, footstepStone, footstepSand
}

/// Музыка локаций. Файлы в бандле: mus_<rawValue>.m4a.
enum Music: String, CaseIterable { case meadow, hills, lake, swamp, desert, snow, caves, island, volcano, sky, garden, expedition }

/// Фоновые звуки окружения. Файлы в бандле: amb_<rawValue>.m4a.
enum Ambience: String, CaseIterable { case river, wind, waves, fire, birds }

/// Звук игры: эффекты, музыка и фон.
/// Если какого-то файла нет в бандле, соответствующий звук просто не играет.
@MainActor
final class Sound {
    static let shared = Sound()

    private static let musicKey = "sound.music"
    private static let sfxKey = "sound.sfx"
    private static let poolSize = 4
    private static let throttle: TimeInterval = 0.05

    /// Музыка. Выключение плавно глушит трек, включение продолжает текущий.
    var musicOn: Bool {
        didSet {
            guard musicOn != oldValue else { return }
            UserDefaults.standard.set(musicOn, forKey: Self.musicKey)
            if musicOn {
                if !appPaused { music.resume() }
            } else {
                music.suspend()
            }
        }
    }

    /// Звуковые эффекты и фон окружения.
    var sfxOn: Bool {
        didSet {
            guard sfxOn != oldValue else { return }
            UserDefaults.standard.set(sfxOn, forKey: Self.sfxKey)
            if sfxOn {
                if !appPaused { ambience.resume() }
            } else {
                ambience.suspend()
                stopAllEffects()
            }
        }
    }

    private var started = false
    private var appPaused = false
    private var bank: [SFX: [SoundVariant]] = [:]
    private var lastPlay: [SFX: TimeInterval] = [:]
    private var lastVariant: [SFX: Int] = [:]
    private let music = SoundLoopChannel(volume: 0.35)
    private let ambience = SoundLoopChannel(volume: 0.25)
    private var observers: [NSObjectProtocol] = []

    private init() {
        let defaults = UserDefaults.standard
        musicOn = defaults.object(forKey: Self.musicKey) as? Bool ?? true
        sfxOn = defaults.object(forKey: Self.sfxKey) as? Bool ?? true
    }

    // MARK: - Запуск

    /// Настраивает аудиосессию (не глушит музыку других приложений) и загружает эффекты.
    /// Повторный вызов ничего не делает.
    func start() {
        guard !started else { return }
        started = true
        configureSession()
        loadBank()
        observeInterruptions()
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        } catch {
            try? session.setCategory(.ambient)
        }
        try? session.setActive(true)
    }

    private func loadBank() {
        for sfx in SFX.allCases {
            var variants: [SoundVariant] = []
            for index in 0..<16 {
                guard let url = Bundle.main.url(forResource: "sfx_\(sfx.rawValue)_\(index)", withExtension: "m4a") else { break }
                let variant = SoundVariant(url: url)
                if let player = Self.makePlayer(url) {
                    variant.players.append(player)
                }
                variants.append(variant)
            }
            bank[sfx] = variants
        }
    }

    private func observeInterruptions() {
        let token = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            guard raw.flatMap(AVAudioSession.InterruptionType.init(rawValue:)) == .ended else { return }
            MainActor.assumeIsolated {
                self?.recoverAfterInterruption()
            }
        }
        observers.append(token)
    }

    private func recoverAfterInterruption() {
        guard !appPaused else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        if musicOn { music.resume(fade: 0.6) }
        if sfxOn { ambience.resume(fade: 0.6) }
    }

    // MARK: - Эффекты

    /// Играет случайный вариант эффекта. Один и тот же эффект не чаще раза в 0.05 с.
    func play(_ sfx: SFX, volume: Float = 1) {
        guard sfxOn, !appPaused else { return }
        if !started { start() }
        guard let variants = bank[sfx], !variants.isEmpty else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if let last = lastPlay[sfx], now - last < Self.throttle { return }
        lastPlay[sfx] = now

        var index = Int.random(in: 0..<variants.count)
        if variants.count > 1, index == lastVariant[sfx] {
            index = (index + Int.random(in: 1..<variants.count)) % variants.count
        }
        lastVariant[sfx] = index

        guard let player = freePlayer(in: variants[index]) else { return }
        player.volume = max(0, min(1, volume * sfx.gain))
        player.rate = sfx.varies ? Float.random(in: 0.94...1.06) : 1
        player.currentTime = 0
        player.play()
    }

    private func freePlayer(in variant: SoundVariant) -> AVAudioPlayer? {
        if let idle = variant.players.first(where: { !$0.isPlaying }) {
            return idle
        }
        if variant.players.count < Self.poolSize, let fresh = Self.makePlayer(variant.url) {
            variant.players.append(fresh)
            return fresh
        }
        // Все заняты: перезапускаем тот, что играет дольше всех.
        let oldest = variant.players.max(by: { $0.currentTime < $1.currentTime })
        oldest?.stop()
        return oldest
    }

    private func stopAllEffects() {
        for variants in bank.values {
            for variant in variants {
                for player in variant.players where player.isPlaying {
                    player.stop()
                }
            }
        }
    }

    private static func makePlayer(_ url: URL) -> AVAudioPlayer? {
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.enableRate = true
        player.prepareToPlay()
        return player
    }

    // MARK: - Музыка и фон

    /// Плавно (около 1.2 с) переключает музыку. nil глушит. Тот же трек не перезапускается.
    func playMusic(_ music: Music?) {
        if !started { start() }
        self.music.select(music.map { "mus_\($0.rawValue)" }, active: musicOn && !appPaused)
    }

    /// Плавно переключает фон окружения. nil выключает.
    func playAmbience(_ ambience: Ambience?) {
        if !started { start() }
        self.ambience.select(ambience.map { "amb_\($0.rawValue)" }, active: sfxOn && !appPaused)
    }

    // MARK: - Фон приложения

    /// Приложение уходит в фон.
    func pauseAll() {
        appPaused = true
        music.pauseNow()
        ambience.pauseNow()
        stopAllEffects()
    }

    /// Приложение вернулось.
    func resumeAll() {
        guard appPaused else { return }
        appPaused = false
        guard started else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        if musicOn { music.resume(fade: 0.6) }
        if sfxOn { ambience.resume(fade: 0.6) }
    }
}

// MARK: - Вспомогательное

/// Один вариант эффекта и его небольшой пул плееров, чтобы частые повторы накладывались.
private final class SoundVariant {
    let url: URL
    var players: [AVAudioPlayer] = []

    init(url: URL) {
        self.url = url
    }
}

/// Зацикленный канал (музыка или фон) с плавными переходами.
@MainActor
private final class SoundLoopChannel {
    let volume: Float
    private(set) var name: String?
    private var player: AVAudioPlayer?
    private var retiring: [AVAudioPlayer] = []
    private var token = 0

    init(volume: Float) {
        self.volume = volume
    }

    /// Выбирает трек. active: можно ли ему звучать прямо сейчас.
    func select(_ newName: String?, active: Bool, fade: TimeInterval = 1.2) {
        if newName == name {
            if active { resume(fade: fade) }
            return
        }
        name = newName
        if let old = player {
            retire(old, fade: fade)
        }
        player = nil
        if active { resume(fade: fade) }
    }

    /// Запускает или продолжает текущий трек с плавным нарастанием.
    func resume(fade: TimeInterval = 1.2) {
        guard let name else { return }
        token += 1
        if player == nil {
            guard let url = Bundle.main.url(forResource: name, withExtension: "m4a"),
                  let fresh = try? AVAudioPlayer(contentsOf: url) else { return }
            fresh.numberOfLoops = -1
            fresh.volume = 0
            fresh.prepareToPlay()
            player = fresh
        }
        guard let player else { return }
        if !player.isPlaying { player.play() }
        player.setVolume(volume, fadeDuration: fade)
    }

    /// Плавно глушит и ставит на паузу, позиция в треке сохраняется.
    func suspend(fade: TimeInterval = 0.8) {
        guard let current = player, current.isPlaying else { return }
        token += 1
        let expected = token
        current.setVolume(0, fadeDuration: fade)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((fade + 0.05) * 1_000_000_000))
            guard let self, self.token == expected, self.player === current else { return }
            current.pause()
        }
    }

    /// Мгновенная пауза (уход приложения в фон).
    func pauseNow() {
        token += 1
        player?.pause()
        for old in retiring {
            old.stop()
        }
        retiring.removeAll()
    }

    private func retire(_ old: AVAudioPlayer, fade: TimeInterval) {
        retiring.append(old)
        old.setVolume(0, fadeDuration: fade)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((fade + 0.05) * 1_000_000_000))
            old.stop()
            self?.retiring.removeAll { $0 === old }
        }
    }
}

private extension SFX {
    /// Базовая громкость эффекта.
    var gain: Float {
        switch self {
        case .footstepGrass, .footstepSnow, .footstepStone, .footstepSand: return 0.35
        case .tap, .open, .close: return 0.8
        default: return 1
        }
    }

    /// Частые звуки слегка меняют скорость, чтобы не звучать одинаково. Мелодии и интерфейс не трогаем.
    var varies: Bool {
        switch self {
        case .levelUp, .success, .treasure, .unlock, .purchase, .gateOpen, .luck, .tame,
             .wildAppear, .coinBig, .tap, .open, .close, .error:
            return false
        default:
            return true
        }
    }
}
