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

        // 이미 맞으면 손대지 않는다.
        //
        // 재구성은 창을 전부 버리고 새로 만든다. 그 과정에서 키 윈도우가 바뀌면서
        // 열려 있던 메뉴바 메뉴가 함께 닫힌다. 앱이 활성화될 때마다(app-active)
        // 재구성이 도는데, 사용자가 메뉴를 여는 순간이 바로 활성화되는 순간이라
        // 메뉴가 1~2초 만에 저절로 사라졌다. (2026-08-28 실측)
        //
        // 화면 구성이 실제로 바뀌었을 때는 예전처럼 전부 새로 만든다. 부분 수정이
        // 어긋난 상태로 굳는 문제(OverlayController 주석 참고)는 그대로 피한다.
        if overlays.isConsistent(with: targets) {
            log.debug("rebuild skipped (already consistent): \(reason, privacy: .public)")
            return overlays.overlayCount
        }

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
