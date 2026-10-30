import Foundation

/// Снимки экрана Swift-версии в CI (.github/workflows/swift-shots.yml), чтобы сравнить с Godot-версией.
/// Включается только аргументом запуска -shots (`xcrun simctl launch <udid> com.personal.gamefarm -shots`),
/// обычный запуск это не меняет. Сценарий по времени ведёт ContentView.runShots().
///
/// Обмен с workflow через файлы в tmp контейнера приложения: приложение пишет имя шага
/// в tmp/shots/request и ждёт, пока workflow снимет экран (xcrun simctl io screenshot) и удалит файл.
/// В конце сценария появляется tmp/shots/finished. Ход сценария пишется в tmp/shots/driver.log.
/// В этом режиме прогресс начинается с нуля и не сохраняется (см. SaveFile).
enum ShotMode {
    static let enabled = ProcessInfo.processInfo.arguments.contains("-shots")

    /// Окна по порядку, как в godot/scripts/debug/shot_driver.gd (имена снимков совпадают с GameSheet).
    static let windows: [GameSheet] = [
        .storage, .workshop, .talents, .animals, .quests, .level, .house, .kitchen, .garden,
        .trader, .hunt, .trophies, .collection, .legacy, .wardrobe, .map, .events, .shop,
    ]

    private static var dir: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("shots", isDirectory: true)
    }

    private static var request: URL { dir.appendingPathComponent("request") }

    /// Чистая папка обмена в начале сценария.
    static func prepare() {
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        log("start, dir: \(dir.path)")
    }

    static func pause(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    /// Попросить снимок и дождаться, пока workflow его сделает (не дольше 30 с).
    static func shot(_ name: String) async {
        log("shot request: \(name)")
        try? Data(name.utf8).write(to: request, options: .atomic)
        let deadline = Date().addingTimeInterval(30)
        while FileManager.default.fileExists(atPath: request.path) && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
        if FileManager.default.fileExists(atPath: request.path) {
            try? FileManager.default.removeItem(at: request)
            log("shot timeout: \(name)")
        } else {
            log("shot done: \(name)")
        }
    }

    static func finish() {
        log("finished")
        try? Data("done".utf8).write(to: dir.appendingPathComponent("finished"), options: .atomic)
    }

    static func log(_ text: String) {
        let line = Data("[shots] \(text)\n".utf8)
        FileHandle.standardError.write(line)
        let file = dir.appendingPathComponent("driver.log")
        if let handle = try? FileHandle(forWritingTo: file) {
            handle.seekToEndOfFile()
            handle.write(line)
            try? handle.close()
        } else {
            try? line.write(to: file)
        }
    }
}
