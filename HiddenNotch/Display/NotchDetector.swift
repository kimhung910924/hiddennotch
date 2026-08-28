import Foundation

/// 노치가 있는 디스플레이를 판정한다.
///
/// 화면 이름, 메인 디스플레이 여부, 저장해 둔 화면 번호는 판정에 쓰지 않는다.
/// 외부 모니터가 주 디스플레이가 되어도 내장 화면 판정이 흔들리면 안 되기 때문이다.
enum NotchDetector {
    static func hasNotch(_ screen: ScreenSnapshot) -> Bool {
        // 노치 화면에서만 존재하는 보조 영역이 1차 신호다. 메뉴바를 자동으로
        // 가리는 설정에서는 safeAreaInsets.top이 0으로 떨어질 수 있어
        // 이 값만 믿을 수는 없다.
        if screen.hasAuxiliaryTopArea && screen.auxiliaryTopHeight > 0 {
            return true
        }
        return screen.safeAreaTop > 0
    }

    static func notchScreens(in screens: [ScreenSnapshot]) -> [ScreenSnapshot] {
        screens.filter(hasNotch)
    }
}

/// 오버레이를 올릴 화면을 고른다.
enum OverlayTargets {
    static func screens(in screens: [ScreenSnapshot], applyToAllScreens: Bool) -> [ScreenSnapshot] {
        applyToAllScreens ? screens : NotchDetector.notchScreens(in: screens)
    }
}
