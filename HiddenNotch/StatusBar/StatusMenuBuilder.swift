import AppKit

/// 메뉴바 메뉴를 구성한다. 설정 창은 만들지 않는다.
@MainActor
enum StatusMenuBuilder {
    enum Item: Int {
        case toggleEnabled = 1
        case toggleAllScreens
        case toggleLaunchAtLogin
        case reapply
        case openLoginItemsSettings
        case quit
    }

    struct State {
        var isEnabled: Bool
        var applyToAllScreens: Bool
        var launchAtLoginEnabled: Bool
        var launchAtLoginNeedsApproval: Bool
    }

    /// 메뉴 내용을 현재 상태로 다시 채운다.
    ///
    /// 새 메뉴를 만들어 갈아 끼우지 않고 기존 메뉴를 비우고 채우는 이유는,
    /// 메뉴가 열릴 때마다(`menuNeedsUpdate`) 호출해 체크 표시를 항상 실제
    /// 상태와 맞추기 위해서다. 시스템 설정에서 로그인 항목을 바꾸는 등
    /// 앱 바깥에서 상태가 변해도 다음에 열 때 바로 반영된다.
    static func populate(_ menu: NSMenu, state: State, target: AnyObject, action: Selector) {
        menu.removeAllItems()
        menu.autoenablesItems = false

        let title = NSMenuItem(title: "HiddenNotch", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())

        menu.addItem(makeItem(
            "노치 숨기기",
            item: .toggleEnabled,
            checked: state.isEnabled,
            target: target,
            action: action
        ))

        menu.addItem(makeItem(
            "외부 모니터에도 적용",
            item: .toggleAllScreens,
            checked: state.applyToAllScreens,
            target: target,
            action: action
        ))

        menu.addItem(makeItem(
            "로그인 시 자동 실행",
            item: .toggleLaunchAtLogin,
            checked: state.launchAtLoginEnabled,
            target: target,
            action: action
        ))

        if state.launchAtLoginNeedsApproval {
            menu.addItem(makeItem(
                "로그인 항목 승인 필요 — 시스템 설정 열기",
                item: .openLoginItemsSettings,
                checked: false,
                target: target,
                action: action
            ))
        }

        menu.addItem(makeItem(
            "다시 적용",
            item: .reapply,
            checked: false,
            target: target,
            action: action
        ))

        menu.addItem(.separator())
        menu.addItem(makeItem(
            "HiddenNotch 종료",
            item: .quit,
            checked: false,
            target: target,
            action: action
        ))
    }

    private static func makeItem(
        _ title: String,
        item: Item,
        checked: Bool,
        target: AnyObject,
        action: Selector
    ) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: "")
        menuItem.target = target
        menuItem.tag = item.rawValue
        menuItem.state = checked ? .on : .off
        menuItem.isEnabled = true
        return menuItem
    }
}
