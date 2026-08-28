import Foundation

/// 오버레이 창의 위치와 크기를 계산한다. 높이를 하드코딩하지 않는다.
enum OverlayGeometry {
    /// 창 프레임 비교에 쓰는 허용 오차. 배율이 다른 화면 사이를 오갈 때
    /// 서브픽셀 반올림 차이로 watchdog이 헛돌지 않게 한다.
    static let frameTolerance: CGFloat = 0.5

    /// 덮어야 할 화면 상단 영역의 높이.
    ///
    /// 노치 높이(safe area), 보조 영역 높이, 실제 메뉴바 높이 중 가장 큰 값을 쓴다.
    /// 전부 0이면 지금 이 화면에는 덮을 메뉴바가 없다는 뜻이다 — 전체화면 앱이
    /// 화면을 차지한 상태가 대표적이며, 이때는 오버레이를 만들지 않는다.
    ///
    /// 메뉴바 높이는 두 경로로 구한다. `visibleFrame`이 줄어든 만큼(내장 화면)과
    /// 실제 메뉴바 창에서 읽은 높이(외부 모니터). 외부 모니터는 메뉴바가 있어도
    /// `visibleFrame`이 줄지 않아 앞쪽 경로만으로는 0이 나온다.
    static func topInset(for screen: ScreenSnapshot) -> CGFloat {
        let inferredMenuBar = max(0, screen.frame.maxY - screen.visibleFrame.maxY)
        return max(
            screen.safeAreaTop,
            screen.auxiliaryTopHeight,
            inferredMenuBar,
            screen.systemMenuBarHeight
        )
    }

    /// 화면 좌표계(원점 좌하단) 기준 오버레이 프레임. 덮을 영역이 없으면 nil.
    static func overlayFrame(for screen: ScreenSnapshot) -> CGRect? {
        let height = topInset(for: screen)
        guard height > frameTolerance, screen.frame.width > 0 else { return nil }

        return CGRect(
            x: screen.frame.minX,
            y: screen.frame.maxY - height,
            width: screen.frame.width,
            height: height
        )
    }

    static func matches(_ lhs: CGRect, _ rhs: CGRect, tolerance: CGFloat = frameTolerance) -> Bool {
        abs(lhs.minX - rhs.minX) <= tolerance
            && abs(lhs.minY - rhs.minY) <= tolerance
            && abs(lhs.width - rhs.width) <= tolerance
            && abs(lhs.height - rhs.height) <= tolerance
    }
}
