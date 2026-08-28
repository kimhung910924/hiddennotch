import AppKit

/// 특정 시점의 화면 상태를 값으로 떠낸 것.
///
/// 오래 들고 있으라고 만든 타입이 아니다. 노치 판정과 오버레이 좌표 계산을
/// `NSScreen`에서 분리해 순수 함수로 테스트할 수 있게 하고, 계산 도중에
/// 화면 구성이 바뀌어도 한 번의 재구성 안에서는 일관된 값을 쓰기 위한 것이다.
struct ScreenSnapshot: Equatable {
    let displayID: CGDirectDisplayID
    let frame: CGRect
    let visibleFrame: CGRect
    let safeAreaTop: CGFloat
    /// 노치 좌·우 보조 영역의 높이. 노치가 없으면 0.
    let auxiliaryTopHeight: CGFloat
    let hasAuxiliaryTopArea: Bool
    /// 이 화면에 실제로 놓인 메뉴바의 높이. 알 수 없으면 0.
    /// 외부 모니터는 `visibleFrame`으로 알아낼 수 없어 별도로 조회한다.
    let systemMenuBarHeight: CGFloat
    let backingScaleFactor: CGFloat
    let localizedName: String
}

extension ScreenSnapshot {
    init(screen: NSScreen, systemMenuBarHeight: CGFloat = 0) {
        let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        let left = screen.auxiliaryTopLeftArea
        let right = screen.auxiliaryTopRightArea

        self.init(
            displayID: CGDirectDisplayID(number?.uint32Value ?? 0),
            frame: screen.frame,
            visibleFrame: screen.visibleFrame,
            safeAreaTop: screen.safeAreaInsets.top,
            auxiliaryTopHeight: max(left?.height ?? 0, right?.height ?? 0),
            hasAuxiliaryTopArea: left != nil || right != nil,
            systemMenuBarHeight: systemMenuBarHeight,
            backingScaleFactor: screen.backingScaleFactor,
            localizedName: screen.localizedName
        )
    }

    /// 지금 이 순간 연결된 모든 화면. 호출할 때마다 새로 조회한다.
    static func currentScreens() -> [ScreenSnapshot] {
        let screens = NSScreen.screens
        guard let globalTop = screens.first?.frame.maxY else { return [] }

        // 창 목록 조회는 화면당 한 번이 아니라 재구성당 한 번만 한다.
        let menuBarRects = MenuBarProbe.menuBarRects()

        return screens.map { screen in
            ScreenSnapshot(
                screen: screen,
                systemMenuBarHeight: MenuBarProbe.menuBarHeight(
                    forScreenFrame: screen.frame,
                    globalTop: globalTop,
                    rects: menuBarRects
                )
            )
        }
    }
}
