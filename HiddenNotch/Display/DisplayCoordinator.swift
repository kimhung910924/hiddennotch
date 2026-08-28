import AppKit
import os

/// 화면 조회 → 노치 감지 → 오버레이 재구성으로 이어지는 한 번의 사이클을 책임진다.
@MainActor
final class DisplayCoordinator {
    private let settings: AppSettings
    private let overlays = OverlayController()
    private let log = Logger(subsystem: "com.rrllab.HiddenNotch", category: "display")

    init(settings: AppSettings) {
        self.settings = settings
    }

    var isEnabled: Bool { settings.isEnabled }

    /// 오버레이를 전부 버리고 현재 화면 구성에 맞춰 새로 만든다.
    /// - Returns: 생성된 오버레이 수. 기능이 꺼져 있으면 0.
    @discardableResult
    func rebuild(reason: String) -> Int {
        guard settings.isEnabled else {
            overlays.teardown()
            log.debug("rebuild skipped (disabled): \(reason, privacy: .public)")
            return 0
        }

        let screens = ScreenSnapshot.currentScreens()
        let targets = OverlayTargets.screens(in: screens, applyToAllScreens: settings.applyToAllScreens)
        let count = overlays.rebuild(for: targets)

        log.debug("rebuild(\(reason, privacy: .public)): screens=\(screens.count) targets=\(targets.count) overlays=\(count)")
        return count
    }

    func setEnabled(_ enabled: Bool) {
        settings.isEnabled = enabled
        if enabled {
            rebuild(reason: "toggle-on")
        } else {
            overlays.teardown()
        }
    }

    func setApplyToAllScreens(_ applyToAll: Bool) {
        settings.applyToAllScreens = applyToAll
        rebuild(reason: "scope-change")
    }

    func teardown() {
        overlays.teardown()
    }

    /// watchdog용 무결성 확인. 기대 상태와 어긋나면 false.
    func isConsistent() -> Bool {
        guard settings.isEnabled else { return overlays.overlayCount == 0 }
        let targets = OverlayTargets.screens(
            in: ScreenSnapshot.currentScreens(),
            applyToAllScreens: settings.applyToAllScreens
        )
        return overlays.isConsistent(with: targets)
    }
}
