import Foundation

struct CompiledAutoLabel {
    let label: String
    let mask: String
    let ignoreCase: Bool
}

enum AutoLabelMatcher {
    static func compile(_ mappings: [AutoLabelMapping]) -> [CompiledAutoLabel] {
        mappings.map { mapping in
            CompiledAutoLabel(
                label: mapping.label,
                mask: mapping.ignoreCase ? mapping.mask.lowercased() : mapping.mask,
                ignoreCase: mapping.ignoreCase
            )
        }
    }

    static func match(title: String, compiled: [CompiledAutoLabel]) -> [String] {
        compiled
            .filter { entry in
                let haystack = entry.ignoreCase ? title.lowercased() : title
                return haystack.contains(entry.mask)
            }
            .map(\.label)
    }
}
