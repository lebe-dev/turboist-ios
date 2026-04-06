import SwiftUI

struct ContextPickerView: View {
    let contexts: [TaskContext]
    let activeContextId: String?
    let onSelect: (String?) -> Void

    var body: some View {
        Menu {
            Button {
                onSelect(nil)
            } label: {
                if activeContextId == nil || activeContextId?.isEmpty == true {
                    Label("All", systemImage: "checkmark")
                } else {
                    Text("All")
                }
            }

            if !contexts.isEmpty {
                Divider()
            }

            ForEach(contexts) { context in
                Button {
                    onSelect(context.id)
                } label: {
                    if activeContextId == context.id {
                        Label(context.displayName, systemImage: "checkmark")
                    } else {
                        Text(context.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                if let activeContext = contexts.first(where: { $0.id == activeContextId }) {
                    if let colorHex = activeContext.color, let color = Color(hex: colorHex) {
                        Circle()
                            .fill(color)
                            .frame(width: 8, height: 8)
                    }
                    Text(activeContext.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .fontWeight(.semibold)
            }
        }
    }
}
