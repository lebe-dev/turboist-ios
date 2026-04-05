import SwiftUI

struct DatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date
    let currentDate: String?
    let onSelect: (String) -> Void
    let onClear: () -> Void

    init(currentDate: String?, onSelect: @escaping (String) -> Void, onClear: @escaping () -> Void) {
        self.currentDate = currentDate
        self.onSelect = onSelect
        self.onClear = onClear
        let initial = currentDate.flatMap { DueDateHelper.parse($0) } ?? Date()
        _selectedDate = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                QuickDateButtons { dateString in
                    onSelect(dateString)
                    dismiss()
                }
                .padding(.horizontal)

                DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Due Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSelect(DueDateHelper.format(selectedDate))
                        dismiss()
                    }
                }
                if currentDate != nil {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Clear Date", role: .destructive) {
                            onClear()
                            dismiss()
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
