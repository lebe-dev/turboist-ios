import SwiftUI

enum Priority: Int, CaseIterable, Identifiable {
    case p4 = 1  // Low
    case p3 = 2  // Medium
    case p2 = 3  // High
    case p1 = 4  // Urgent

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .p1: return "P1 - Urgent"
        case .p2: return "P2 - High"
        case .p3: return "P3 - Medium"
        case .p4: return "P4 - Low"
        }
    }

    var shortLabel: String {
        switch self {
        case .p1: return "P1"
        case .p2: return "P2"
        case .p3: return "P3"
        case .p4: return "P4"
        }
    }

    var color: Color {
        switch self {
        case .p1: return .red
        case .p2: return .orange
        case .p3: return .blue
        case .p4: return .gray
        }
    }

    init(rawPriority: Int) {
        self = Priority(rawValue: rawPriority) ?? .p4
    }
}
