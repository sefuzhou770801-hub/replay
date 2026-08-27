import Foundation

/// 跨视频字幕检索：扫媒体目录里的 `<uuid>.*.srt`，按句块匹配关键词。
enum LibrarySubtitleSearch {
    struct CatalogItem: Equatable {
        let id: UUID
        let title: String
        let author: String
    }

    struct Hit: Equatable, Identifiable {
        let itemID: UUID
        let startTime: Double
        let endTime: Double
        let text: String
        let contextBefore: String?
        let contextAfter: String?

        var id: String {
            "\(itemID.uuidString)-\(startTime)-\(endTime)-\(text)"
        }
    }

    struct Group: Equatable, Identifiable {
        let item: CatalogItem
        let hits: [Hit]
        var id: UUID { item.id }
    }

    static func normalizeForMatch(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{2009}", with: " ").lowercased()
    }

    static func formatTimecode(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let remaining = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, remaining)
            : String(format: "%d:%02d", minutes, remaining)
    }

    static func itemID(fromSubtitleFileName name: String) -> UUID? {
        UUID(uuidString: String(name.prefix(36)))
    }

    static func preferredSubtitleURL(from urls: [URL]) -> URL? {
        urls
            .filter { $0.pathExtension.lowercased() == "srt" }
            .sorted { lhs, rhs in
                let leftRank = SubtitleTrackRank.value(for: lhs)
                let rightRank = SubtitleTrackRank.value(for: rhs)
                if leftRank != rightRank { return leftRank < rightRank }
                return lhs.lastPathComponent.count < rhs.lastPathComponent.count
            }
            .first
    }

    /// 命中预览取译文行；没有译文时用原文。
    static func previewText(_ text: String) -> String {
        let lines = VideoSubtitlePresentation.displayLines(from: text)
        if lines.count >= 2 { return lines[1] }
        return lines.first ?? text
    }

    static func hits(in track: VideoSubtitleTrack, itemID: UUID, query: String) -> [Hit] {
        hits(in: SubtitleSentenceBlocks.aggregate(track.cues), itemID: itemID, query: query)
    }

    static func hits(in sentences: [VideoSubtitleCue], itemID: UUID, query: String) -> [Hit] {
        let needle = normalizeForMatch(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !needle.isEmpty else { return [] }
        var result: [Hit] = []
        for (index, sentence) in sentences.enumerated() {
            guard normalizeForMatch(sentence.text).contains(needle) else { continue }
            result.append(
                Hit(
                    itemID: itemID,
                    startTime: sentence.startTime,
                    endTime: sentence.endTime,
                    text: sentence.text,
                    contextBefore: index > 0 ? previewText(sentences[index - 1].text) : nil,
                    contextAfter: index + 1 < sentences.count ? previewText(sentences[index + 1].text) : nil
                )
            )
        }
        return result
    }

    static func search(
        query: String,
        items: [CatalogItem],
        tracks: [UUID: VideoSubtitleTrack]
    ) -> [Group] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }
        return items.compactMap { item in
            guard let track = tracks[item.id] else { return nil }
            let found = hits(in: track, itemID: item.id, query: needle)
            guard !found.isEmpty else { return nil }
            return Group(item: item, hits: found)
        }
    }

    static func loadTracks(
        in folder: URL,
        fileManager: FileManager = .default
    ) -> [UUID: VideoSubtitleTrack] {
        let files = (try? fileManager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        var grouped: [UUID: [URL]] = [:]
        for file in files where file.pathExtension.lowercased() == "srt" {
            guard let id = itemID(fromSubtitleFileName: file.lastPathComponent) else { continue }
            grouped[id, default: []].append(file)
        }
        var tracks: [UUID: VideoSubtitleTrack] = [:]
        for (id, urls) in grouped {
            guard let preferred = preferredSubtitleURL(from: urls),
                  let track = VideoSubtitleTrack(contentsOf: preferred) else { continue }
            tracks[id] = track
        }
        return tracks
    }
}
