import GoogleMobileAds
import Observation
import UIKit

/// Реклама только по желанию игрока и только за награду (Google AdMob).
/// Сейчас стоят тестовые идентификаторы Google: перед выпуском в App Store
/// их нужно заменить на свои из кабинета AdMob (здесь и в Info.plist).
@MainActor
@Observable
final class Ads: NSObject, FullScreenContentDelegate {
    static let shared = Ads()
    static let rewardedUnitID = "ca-app-pub-3940256099942544/1712485313"

    private(set) var ready = false
    private(set) var loading = false

    @ObservationIgnored private var ad: RewardedAd?
    @ObservationIgnored private var onReward: (() -> Void)?
    @ObservationIgnored private var earned = false
    @ObservationIgnored private var started = false

    private override init() {
        super.init()
    }

    func start() {
        guard !started else { return }
        started = true
        MobileAds.shared.start()
        Task { await load() }
    }

    private func load() async {
        guard ad == nil, !loading else { return }
        loading = true
        defer { loading = false }
        do {
            let loaded = try await RewardedAd.load(with: Self.rewardedUnitID, request: Request())
            loaded.fullScreenContentDelegate = self
            ad = loaded
            ready = true
        } catch {
            ready = false
        }
    }

    /// Показывает ролик и вызывает reward, если его досмотрели.
    /// Владельцы Pro получают награду сразу, без рекламы.
    func show(reward: @escaping () -> Void) {
        if GameState.shared.hasPro {
            reward()
            return
        }
        guard let ad, let root = Self.topController() else {
            #if SIDELOAD
            GameState.shared.toast("🧪", tr("ads.testSkipped"))
            reward()
            #else
            GameState.shared.toast("📺", tr("ads.notReady"))
            #endif
            Task { await load() }
            return
        }
        onReward = reward
        earned = false
        ad.present(from: root) { [weak self] in
            self?.earned = true
        }
    }

    private func finish() {
        if earned { onReward?() }
        onReward = nil
        earned = false
        ad = nil
        ready = false
        Task { await load() }
    }

    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in self.finish() }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            self.earned = false
            self.finish()
        }
    }

    private static func topController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.first?.windows.first
        var controller = window?.rootViewController
        while let presented = controller?.presentedViewController { controller = presented }
        return controller
    }
}
