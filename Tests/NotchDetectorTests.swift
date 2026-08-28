import XCTest
@testable import HiddenNotch

final class NotchDetectorTests: XCTestCase {
    func testBuiltInNotchScreenIsDetected() {
        let screen = ScreenSnapshot.stub(safeAreaTop: 37, auxiliaryTopHeight: 37, hasAuxiliaryTopArea: true)
        XCTAssertTrue(NotchDetector.hasNotch(screen))
    }

    func testExternalDisplayIsNotDetected() {
        let screen = ScreenSnapshot.stub(
            frame: CGRect(x: 1512, y: 0, width: 2560, height: 1440),
            visibleFrame: CGRect(x: 1512, y: 0, width: 2560, height: 1415),
            safeAreaTop: 0,
            auxiliaryTopHeight: 0,
            hasAuxiliaryTopArea: false
        )
        XCTAssertFalse(NotchDetector.hasNotch(screen))
    }

    /// 메뉴바를 자동으로 가리는 설정에서는 safeAreaInsets.top이 0으로 떨어져도
    /// 노치는 그대로 있다. 보조 영역 신호로 판정이 유지되어야 한다.
    func testNotchStillDetectedWhenSafeAreaCollapses() {
        let screen = ScreenSnapshot.stub(safeAreaTop: 0, auxiliaryTopHeight: 37, hasAuxiliaryTopArea: true)
        XCTAssertTrue(NotchDetector.hasNotch(screen))
    }

    func testOnlyNotchScreensAreReturnedRegardlessOfOrder() {
        let external = ScreenSnapshot.stub(
            displayID: 2,
            frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
            visibleFrame: CGRect(x: 0, y: 0, width: 2560, height: 1415),
            safeAreaTop: 0,
            auxiliaryTopHeight: 0,
            hasAuxiliaryTopArea: false
        )
        let builtIn = ScreenSnapshot.stub(displayID: 1, safeAreaTop: 37, auxiliaryTopHeight: 37, hasAuxiliaryTopArea: true)

        // 외부 모니터가 주 디스플레이라 목록 앞에 오더라도 내장 화면이 선택되어야 한다.
        let targets = NotchDetector.notchScreens(in: [external, builtIn])
        XCTAssertEqual(targets.map(\.displayID), [1])
    }

    func testNoScreensProducesNoTargets() {
        XCTAssertTrue(NotchDetector.notchScreens(in: []).isEmpty)
    }

    /// 기본값에서는 노치 화면만 대상이다(기획안 완료 기준 7).
    func testDefaultScopeCoversNotchScreensOnly() {
        let screens = [ScreenSnapshot.stub(displayID: 1), .externalStub()]
        let targets = OverlayTargets.screens(in: screens, applyToAllScreens: false)
        XCTAssertEqual(targets.map(\.displayID), [1])
    }

    func testAllScreensScopeIncludesExternalDisplays() {
        let screens = [ScreenSnapshot.stub(displayID: 1), .externalStub()]
        let targets = OverlayTargets.screens(in: screens, applyToAllScreens: true)
        XCTAssertEqual(targets.map(\.displayID), [1, 2])
    }
}

extension ScreenSnapshot {
    static func stub(
        displayID: CGDirectDisplayID = 1,
        frame: CGRect = CGRect(x: 0, y: 0, width: 1512, height: 982),
        visibleFrame: CGRect = CGRect(x: 0, y: 0, width: 1512, height: 945),
        safeAreaTop: CGFloat = 37,
        auxiliaryTopHeight: CGFloat = 37,
        hasAuxiliaryTopArea: Bool = true,
        systemMenuBarHeight: CGFloat = 0,
        backingScaleFactor: CGFloat = 2,
        localizedName: String = "Built-in Retina Display"
    ) -> ScreenSnapshot {
        ScreenSnapshot(
            displayID: displayID,
            frame: frame,
            visibleFrame: visibleFrame,
            safeAreaTop: safeAreaTop,
            auxiliaryTopHeight: auxiliaryTopHeight,
            hasAuxiliaryTopArea: hasAuxiliaryTopArea,
            systemMenuBarHeight: systemMenuBarHeight,
            backingScaleFactor: backingScaleFactor,
            localizedName: localizedName
        )
    }

    /// 노치 없는 외부 모니터. `visibleFrame`이 메뉴바만큼 줄지 않는 실제 동작을 반영한다.
    static func externalStub(
        displayID: CGDirectDisplayID = 2,
        frame: CGRect = CGRect(x: -1920, y: 60, width: 1920, height: 1080),
        systemMenuBarHeight: CGFloat = 30
    ) -> ScreenSnapshot {
        stub(
            displayID: displayID,
            frame: frame,
            visibleFrame: frame,
            safeAreaTop: 0,
            auxiliaryTopHeight: 0,
            hasAuxiliaryTopArea: false,
            systemMenuBarHeight: systemMenuBarHeight,
            backingScaleFactor: 1,
            localizedName: "External Display"
        )
    }
}
