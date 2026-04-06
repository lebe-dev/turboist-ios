import SwiftUI

struct AutoRemovePausedBanner: View {
    let isVisible: Bool
    @State private var dismissed = false

    var body: some View {
        if isVisible && !dismissed {
            HStack(spacing: 8) {
                Image(systemName: "flame")
                    .foregroundStyle(.red)
                Text("Auto-remove paused: too many tasks matched for deletion. Check config.")
                    .font(.caption)
                Spacer()
                Button {
                    withAnimation {
                        dismissed = true
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.red.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.red.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)
            .padding(.vertical, 4)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
