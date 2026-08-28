import XCTest
@testable import HiddenNotch

@MainActor
final class RebuildSchedulerTests: XCTestCase {
    /// 외부 모니터 연결 한 번에 여러 알림이 몰려도 즉시 적용은 한 번이어야 한다.
    func testBurstOfEventsCollapsesIntoOneImmediateRebuild() {
        var reasons: [String] = []
        let scheduler = RebuildScheduler(followUps: [], debounce: 0.05) { reasons.append($0) }

        scheduler.request(reason: "a")
        scheduler.request(reason: "b")
        scheduler.request(reason: "c")

        wait(seconds: 0.3)
        XCTAssertEqual(reasons, ["c"])
    }

    /// macOS가 화면 좌표를 뒤늦게 확정하는 경우를 위해 지연 재확인이 뒤따라야 한다.
    func testFollowUpChecksRunAfterInitialRebuild() {
        var count = 0
        let scheduler = RebuildScheduler(followUps: [0.05, 0.1], debounce: 0.01) { _ in count += 1 }

        scheduler.request(reason: "display")

        wait(seconds: 0.4)
        XCTAssertEqual(count, 3, "즉시 1회 + 재확인 2회")
    }

    func testImmediateRequestDoesNotWaitForDebounce() {
        var reasons: [String] = []
        let scheduler = RebuildScheduler(followUps: [], debounce: 5.0) { reasons.append($0) }

        scheduler.requestImmediately(reason: "manual")

        XCTAssertEqual(reasons, ["manual"])
    }

    func testCancelPendingStopsQueuedAndFollowUpWork() {
        var count = 0
        let scheduler = RebuildScheduler(followUps: [0.05], debounce: 0.05) { _ in count += 1 }

        scheduler.request(reason: "display")
        scheduler.cancelPending()

        wait(seconds: 0.3)
        XCTAssertEqual(count, 0)
    }

    func testNewRequestSupersedesPreviousFollowUps() {
        var reasons: [String] = []
        let scheduler = RebuildScheduler(followUps: [0.2], debounce: 0.01) { reasons.append($0) }

        scheduler.request(reason: "first")
        wait(seconds: 0.05)
        scheduler.request(reason: "second")
        wait(seconds: 0.4)

        XCTAssertEqual(reasons, ["first", "second", "second+0.2s"])
    }

    private func wait(seconds: TimeInterval) {
        let expectation = expectation(description: "wait \(seconds)")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { expectation.fulfill() }
        wait(for: [expectation], timeout: seconds + 2)
    }
}
