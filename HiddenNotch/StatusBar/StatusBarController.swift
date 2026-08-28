import AppKit

@MainActor
protocol StatusBarControllerDelegate: AnyObject {
    func statusBarDidToggleEnabled()
    func statusBarDidToggleAllScreens()
    func statusBarDidToggleLaunchAtLogin()
    func statusBarDidRequestReapply()
    func statusBarDidRequestLoginItemsSettings()
    func statusBarDidRequestQuit()
}

/// 메뉴바 아이콘과 메뉴. 앱의 유일한 UI다.
///
/// 메뉴는 열릴 때마다 다시 채운다(`menuNeedsUpdate`). 로그인 항목처럼 앱 바깥에서
/// 바뀔 수 있는 상태의 체크 표시가 낡은 값으로 남지 않게 하기 위해서다.
@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let settings: AppSettings
    private weak var delegate: StatusBarControllerDelegate?
    private var statusItem: NSStatusItem?

    init(settings: AppSettings, delegate: StatusBarControllerDelegate) {
        self.settings = settings
        self.delegate = delegate
        super.init()
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "rectangle.tophalf.filled",
            accessibilityDescription: "HiddenNotch"
        )
        item.button?.image?.isTemplate = true

        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    func remove() {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let state = StatusMenuBuilder.State(
            isEnabled: settings.isEnabled,
            applyToAllScreens: settings.applyToAllScreens,
            launchAtLoginEnabled: LoginItemManager.isEnabled,
            launchAtLoginNeedsApproval: LoginItemManager.needsUserApproval
        )
        StatusMenuBuilder.populate(menu, state: state, target: self, action: #selector(handleMenuItem(_:)))
    }

    @objc private func handleMenuItem(_ sender: NSMenuItem) {
        guard let item = StatusMenuBuilder.Item(rawValue: sender.tag) else { return }
        switch item {
        case .toggleEnabled:
            delegate?.statusBarDidToggleEnabled()
        case .toggleAllScreens:
            delegate?.statusBarDidToggleAllScreens()
        case .toggleLaunchAtLogin:
            delegate?.statusBarDidToggleLaunchAtLogin()
        case .reapply:
            delegate?.statusBarDidRequestReapply()
        case .openLoginItemsSettings:
            delegate?.statusBarDidRequestLoginItemsSettings()
        case .checkForUpdates:
            UpdateController.shared.checkForUpdates()
        case .quit:
            delegate?.statusBarDidRequestQuit()
        }
    }
}
