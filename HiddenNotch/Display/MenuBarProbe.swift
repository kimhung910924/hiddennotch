import AppKit

/// 화면별 메뉴바 높이를 실제 메뉴바 창의 좌표에서 읽어 온다.
///
/// 내장 화면은 `visibleFrame`이 메뉴바만큼 줄어들어 높이를 알 수 있지만, 외부
/// 모니터는 메뉴바가 있어도 `visibleFrame == frame`이라 그 방법이 통하지 않는다.
/// 화면마다 메뉴바 높이가 다르므로(예: 내장 33pt, 외부 30pt) 하나를 골라 쓸 수도 없다.
///
/// 창 목록 조회는 공개 API이고 좌표·소유자만 읽으므로 화면 기록 권한이 필요 없다.
enum MenuBarProbe {
    /// CG 전역 좌표(원점 좌상단, Y 아래로 증가) 기준 메뉴바 창들의 사각형.
    static func menuBarRects() -> [CGRect] {
        let menuBarLevel = Int(CGWindowLevelForKey(.mainMenuWindow))
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        return list.compactMap { window in
            guard window[kCGWindowLayer as String] as? Int == menuBarLevel,
                  window[kCGWindowOwnerName as String] as? String == "Window Server",
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds)
            else { return nil }
            return rect
        }
    }

    /// 주어진 화면 위에 놓인 메뉴바의 높이. 찾지 못하면 0.
    ///
    /// - Parameter globalTop: CG 좌표 원점이 되는 주 화면의 위쪽 끝(NSScreen 좌표).
    static func menuBarHeight(
        forScreenFrame frame: CGRect,
        globalTop: CGFloat,
        rects: [CGRect],
        tolerance: CGFloat = 1
    ) -> CGFloat {
        let cgTop = globalTop - frame.maxY

        let match = rects.first { rect in
            abs(rect.minX - frame.minX) <= tolerance
                && abs(rect.minY - cgTop) <= tolerance
                && abs(rect.width - frame.width) <= tolerance
        }

        return match?.height ?? 0
    }
}
