import AppKit

/// 화면별 오버레이의 생성·제거와 무결성 확인을 담당한다.
///
/// 화면 구성이 바뀌면 기존 창의 프레임을 고쳐 쓰지 않고 전부 버리고 새로 만든다.
/// 부분 수정은 macOS가 화면 목록을 단계적으로 확정하는 동안 어긋난 상태로
/// 굳어버릴 수 있기 때문이다.
@MainActor
final class OverlayController {
    private var panels: [CGDirectDisplayID: OverlayPanel] = [:]
    private var appliedFrames: [CGDirectDisplayID: CGRect] = [:]

    var overlayCount: Int { panels.count }

    /// 주어진 화면들에 맞춰 오버레이 전체를 다시 만든다.
    /// - Returns: 실제로 만들어진 오버레이 수.
    @discardableResult
    func rebuild(for screens: [ScreenSnapshot]) -> Int {
        teardown()

        for screen in screens {
            guard let frame = OverlayGeometry.overlayFrame(for: screen) else { continue }
            let panel = OverlayPanel(frame: frame)
            panel.show()
            panels[screen.displayID] = panel
            appliedFrames[screen.displayID] = frame
        }

        return panels.count
    }

    func teardown() {
        for panel in panels.values {
            panel.orderOut(nil)
            panel.close()
        }
        panels.removeAll()
        appliedFrames.removeAll()
    }

    /// 지금 화면 상태와 현재 오버레이가 일치하는지 확인한다.
    ///
    /// 창 생성 없이 비교만 하므로 watchdog에서 반복 호출해도 부담이 없다.
    func isConsistent(with screens: [ScreenSnapshot]) -> Bool {
        var expected: [CGDirectDisplayID: CGRect] = [:]
        for screen in screens {
            if let frame = OverlayGeometry.overlayFrame(for: screen) {
                expected[screen.displayID] = frame
            }
        }

        guard expected.count == panels.count else { return false }

        for (displayID, frame) in expected {
            guard let panel = panels[displayID] else { return false }
            guard panel.isVisible else { return false }
            guard OverlayGeometry.matches(panel.frame, frame) else { return false }
            // 창이 붙어 있는 화면 자체가 사라졌거나 바뀐 경우.
            guard let panelScreen = panel.screen,
                  ScreenSnapshot(screen: panelScreen).displayID == displayID else { return false }
        }

        return true
    }
}
