import XCTest
@testable import HiddenNotch

final class OverlayGeometryTests: XCTestCase {
    func testOverlayCoversFullWidthOfTopStrip() {
        let screen = ScreenSnapshot.stub()
        let frame = try? XCTUnwrap(OverlayGeometry.overlayFrame(for: screen))

        XCTAssertEqual(frame?.minX, 0)
        XCTAssertEqual(frame?.width, 1512)
        XCTAssertEqual(frame?.height, 37)
        XCTAssertEqual(frame?.maxY, 982, "오버레이 위쪽 끝은 화면 위쪽 끝과 같아야 한다")
    }

    func testOverlayUsesOffsetOriginOfSecondaryScreen() {
        let screen = ScreenSnapshot.stub(
            frame: CGRect(x: -1512, y: 300, width: 1512, height: 982),
            visibleFrame: CGRect(x: -1512, y: 300, width: 1512, height: 945)
        )
        let frame = OverlayGeometry.overlayFrame(for: screen)

        XCTAssertEqual(frame?.minX, -1512)
        XCTAssertEqual(frame?.minY, 300 + 982 - 37)
    }

    /// 노치보다 메뉴바가 두꺼운 구성에서는 메뉴바 높이를 따라간다.
    func testTopInsetUsesLargestOfAvailableSignals() {
        let screen = ScreenSnapshot.stub(
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 938),
            safeAreaTop: 37,
            auxiliaryTopHeight: 37
        )
        XCTAssertEqual(OverlayGeometry.topInset(for: screen), 44)
    }

    /// 전체화면 앱이 화면을 차지하면 덮을 메뉴바가 없다. 상단 콘텐츠를 가리지 않는다.
    func testNoOverlayWhenNothingToCover() {
        let screen = ScreenSnapshot.stub(
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            safeAreaTop: 0,
            auxiliaryTopHeight: 0,
            hasAuxiliaryTopArea: false
        )
        XCTAssertNil(OverlayGeometry.overlayFrame(for: screen))
    }

    func testHeightIsRecalculatedForScaledResolution() {
        let scaled = ScreenSnapshot.stub(
            frame: CGRect(x: 0, y: 0, width: 1800, height: 1169),
            visibleFrame: CGRect(x: 0, y: 0, width: 1800, height: 1125),
            safeAreaTop: 44,
            auxiliaryTopHeight: 44
        )
        XCTAssertEqual(OverlayGeometry.overlayFrame(for: scaled)?.height, 44)
    }

    /// 외부 모니터는 메뉴바가 있어도 visibleFrame이 줄지 않는다.
    /// 메뉴바 창에서 읽은 높이가 없으면 오버레이 크기를 알 수 없다.
    func testExternalDisplayUsesProbedMenuBarHeight() {
        let external = ScreenSnapshot.externalStub(systemMenuBarHeight: 30)
        let frame = OverlayGeometry.overlayFrame(for: external)

        XCTAssertEqual(frame?.height, 30)
        XCTAssertEqual(frame?.width, 1920)
        XCTAssertEqual(frame?.minX, -1920)
        XCTAssertEqual(frame?.maxY, 60 + 1080)
    }

    func testExternalDisplayWithoutMenuBarGetsNoOverlay() {
        let external = ScreenSnapshot.externalStub(systemMenuBarHeight: 0)
        XCTAssertNil(OverlayGeometry.overlayFrame(for: external))
    }

    func testFrameComparisonToleratesSubpixelDrift() {
        let a = CGRect(x: 0, y: 945, width: 1512, height: 37)
        let b = CGRect(x: 0.2, y: 945.3, width: 1512, height: 37)
        let c = CGRect(x: 0, y: 945, width: 1512, height: 44)

        XCTAssertTrue(OverlayGeometry.matches(a, b))
        XCTAssertFalse(OverlayGeometry.matches(a, c))
    }
}
