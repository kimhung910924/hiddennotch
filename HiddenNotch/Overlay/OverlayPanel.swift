import AppKit

/// 화면 상단을 덮는 검은 패널 하나.
///
/// 배경화면 바로 위, 나머지 모든 것의 아래에 놓인다. 메뉴바는 반투명해서 뒤에 있는
/// 것을 비추므로, 레벨이 아무리 낮아도 그 뒤가 검으면 메뉴바 배경과 노치 양옆이
/// 함께 검게 보인다. 메뉴바 글자·아이콘은 그대로 보인다.
///
/// 레벨을 낮게 두는 이유는 메뉴바가 *없는* 상황 때문이다. 미션 컨트롤과 전체화면
/// 앱은 화면 맨 위까지 자기 UI를 그리는데, 이 패널이 위에 있으면 그 UI를 잘라먹는다.
/// 메뉴바 영역은 원래 일반 창이 침범하지 못하는 자리라, 낮은 레벨에 둬도 평상시에는
/// 가려질 일이 없다.
final class OverlayPanel: NSPanel {
    init(frame: CGRect) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = true
        backgroundColor = .black
        hasShadow = false
        ignoresMouseEvents = true
        isMovable = false
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        animationBehavior = .none
        level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]

        // NSColor.black은 화면 색 프로파일에 따라 변환될 수 있어, 실제로 칠하는
        // 면은 색 공간을 고정한 순수 검정으로 둔다.
        let view = NSView(frame: CGRect(origin: .zero, size: frame.size))
        view.wantsLayer = true
        view.layer?.backgroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceGray(), components: [0, 1])
        contentView = view

        setFrame(frame, display: false)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// AppKit은 일반 창이 메뉴바를 덮지 않도록 프레임을 아래로 밀어낸다.
    /// 이 패널은 바로 그 영역을 덮는 것이 목적이므로 제약을 받지 않는다.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    func show() {
        orderFrontRegardless()
    }
}
