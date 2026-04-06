import SwiftUI

struct SettingsView: View {
    @AppStorage("appColorScheme") private var colorSchemePreference: String = "system"
    @AppStorage("appLanguage") private var language: String = "ru"
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    themeRow("system.fill",  "Системная",  tag: "system")
                    themeRow("sun.max.fill", "Светлая",    tag: "light")
                    themeRow("moon.fill",    "Тёмная",     tag: "dark")
                } header: {
                    InlineSectionHeader(title: "Тема оформления")
                }

                Section {
                    languageRow("ru", label: "Русский", flag: "🇷🇺")
                    languageRow("en", label: "English",  flag: "🇺🇸")
                } header: {
                    InlineSectionHeader(title: "Язык")
                } footer: {
                    Text("Изменение языка вступит в силу после перезапуска приложения.")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Palette.textTertiary)
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func themeRow(_ icon: String, _ title: String, tag: String) -> some View {
        Button {
            colorSchemePreference = tag
        } label: {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24)
                    .foregroundStyle(DS.Palette.accent)
                Text(title)
                    .foregroundStyle(DS.Palette.textPrimary)
                Spacer()
                if colorSchemePreference == tag {
                    Image(systemName: "checkmark")
                        .foregroundStyle(DS.Palette.accent)
                        .fontWeight(.semibold)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func languageRow(_ tag: String, label: String, flag: String) -> some View {
        Button {
            language = tag
        } label: {
            HStack {
                Text(flag)
                    .frame(width: 24)
                Text(label)
                    .foregroundStyle(DS.Palette.textPrimary)
                Spacer()
                if language == tag {
                    Image(systemName: "checkmark")
                        .foregroundStyle(DS.Palette.accent)
                        .fontWeight(.semibold)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView()
}
