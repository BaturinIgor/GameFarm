import GameKit
import MessageUI
import StoreKit
import SwiftUI
import UIKit

/// Что включено в этой сборке. Флаги лежат в Info.plist (project.yml), чтобы для App Store
/// их можно было включить без правок кода. Сборке через SideStore iCloud и Game Center недоступны.
enum Distribution {
    private static func flag(_ key: String) -> Bool {
        (Bundle.main.object(forInfoDictionaryKey: key) as? Bool) == true
    }

    /// Синхронизация прогресса через iCloud (нужен iCloud key-value storage в entitlements).
    static var cloudSync: Bool { flag("HHCloudSync") }
    /// Рейтинги Game Center (нужна игра в App Store Connect и таблицы рекордов).
    static var gameCenter: Bool { flag("HHGameCenter") }
    /// Сборка из App Store: можно просить оценку.
    static var appStore: Bool { flag("HHAppStore") }

    static var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(short) (\(build))"
    }

    /// Модель телефона, например iPhone16,2.
    static var deviceModel: String {
        var info = utsname()
        uname(&info)
        let mirror = Mirror(reflecting: info.machine)
        let id = mirror.children.reduce(into: "") { result, element in
            if let value = element.value as? Int8, value != 0 { result.append(Character(UnicodeScalar(UInt8(value)))) }
        }
        return id.isEmpty ? UIDevice.current.model : id
    }

    /// Верхний контроллер, чтобы показать системное окно поверх игры.
    @MainActor
    static func topController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.first?.windows.first
        var controller = window?.rootViewController
        while let presented = controller?.presentedViewController { controller = presented }
        return controller
    }
}

// MARK: Обратная связь

enum FeedbackTopic: String, CaseIterable, Identifiable {
    case bug, idea, other

    var id: String { rawValue }
    var title: String { tr("feedback.topic.\(rawValue)") }
    var icon: String {
        switch self {
        case .bug: "ladybug.fill"
        case .idea: "lightbulb.fill"
        case .other: "bubble.left.fill"
        }
    }
}

/// Письмо разработчику: тема, заготовка с версией игры и телефона, по желанию файл прогресса.
@MainActor
final class Feedback: NSObject, MFMailComposeViewControllerDelegate {
    static let shared = Feedback()

    /// Почта для писем из игры. Пока пустая, письмо открывается без адресата.
    static let address = ""

    func subject(_ topic: FeedbackTopic) -> String {
        "Harvest Hollow · \(topic.title) · \(Distribution.version)"
    }

    func body(_ game: GameState) -> String {
        """


        ---
        \(tr("feedback.bodyHint"))
        Version: \(Distribution.version)
        Device: \(Distribution.deviceModel), iOS \(UIDevice.current.systemVersion)
        Language: \(Lang.shared.code)
        Level: \(game.save.level), rebirths: \(game.save.rebirths)
        """
    }

    /// Открыть письмо. Если на телефоне не настроена Почта, пробуем ссылку mailto, а без адреса - окно "Поделиться".
    func compose(_ topic: FeedbackTopic, attachSave: Bool, game: GameState) {
        let subject = subject(topic)
        let body = body(game)
        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()
            mail.mailComposeDelegate = self
            if !Self.address.isEmpty { mail.setToRecipients([Self.address]) }
            mail.setSubject(subject)
            mail.setMessageBody(body, isHTML: false)
            if attachSave, let url = game.exportBackup(), let data = try? Data(contentsOf: url) {
                mail.addAttachmentData(data, mimeType: "application/json", fileName: url.lastPathComponent)
            }
            Distribution.topController()?.present(mail, animated: true)
            return
        }
        if !Self.address.isEmpty, var parts = URLComponents(string: "mailto:\(Self.address)") {
            parts.queryItems = [URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: body)]
            if let url = parts.url, UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                return
            }
        }
        var items: [Any] = [subject + "\n" + body]
        if attachSave, let url = game.exportBackup() { items.append(url) }
        let share = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let top = Distribution.topController() {
            share.popoverPresentationController?.sourceView = top.view
            top.present(share, animated: true)
        }
    }

    nonisolated func mailComposeController(_ controller: MFMailComposeViewController,
                                           didFinishWith result: MFMailComposeResult, error: Error?) {
        Task { @MainActor in
            controller.dismiss(animated: true)
            if result == .sent { GameState.shared.toast("px:quest", tr("feedback.sent")) }
        }
    }
}

// MARK: Оценка в App Store

enum Review {
    private static let key = "review.askedVersion"

    /// Попросить оценку в удачный момент (победа над боссом, круглый уровень). Не чаще раза за версию.
    @MainActor
    static func askIfAppropriate() {
        guard Distribution.appStore else { return }
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: key) != Distribution.version else { return }
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else { return }
        defaults.set(Distribution.version, forKey: key)
        AppStore.requestReview(in: scene)
    }
}

// MARK: iCloud

/// Прогресс в iCloud key-value хранилище. Загружаем только с согласия игрока:
/// если в облаке прогресс дальше локального, показываем вопрос.
final class CloudSync {
    static let shared = CloudSync()

    private let store = NSUbiquitousKeyValueStore.default
    private let saveKey = "save.v1"
    private var lastPush = Date.distantPast
    private var started = false
    /// Прогресс из облака, который игрок уже отказался загружать (чтобы не спрашивать снова).
    private var declinedScore = 0.0

    /// Мера прогресса: перерождения важнее уровня, уровень важнее опыта.
    static func score(_ save: SaveData) -> Double {
        Double(save.sparksEarned) * 1_000_000_000 + Double(save.level) * 10_000_000 + Double(save.xp) + Double(save.coinsEarned) / 1_000_000
    }

    @MainActor
    func start() {
        guard Distribution.cloudSync, !started else { return }
        started = true
        NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                               object: store, queue: .main) { _ in
            Task { @MainActor in CloudSync.shared.checkRemote() }
        }
        store.synchronize()
        checkRemote()
    }

    /// Отправить прогресс в облако не чаще раза в минуту (или сразу при уходе в фон).
    func push(_ save: SaveData, force: Bool = false) {
        guard Distribution.cloudSync, force || Date().timeIntervalSince(lastPush) > 60 else { return }
        guard let data = SaveFile.encode(save), data.count < 900_000 else { return }
        // Не затираем облако, если там прогресс дальше: сначала игрок должен решить, что оставить.
        if let remote = remoteSave(), Self.score(remote) > Self.score(save) { return }
        lastPush = Date()
        store.set(data, forKey: saveKey)
        store.synchronize()
    }

    func remoteSave() -> SaveData? {
        guard let data = store.data(forKey: saveKey) else { return nil }
        return SaveFile.decode(data)
    }

    @MainActor
    private func checkRemote() {
        let game = GameState.shared
        guard let remote = remoteSave() else { return }
        let score = Self.score(remote)
        guard score > Self.score(game.save), score != declinedScore else { return }
        // Спрашиваем один раз за запуск: если игрок откажется, этот облачный прогресс больше не предлагаем.
        declinedScore = score
        Dialogs.shared.confirm(tr("cloud.found", remote.level), message: tr("cloud.found.message", game.save.level),
                               icon: "px:scroll2", confirm: tr("cloud.load"), tone: .green) {
            game.restoreBackup(remote)
        }
    }
}

// MARK: Game Center

/// Таблицы рекордов. Идентификаторы должны совпадать с таблицами в App Store Connect.
enum Leaderboard: String, CaseIterable {
    case eventStage = "hh.event.stage"
    case dungeonFloor = "hh.dungeon.floor"
    case level = "hh.level"
    case rebirths = "hh.rebirths"
}

@Observable
final class GameCenter {
    static let shared = GameCenter()

    private(set) var authenticated = false

    @MainActor
    func authenticate() {
        guard Distribution.gameCenter else { return }
        GKLocalPlayer.local.authenticateHandler = { controller, _ in
            Task { @MainActor in
                if let controller { Distribution.topController()?.present(controller, animated: true) }
                GameCenter.shared.authenticated = GKLocalPlayer.local.isAuthenticated
                if GameCenter.shared.authenticated { GameCenter.shared.submitAll(GameState.shared) }
            }
        }
    }

    func submit(_ board: Leaderboard, _ value: Int) {
        guard Distribution.gameCenter, authenticated, value > 0 else { return }
        GKLeaderboard.submitScore(value, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [board.rawValue]) { _ in }
    }

    /// Отправить все рекорды разом (после входа в Game Center).
    func submitAll(_ game: GameState) {
        submit(.level, game.save.bestLevel)
        submit(.rebirths, game.save.rebirths)
        submit(.eventStage, game.save.eventBest)
        submit(.dungeonFloor, DungeonID.allCases.map { game.dungeonBest($0) }.reduce(0, +))
    }

    @MainActor
    func show() {
        guard Distribution.gameCenter else { return }
        let controller = GKGameCenterViewController(state: .leaderboards)
        controller.gameCenterDelegate = GameCenterDismisser.shared
        Distribution.topController()?.present(controller, animated: true)
    }
}

final class GameCenterDismisser: NSObject, GKGameCenterControllerDelegate {
    static let shared = GameCenterDismisser()

    func gameCenterViewControllerDidFinish(_ controller: GKGameCenterViewController) {
        controller.dismiss(animated: true)
    }
}
