import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Design tokens

enum DS {
    enum Spacing {
        static let hairline: CGFloat = 0.5
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 28
        static let gutter: CGFloat = 20
    }

    enum Radius {
        static let chip: CGFloat = 8
        static let surface: CGFloat = 14
    }

    enum Palette {
        /// Todoist crimson — reserved for primary action and urgent states.
        static let accent = Color(red: 0.863, green: 0.298, blue: 0.243) // #DC4C3E
        static let hairline = Color(.separator).opacity(0.6)
        static let surface = Color(.systemBackground)
        static let surfaceMuted = Color(.secondarySystemBackground)
        static let textPrimary = Color(.label)
        static let textSecondary = Color(.secondaryLabel)
        static let textTertiary = Color(.tertiaryLabel)
    }

    enum Typography {
        /// Editorial hero — large, rounded, tight.
        static let hero = Font.system(size: 34, weight: .bold, design: .rounded)
        static let title = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 16, weight: .regular)
        static let bodyEmph = Font.system(size: 16, weight: .medium)
        static let caption = Font.system(size: 12, weight: .medium)
        static let micro = Font.system(size: 11, weight: .semibold)
    }
}

// MARK: - Hairline divider

struct Hairline: View {
    var inset: CGFloat = 0
    var body: some View {
        Rectangle()
            .fill(DS.Palette.hairline)
            .frame(height: DS.Spacing.hairline)
            .padding(.leading, inset)
    }
}

// MARK: - Chip

struct Chip: View {
    let icon: String?
    let text: String
    var tint: Color = DS.Palette.textSecondary
    var filled: Bool = false

    init(_ text: String, icon: String? = nil, tint: Color = DS.Palette.textSecondary, filled: Bool = false) {
        self.text = text
        self.icon = icon
        self.tint = tint
        self.filled = filled
    }

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
            }
            Text(text)
                .font(DS.Typography.caption)
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                .fill(filled ? tint.opacity(0.14) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                .strokeBorder(filled ? Color.clear : DS.Palette.hairline, lineWidth: DS.Spacing.hairline)
        )
    }
}

// MARK: - Section header (inline, no card)

struct InlineSectionHeader: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(DS.Typography.micro)
                .tracking(0.8)
                .foregroundStyle(DS.Palette.textTertiary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(DS.Typography.micro)
                    .foregroundStyle(DS.Palette.textTertiary)
            }
        }
    }
}
