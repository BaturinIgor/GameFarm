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
    private let effects = EffectsEngine()
    private var lastPlay: [SFX: TimeInterval] = [:]
    private var lastVariant: [SFX: Int] = [:]
    private var lastJingle: TimeInterval = 0
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
        effects.start()
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
        effects.resume()
        if musicOn { music.resume(fade: 0.6) }
        if sfxOn { ambience.resume(fade: 0.6) }
    }

    // MARK: - Эффекты

    /// Играет случайный вариант эффекта. Один и тот же эффект не чаще раза в 0.05 с.
    /// Звуки заранее раскодированы в память и играют через AVAudioEngine: на кадр это почти ничего не стоит.
    func play(_ sfx: SFX, volume: Float = 1) {
        guard sfxOn, !appPaused else { return }
        if !started { start() }
        let count = effects.variants(sfx)
        guard count > 0 else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if let last = lastPlay[sfx], now - last < sfx.cooldown { return }
        // Мелодии наград не накладываются друг на друга: при быстром сборе звучит одна.
        if sfx.isJingle {
            if now - lastJingle < 0.45 { return }
            lastJingle = now
        }
        lastPlay[sfx] = now

        var index = Int.random(in: 0..<count)
        if count > 1, index == lastVariant[sfx] {
            index = (index + Int.random(in: 1..<count)) % count
        }
        lastVariant[sfx] = index
        effects.play(sfx, variant: index, volume: max(0, min(1, volume * sfx.gain)),
                     rate: sfx.varies ? Float.random(in: 0.94...1.06) : 1)
    }

    private func stopAllEffects() {
        effects.stopAll()
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
        effects.pause()
    }

    /// Приложение вернулось.
    func resumeAll() {
        guard appPaused else { return }
        appPaused = false
        guard started else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        effects.resume()
        if musicOn { music.resume(fade: 0.6) }
        if sfxOn { ambience.resume(fade: 0.6) }
    }
}

// MARK: - Вспомогательное

/// Эффекты через AVAudioEngine: все файлы один раз раскодированы в память (около 5 МБ),
/// дальше звук просто ставится в очередь одного из голосов. Никаких плееров и чтения файлов во время игры.
@MainActor
private final class EffectsEngine {
    private final class Voice {
        let node = AVAudioPlayerNode()
        let pitch = AVAudioUnitVarispeed()
        var endsAt: TimeInterval = 0
    }

    private let engine = AVAudioEngine()
    private var voices: [Voice] = []
    private var buffers: [SFX: [AVAudioPCMBuffer]] = [:]
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var running = false

    func start() {
        guard voices.isEmpty else { return }
        for _ in 0..<10 {
            let voice = Voice()
            engine.attach(voice.node)
            engine.attach(voice.pitch)
            engine.connect(voice.node, to: voice.pitch, format: format)
            engine.connect(voice.pitch, to: engine.mainMixerNode, format: format)
            voices.append(voice)
        }
        engine.prepare()
        resume()
        let format = self.format
        DispatchQueue.global(qos: .userInitiated).async {
            let decoded = Self.decodeAll(format)
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self.buffers = decoded }
            }
        }
    }

    func variants(_ sfx: SFX) -> Int { buffers[sfx]?.count ?? 0 }

    func play(_ sfx: SFX, variant: Int, volume: Float, rate: Float) {
        guard let list = buffers[sfx], variant < list.count, !voices.isEmpty else { return }
        if !running { resume() }
        guard running else { return }
        let buffer = list[variant]
        let now = ProcessInfo.processInfo.systemUptime
        // Свободный голос, а если все заняты, тот, что закончится раньше всех.
        let voice = voices.first { $0.endsAt <= now } ?? voices.min { $0.endsAt < $1.endsAt }!
        voice.node.volume = volume
        voice.pitch.rate = rate
        voice.node.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !voice.node.isPlaying { voice.node.play() }
        voice.endsAt = now + Double(buffer.frameLength) / format.sampleRate / Double(rate)
    }

    func stopAll() {
        for voice in voices {
            voice.node.stop()
            voice.endsAt = 0
        }
    }

    func pause() {
        guard running else { return }
        engine.pause()
        running = false
    }

    func resume() {
        guard !running, !voices.isEmpty else { return }
        do {
            try engine.start()
            running = true
        } catch {
            running = false
        }
    }

    nonisolated private static func decodeAll(_ format: AVAudioFormat) -> [SFX: [AVAudioPCMBuffer]] {
        var out: [SFX: [AVAudioPCMBuffer]] = [:]
        for sfx in SFX.allCases {
            var list: [AVAudioPCMBuffer] = []
            for index in 0..<16 {
                guard let url = Bundle.main.url(forResource: "sfx_\(sfx.rawValue)_\(index)", withExtension: "m4a") else { break }
                if let buffer = decode(url, to: format) { list.append(buffer) }
            }
            out[sfx] = list
        }
        return out
    }

    nonisolated private static func decode(_ url: URL, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let source = file.processingFormat
        guard file.length > 0,
              let input = AVAudioPCMBuffer(pcmFormat: source, frameCapacity: AVAudioFrameCount(file.length)) else { return nil }
        do { try file.read(into: input) } catch { return nil }
        if source == format { return input }
        guard let converter = AVAudioConverter(from: source, to: format) else { return nil }
        let capacity = AVAudioFrameCount(Double(input.frameLength) * format.sampleRate / source.sampleRate) + 1024
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        var fed = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if fed {
                status.pointee = .endOfStream
                return nil
            }
            fed = true
            status.pointee = .haveData
            return input
        }
        return error == nil && output.frameLength > 0 ? output : nil
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

    /// Как часто может звучать один и тот же эффект.
    var cooldown: TimeInterval {
        switch self {
        case .levelUp, .success, .treasure, .unlock, .purchase, .gateOpen, .tame, .luck: return 0.6
        case .coinBig, .wildAppear: return 0.3
        case .coin, .pickup, .deposit: return 0.07
        case .tap, .open, .close: return 0.08
        default: return 0.05
        }
    }

    /// Короткие мелодии наград.
    var isJingle: Bool {
        switch self {
        case .levelUp, .success, .treasure, .unlock, .purchase, .tame, .luck, .gateOpen: return true
        default: return false
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
