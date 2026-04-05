import SwiftUI

@Observable
final class AppConfigStore {
    var config: AppConfig?

    var labels: [TaskLabel] {
        config?.labels ?? []
    }

    var labelConfigs: [LabelConfig] {
        config?.labelConfigs ?? []
    }

    func labelColor(_ name: String) -> Color? {
        guard let label = labels.first(where: { $0.name == name }) else { return nil }
        return Color(hex: label.color)
    }

    func shouldInheritToSubtasks(_ labelName: String) -> Bool {
        labelConfigs.first(where: { $0.name == labelName })?.inheritToSubtasks ?? false
    }

    func setConfig(_ config: AppConfig) {
        self.config = config
    }
}

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6 else { return nil }
        var rgbValue: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&rgbValue) else { return nil }
        self.init(
            red: Double((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: Double((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgbValue & 0x0000FF) / 255.0
        )
    }
}
