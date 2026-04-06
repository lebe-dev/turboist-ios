import Foundation
import Network

enum ConnectionState: Equatable {
    case online
    case connecting
    case offline
}

@Observable
final class ConnectionStatusStore {
    private(set) var connectionState: ConnectionState = .online
    private(set) var pendingActionCount: Int = 0

    var isVisible: Bool {
        connectionState != .online
    }

    private var monitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "connection-monitor")
    private var graceTask: Task<Void, Never>?
    private var isNetworkAvailable = true

    static let offlineGracePeriod: TimeInterval = 5.0

    func start() {
        stop()
        let newMonitor = NWPathMonitor()
        newMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handlePathUpdate(path)
            }
        }
        newMonitor.start(queue: monitorQueue)
        monitor = newMonitor
    }

    func stop() {
        monitor?.cancel()
        monitor = nil
        graceTask?.cancel()
        graceTask = nil
    }

    @MainActor
    func setPendingActionCount(_ count: Int) {
        pendingActionCount = count
    }

    @MainActor
    func markConnecting() {
        graceTask?.cancel()
        graceTask = nil
        connectionState = .connecting
    }

    @MainActor
    func markOnline() {
        graceTask?.cancel()
        graceTask = nil
        isNetworkAvailable = true
        connectionState = .online
    }

    @MainActor
    func markOffline() {
        isNetworkAvailable = false
        scheduleOfflineTransition()
    }

    @MainActor
    private func handlePathUpdate(_ path: NWPath) {
        let wasAvailable = isNetworkAvailable
        isNetworkAvailable = path.status == .satisfied

        if isNetworkAvailable {
            graceTask?.cancel()
            graceTask = nil
            connectionState = .online
        } else if wasAvailable {
            scheduleOfflineTransition()
        }
    }

    @MainActor
    private func scheduleOfflineTransition() {
        guard connectionState != .offline else { return }

        graceTask?.cancel()
        connectionState = .connecting

        graceTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.offlineGracePeriod))
            guard !Task.isCancelled else { return }
            if !isNetworkAvailable {
                connectionState = .offline
            }
        }
    }
}
