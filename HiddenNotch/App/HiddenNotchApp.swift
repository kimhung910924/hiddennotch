import AppKit

/// 앱 진입점.
///
/// SwiftUI `App` 대신 AppKit 수명주기를 직접 사용한다. 메뉴바 전용 앱이라
/// 씬(scene)이나 윈도우 그룹이 필요 없고, Dock 비표시 정책을 `NSApplication`이
/// 첫 화면을 그리기 전에 확정해야 하기 때문이다.
@main
enum HiddenNotchApp {
    /// `NSApplication.delegate`는 약한 참조라 여기서 강한 참조를 유지한다.
    @MainActor private static var retainedDelegate: AppDelegate?

    @MainActor
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let delegate = AppDelegate()
        retainedDelegate = delegate
        app.delegate = delegate

        app.run()
    }
}
