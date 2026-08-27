import Foundation

enum PlaylistListing {
    struct Entry: Equatable {
        let id: String
        let title: String
        let url: URL
    }

    static let listingLimit = 5
    static let maximumNewPerPoll = 3

    static func parse(_ output: String, sourceURL: URL) -> [Entry] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            parseLine(String(line), sourceURL: sourceURL)
        }
    }

    static func newEntries(
        from listing: [Entry],
        existingURLStrings: Set<String>,
        maximumAdditions: Int = maximumNewPerPoll
    ) -> [Entry] {
        var selected: [Entry] = []
        var seen = existingURLStrings
        for entry in listing {
            guard selected.count < maximumAdditions else { break }
            let canonical = URLIntake.canonicalString(for: entry.url)
            guard seen.insert(canonical).inserted else { continue }
            selected.append(entry)
        }
        return selected
    }

    private static func parseLine(_ line: String, sourceURL: URL) -> Entry? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("[") else { return nil }

        let parts: [String]
        if trimmed.contains("\t") {
            parts = trimmed.split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
        } else {
            parts = trimmed.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
        }
        guard parts.count >= 2 else { return nil }

        let id = parts[0].trimmingCharacters(in: .whitespaces)
        let title = parts[1].trimmingCharacters(in: .whitespaces)
        let webpage = parts.count > 2 ? parts[2].trimmingCharacters(in: .whitespaces) : ""
        guard !id.isEmpty, id.uppercased() != "NA", !id.contains(" ") else { return nil }

        return Entry(
            id: id,
            title: title == "NA" ? id : title,
            url: ChannelLink.videoURL(id: id, webpageURL: webpage, sourceURL: sourceURL)
        )
    }
}
