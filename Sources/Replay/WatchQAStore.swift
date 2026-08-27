import Foundation

struct WatchQAEntry: Codable, Equatable, Identifiable {
    var id: UUID
    var time: Double
    var question: String
    var answer: String
    var askedAt: Date
    var model: String
}

enum WatchQAStore {
    static let sidecarSuffix = "qa.json"

    static func fileURL(itemID: UUID, in folder: URL) -> URL {
        folder.appendingPathComponent("\(itemID.uuidString).\(sidecarSuffix)")
    }

    static func load(from url: URL) -> [WatchQAEntry] {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([WatchQAEntry].self, from: data)) ?? []
    }

    static func save(_ entries: [WatchQAEntry], to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func append(_ entry: WatchQAEntry, to url: URL) {
        var entries = load(from: url)
        entries.append(entry)
        save(entries, to: url)
    }
}

enum WatchQATimeline {
    struct Insertions: Equatable {
        var leading: [WatchQAEntry]
        var after: [[WatchQAEntry]]
    }

    static func insertions(cues: [VideoSubtitleCue], entries: [WatchQAEntry]) -> Insertions {
        let sorted = entries
            .filter { $0.time.isFinite }
            .sorted { lhs, rhs in
                if lhs.time != rhs.time { return lhs.time < rhs.time }
                if lhs.askedAt != rhs.askedAt { return lhs.askedAt < rhs.askedAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        guard !cues.isEmpty else {
            return Insertions(leading: sorted, after: [])
        }

        var leading: [WatchQAEntry] = []
        var after = Array(repeating: [WatchQAEntry](), count: cues.count)
        var cueIndex = 0
        for entry in sorted {
            while cueIndex + 1 < cues.count, cues[cueIndex + 1].startTime <= entry.time {
                cueIndex += 1
            }
            if cues[cueIndex].startTime <= entry.time {
                after[cueIndex].append(entry)
            } else {
                leading.append(entry)
            }
        }
        return Insertions(leading: leading, after: after)
    }
}
