import Foundation

actor MonitorScheduler {
    private var task: Task<Void, Never>?

    func start(intervalSeconds: Int, fire: @escaping @Sendable () async -> Void) {
        stop()
        task = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(intervalSeconds))
                if Task.isCancelled { return }
                await fire()
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
