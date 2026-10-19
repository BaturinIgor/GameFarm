import Foundation
import Observation

/// Язык игры. Тексты лежат в Resources/Strings/<код>.json, английский служит запасным.
@Observable
final class Lang {
    static let shared = Lang()

    struct Option: Identifiable, Hashable {
        let code: String
        let name: String
        var id: String { code }
    }

    static let options: [Option] = [
        Option(code: "en", name: "English"),
        Option(code: "ru", name: "Русский"),
        Option(code: "de", name: "Deutsch"),
        Option(code: "fr", name: "Français"),
        Option(code: "es", name: "Español"),
        Option(code: "pt-BR", name: "Português (Brasil)"),
        Option(code: "it", name: "Italiano"),
        Option(code: "tr", name: "Türkçe"),
        Option(code: "pl", name: "Polski"),
        Option(code: "zh-Hans", name: "简体中文"),
        Option(code: "zh-Hant", name: "繁體中文"),
        Option(code: "ja", name: "日本語"),
        Option(code: "ko", name: "한국어"),
        Option(code: "id", name: "Bahasa Indonesia"),
        Option(code: "vi", name: "Tiếng Việt"),
        Option(code: "th", name: "ไทย"),
        Option(code: "hi", name: "हिन्दी")
    ]

    private(set) var code: String
    private(set) var table: [String: String]
    @ObservationIgnored private let fallback: [String: String]
    @ObservationIgnored private(set) var locale: Locale

    private init() {
        fallback = Self.load("en")
        let saved = UserDefaults.standard.string(forKey: "language")
        let initial = saved.flatMap { code in Self.options.contains { $0.code == code } ? code : nil } ?? Self.detect()
        code = initial
        table = Self.load(initial)
        locale = Locale(identifier: initial)
    }

    var name: String { Self.options.first { $0.code == code }?.name ?? code }

    func set(_ newCode: String) {
        guard newCode != code, Self.options.contains(where: { $0.code == newCode }) else { return }
        locale = Locale(identifier: newCode)
        table = Self.load(newCode)
        code = newCode
        UserDefaults.standard.set(newCode, forKey: "language")
    }

    /// Язык системы, если игра его поддерживает, иначе английский.
    static func detect() -> String {
        for preferred in Locale.preferredLanguages {
            let lower = preferred.lowercased()
            if lower.hasPrefix("zh") {
                let traditional = lower.contains("hant") || lower.contains("-tw") || lower.contains("-hk") || lower.contains("-mo")
                return traditional ? "zh-Hant" : "zh-Hans"
            }
            if lower.hasPrefix("pt") { return "pt-BR" }
            let base = String(lower.prefix { $0 != "-" && $0 != "_" })
            if let match = options.first(where: { $0.code == base }) { return match.code }
        }
        return "en"
    }

    private static func load(_ code: String) -> [String: String] {
        guard let url = Bundle.main.url(forResource: code, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return dict
    }

    func string(_ key: String) -> String {
        table[key] ?? fallback[key] ?? key
    }
}

/// Перевод по ключу. {0}, {1} в строке заменяются аргументами.
func tr(_ key: String, _ args: Any...) -> String {
    var text = Lang.shared.string(key)
    for (index, arg) in args.enumerated() {
        text = text.replacingOccurrences(of: "{\(index)}", with: "\(arg)")
    }
    return text
}
