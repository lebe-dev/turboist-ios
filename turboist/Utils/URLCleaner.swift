import Foundation

enum URLCleaner {
    private static let trackingParams: Set<String> = [
        // Google / UTM
        "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
        "utm_id", "utm_source_platform", "utm_creative_format", "utm_marketing_tactic",
        // Google Ads / Click IDs
        "gclid", "gclsrc", "dclid", "gbraid", "wbraid",
        // Facebook / Meta
        "fbclid", "fb_action_ids", "fb_action_types", "fb_ref", "fb_source",
        // Microsoft
        "msclkid",
        // HubSpot
        "_hsenc", "_hsmi",
        // Mailchimp
        "mc_cid", "mc_eid",
        // Twitter / X
        "twclid",
        // Yahoo
        "yclid",
        // Instagram
        "igshid",
        // YouTube
        "si", "feature",
        // Generic
        "ref",
    ]

    static func cleanURL(_ raw: String) -> String {
        guard var components = URLComponents(string: raw) else { return raw }
        guard let queryItems = components.queryItems, !queryItems.isEmpty else { return raw }

        let filtered = queryItems.filter { !trackingParams.contains($0.name) }
        if filtered.count == queryItems.count { return raw }

        components.queryItems = filtered.isEmpty ? nil : filtered
        return components.string ?? raw
    }

    private static let urlPattern = try! NSRegularExpression(
        pattern: #"https?://[^\s)\]>]+"#,
        options: []
    )

    static func cleanTrackingParams(in text: String) -> String {
        let nsText = text as NSString
        let matches = urlPattern.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else { return text }

        var result = text
        // Process in reverse to preserve ranges
        for match in matches.reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            let url = String(result[range])
            let cleaned = cleanURL(url)
            if cleaned != url {
                result.replaceSubrange(range, with: cleaned)
            }
        }
        return result
    }
}
