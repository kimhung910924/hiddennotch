import AppKit
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings.shared
    private let log = Logger(subsystem: "com.rrllab.HiddenNotch", category: "app")

    private lazy var coordinator = DisplayCoordinator(settings: settings)
    private lazy var scheduler = RebuildScheduler { [weak self] reason in
        self?.coordinator.rebuild(reason: reason)
    }
    private lazy var eventMonitor = SystemEventMonitor { [weak self] reason in
        self?.scheduler.request(reason: reason)
    }
    private lazy var watchdog = OverlayWatchdog { [weak self] in
        self?.coordinator.isConsistent() ?? true
    } onDrift: { [weak self] in
        self?.scheduler.request(reason: "watchdog")
    }
    private lazy var statusBar = StatusBarController(settings: settings, delegate: self)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusBar.install()
        eventMonitor.start()
        watchdog.start()

        syncLaunchAtLoginWithRequest()
        applyAtStartup(attemptsLeft: 3)
        UpdateController.shared.start()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        scheduler.request(reason: "app-active")
    }

    func applicationWillTerminate(_ notification: Notification) {
        scheduler.cancelPending()
        watchdog.stop()
        coordinator.teardown()
        statusBar.remove()
    }

    /// 시작 시에는 이전 실행의 화면 상태를 복원하지 않는다. 지금 연결된 화면을
    /// 새로 조회해 적용하고, 노치 화면이 있는데도 오버레이가 만들어지지 않으면
    /// 짧은 간격으로 다시 시도한다.
    private func applyAtStartup(attemptsLeft: Int) {
        scheduler.requestImmediately(reason: "launch")

        guard attemptsLeft > 1 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self, self.coordinator.isEnabled, !self.coordinator.isConsistent() else { return }
            self.log.debug("startup retry, attemptsLeft=\(attemptsLeft - 1)")
            self.applyAtStartup(attemptsLeft: attemptsLeft - 1)
        }
    }

    /// 사용자가 원한 자동 실행 상태와 실제 등록 상태를 맞춘다.
    /// 승인 대기 상태는 사용자가 시스템 설정에서 처리해야 하므로 건드리지 않는다.
    private func syncLaunchAtLoginWithRequest() {
        guard !LoginItemManager.needsUserApproval else { return }
        guard settings.launchAtLoginRequested != LoginItemManager.isEnabled else { return }

        do {
            try LoginItemManager.setEnabled(settings.launchAtLoginRequested)
        } catch {
            log.error("login item sync failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

extension AppDelegate: StatusBarControllerDelegate {
    func statusBarDidToggleEnabled() {
        coordinator.setEnabled(!settings.isEnabled)
    }

    func statusBarDidToggleAllScreens() {
        coordinator.setApplyToAllScreens(!settings.applyToAllScreens)
    }

    func statusBarDidToggleLaunchAtLogin() {
        let desired = !LoginItemManager.isEnabled
        settings.launchAtLoginRequested = desired
        do {
            try LoginItemManager.setEnabled(desired)
        } catch {
            log.error("login item toggle failed: \(error.localizedDescription, privacy: .public)")
            LoginItemManager.openLoginItemsSettings()
        }
    }

    func statusBarDidRequestReapply() {
        scheduler.requestImmediately(reason: "manual")
    }

    func statusBarDidRequestLoginItemsSettings() {
        LoginItemManager.openLoginItemsSettings()
    }

    func statusBarDidRequestQuit() {
        NSApp.terminate(nil)
    }
}
