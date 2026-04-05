import SwiftUI

struct LabelPickerView: View {
    let availableLabels: [TaskLabel]
    @Binding var selectedLabels: [String]
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private var filteredLabels: [TaskLabel] {
        guard !searchText.isEmpty else { return availableLabels }
        let query = searchText.lowercased()
        return availableLabels.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredLabels) { label in
                    Button {
                        toggleLabel(label.name)
                    } label: {
                        HStack {
                            Image(systemName: selectedLabels.contains(label.name) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedLabels.contains(label.name) ? .blue : .secondary)
                            if let color = Color(hex: label.color) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 10, height: 10)
                            }
                            Text(label.name)
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search labels")
            .navigationTitle("Labels")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func toggleLabel(_ name: String) {
        if let index = selectedLabels.firstIndex(of: name) {
            selectedLabels.remove(at: index)
        } else {
            selectedLabels.append(name)
        }
    }
}
