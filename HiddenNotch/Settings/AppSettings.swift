import Foundation

/// `UserDefaults`에 저장하는 값은 이 두 개뿐이다.
///
/// 화면 ID·좌표·해상도·배경화면 경로 같은 디스플레이 관련 값은 의도적으로
/// 저장하지 않는다. 저장된 값이 실제 하드웨어 상태와 어긋나는 순간이
/// "한 번 풀리면 재설치해야 하는" 고장의 시작점이기 때문이다.
final class AppSettings {
    static let shared = AppSettings()

    private enum Key {
        static let isEnabled = "isEnabled"
        static let launchAtLoginRequested = "launchAtLoginRequested"
        static let applyToAllScreens = "applyToAllScreens"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.isEnabled: true,
            Key.launchAtLoginRequested: true,
            Key.applyToAllScreens: false,
        ])
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: Key.isEnabled) }
        set { defaults.set(newValue, forKey: Key.isEnabled) }
    }

    var launchAtLoginRequested: Bool {
        get { defaults.bool(forKey: Key.launchAtLoginRequested) }
        set { defaults.set(newValue, forKey: Key.launchAtLoginRequested) }
    }

    /// 노치가 없는 외부 모니터의 메뉴바까지 검게 만들지 여부.
    /// 기본값은 꺼짐이며, 이때는 노치 화면에만 적용된다.
    var applyToAllScreens: Bool {
        get { defaults.bool(forKey: Key.applyToAllScreens) }
        set { defaults.set(newValue, forKey: Key.applyToAllScreens) }
    }
}
