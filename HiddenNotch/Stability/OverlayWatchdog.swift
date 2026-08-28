import Foundation

/// 이벤트 알림을 놓쳤을 때를 대비한 마지막 안전장치.
///
/// 하는 일은 값 비교뿐이라 평상시 CPU 사용은 사실상 0에 가깝다. tolerance를 크게
/// 줘서 시스템이 다른 타이머와 함께 깨울 수 있게 하고, 불필요한 wakeup을 줄인다.
@MainActor
final class OverlayWatchdog {
    nonisolated static let defaultInterval: TimeInterval = 15

    private let interval: TimeInterval
    private let isConsistent: () -> Bool
    private let onDrift: () -> Void
    private var timer: Timer?

    init(
        interval: TimeInterval = OverlayWatchdog.defaultInterval,
        isConsistent: @escaping () -> Bool,
        onDrift: @escaping () -> Void
    ) {
        self.interval = interval
        self.isConsistent = isConsistent
        self.onDrift = onDrift
    }

    deinit {
        timer?.invalidate()
    }

    func start() {
        stop()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.isConsistent() else { return }
                self.onDrift()
            }
        }
        timer.tolerance = interval / 2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
