import SwiftUI

struct RecurrencePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var customInput = ""
    let currentDue: Due?
    let onSelect: (String) -> Void

    private var presets: [(label: String, value: String)] {
        let calendar = Calendar.current
        let today = Date()
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"
        let dayName = dayFormatter.string(from: today)

        let dayOfMonth = calendar.component(.day, from: today)
        let ordinal = ordinalSuffix(dayOfMonth)

        let monthDayFormatter = DateFormatter()
        monthDayFormatter.dateFormat = "MMMM d"
        let monthDay = monthDayFormatter.string(from: today)

        return [
            ("Every day", "every day"),
            ("Every weekday", "every weekday"),
            ("Every week on \(dayName)", "every week on \(dayName)"),
            ("Every month on the \(ordinal)", "every month on the \(ordinal)"),
            ("Every year on \(monthDay)", "every year on \(monthDay)"),
        ]
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Presets") {
                    ForEach(presets, id: \.value) { preset in
                        Button {
                            onSelect(preset.value)
                            dismiss()
                        } label: {
                            HStack {
                                Label(preset.label, systemImage: "arrow.triangle.2.circlepath")
                                Spacer()
                                if currentDue?.recurring == true {
                                    // No way to compare due_string, but show recurring indicator
                                }
                            }
                        }
                    }
                }

                Section("Custom") {
                    TextField("e.g. every 2 weeks", text: $customInput)
                        .onSubmit {
                            guard !customInput.isEmpty else { return }
                            onSelect(customInput)
                            dismiss()
                        }
                    Button("Set Recurrence") {
                        guard !customInput.isEmpty else { return }
                        onSelect(customInput)
                        dismiss()
                    }
                    .disabled(customInput.isEmpty)
                }

                if currentDue?.recurring == true {
                    Section {
                        Button("Remove Recurrence", role: .destructive) {
                            // Setting due_date without due_string removes recurrence
                            if let date = currentDue?.date {
                                onSelect("__clear_recurrence__:\(date)")
                            }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Recurrence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func ordinalSuffix(_ day: Int) -> String {
        let suffixes = ["th", "st", "nd", "rd"]
        let relevantDigits = day % 100
        let suffix: String
        if relevantDigits >= 11 && relevantDigits <= 13 {
            suffix = "th"
        } else if relevantDigits % 10 < 4 {
            suffix = suffixes[relevantDigits % 10]
        } else {
            suffix = "th"
        }
        return "\(day)\(suffix)"
    }
}
