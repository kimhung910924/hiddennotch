import AppKit

/// 오버레이가 풀릴 수 있는 시스템 이벤트를 모아 하나의 콜백으로 넘긴다.
@MainActor
final class SystemEventMonitor {
    private let onEvent: (String) -> Void
    private var tokens: [(NotificationCenter, NSObjectProtocol)] = []

    init(onEvent: @escaping (String) -> Void) {
        self.onEvent = onEvent
    }

    deinit {
        for (center, token) in tokens {
            center.removeObserver(token)
        }
    }

    func start() {
        let workspace = NSWorkspace.shared.notificationCenter
        let app = NotificationCenter.default

        observe(app, NSApplication.didChangeScreenParametersNotification, "screen-parameters")
        observe(workspace, NSWorkspace.didWakeNotification, "wake")
        observe(workspace, NSWorkspace.screensDidWakeNotification, "screens-wake")
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification, "session-active")
        observe(workspace, NSWorkspace.activeSpaceDidChangeNotification, "space-change")
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, _ reason: String) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.onEvent(reason)
            }
        }
        tokens.append((center, token))
    }
}
