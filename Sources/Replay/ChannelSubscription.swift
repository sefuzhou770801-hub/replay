import Foundation

struct ChannelSubscription: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var urlString: String
    var title: String
    var addedAt: Date
    var lastCheckedAt: Date?
}

enum ChannelSubscriptionFile {
    static func load(from file: URL) -> [ChannelSubscription] {
        guard let data = try? Data(contentsOf: file) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([ChannelSubscription].self, from: data)) ?? []
    }

    static func save(_ items: [ChannelSubscription], to file: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(items) else { return }
        try? FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: file, options: .atomic)
    }
}
