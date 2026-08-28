import Foundation

/// 재구성 요청을 debounce하고, 한 번의 이벤트마다 지연 재확인을 예약한다.
///
/// 외부 모니터를 연결한 직후 macOS는 화면 목록과 좌표를 한 번에 확정하지 않는다.
/// 첫 통보 시점의 값만 믿으면 좌표가 어긋난 채로 남으므로, 즉시 한 번 적용한 뒤
/// 여러 번 더 확인한다. 재구성은 항상 메인 큐에서 직렬로 실행된다.
@MainActor
final class RebuildScheduler {
    /// 즉시 적용 이후의 재확인 시점.
    nonisolated static let defaultFollowUps: [TimeInterval] = [0.5, 1.5, 3.0]
    nonisolated static let defaultDebounce: TimeInterval = 0.15

    private let followUps: [TimeInterval]
    private let debounceInterval: TimeInterval
    private let perform: (String) -> Void

    private var debounceWorkItem: DispatchWorkItem?
    private var followUpWorkItems: [DispatchWorkItem] = []

    init(
        followUps: [TimeInterval] = RebuildScheduler.defaultFollowUps,
        debounce: TimeInterval = RebuildScheduler.defaultDebounce,
        perform: @escaping (String) -> Void
    ) {
        self.followUps = followUps
        self.debounceInterval = debounce
        self.perform = perform
    }

    /// 재구성을 요청한다. 짧은 시간에 몰린 요청은 하나로 합쳐진다.
    func request(reason: String) {
        cancelPending()

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.debounceWorkItem = nil
            self.perform(reason)
            self.scheduleFollowUps(reason: reason)
        }
        debounceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }

    /// debounce 없이 지금 바로 한 번 실행한다. 사용자가 `다시 적용`을 고른 경우처럼
    /// 반응이 즉시 보여야 할 때 쓴다. 지연 재확인은 동일하게 예약된다.
    func requestImmediately(reason: String) {
        cancelPending()
        perform(reason)
        scheduleFollowUps(reason: reason)
    }

    func cancelPending() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        followUpWorkItems.forEach { $0.cancel() }
        followUpWorkItems.removeAll()
    }

    private func scheduleFollowUps(reason: String) {
        for delay in followUps {
            let work = DispatchWorkItem { [weak self] in
                self?.perform("\(reason)+\(delay)s")
            }
            followUpWorkItems.append(work)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    }
}
