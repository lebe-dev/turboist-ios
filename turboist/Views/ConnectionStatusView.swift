import SwiftUI

struct ConnectionStatusView: View {
    let connectionState: ConnectionState
    let pendingActionCount: Int

    var body: some View {
        if connectionState != .online {
            HStack(spacing: 8) {
                switch connectionState {
                case .connecting:
                    ProgressView()
                        .controlSize(.small)
                        .tint(.orange)
                    Text("Подключение...")
                        .foregroundStyle(.orange)

                case .offline:
                    Image(systemName: "wifi.slash")
                        .foregroundStyle(.red)
                    if pendingActionCount > 0 {
                        Text("Оффлайн · \(pendingActionCount) в очереди")
                            .foregroundStyle(.red)
                    } else {
                        Text("Оффлайн")
                            .foregroundStyle(.red)
                    }

                case .online:
                    EmptyView()
                }
            }
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
        }
    }

    private var backgroundColor: Color {
        switch connectionState {
        case .connecting: return .orange.opacity(0.1)
        case .offline: return .red.opacity(0.1)
        case .online: return .clear
        }
    }
}

#Preview("Connecting") {
    ConnectionStatusView(connectionState: .connecting, pendingActionCount: 0)
}

#Preview("Offline") {
    ConnectionStatusView(connectionState: .offline, pendingActionCount: 3)
}

#Preview("Offline no pending") {
    ConnectionStatusView(connectionState: .offline, pendingActionCount: 0)
}
