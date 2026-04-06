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
                            .frame(width: 6, height: 6)
                    }
                    Text(activeContext.displayName)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "scope")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
