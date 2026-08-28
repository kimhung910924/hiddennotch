import AppKit
import ServiceManagement

/// 로그인 시 자동 실행 등록. macOS 13 이상의 `SMAppService`만 사용한다.
enum LoginItemManager {
    static var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    static var isEnabled: Bool {
        status == .enabled
    }

    /// 사용자가 시스템 설정에서 직접 승인해야 하는 상태인지.
    static var needsUserApproval: Bool {
        status == .requiresApproval
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            // 이미 등록된 상태에서 register를 다시 호출하면 오류가 날 수 있다.
            guard status != .enabled else { return }
            try SMAppService.mainApp.register()
        } else {
            guard status != .notRegistered else { return }
            try SMAppService.mainApp.unregister()
        }
    }

    static func openLoginItemsSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }
}
