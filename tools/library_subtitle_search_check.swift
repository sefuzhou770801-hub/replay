import Foundation

@main
enum LibrarySubtitleSearchCheck {
    static func main() {
        assertNormalizationAndMatch()
        assertEmptyQuery()
        assertGroupingAndContext()
        assertSentenceAggregation()
        assertFilenameAndPreferredTrack()
        assertTimecode()
        assertLoadTracksFromFolder()
        print("library_subtitle_search_check=passed")
    }

    private static func cue(_ start: Double, _ end: Double, _ text: String) -> VideoSubtitleCue {
        VideoSubtitleCue(startTime: start, endTime: end, text: text)
    }

    private static func assertNormalizationAndMatch() {
        let track = VideoSubtitleTrack(cues: [
            cue(1, 2, "Hello\u{2009}World\n你好 World")
        ])
        let hitsLower = LibrarySubtitleSearch.hits(
            in: track,
            itemID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            query: "hello world"
        )
        precondition(hitsLower.count == 1, "窄空格归一后应忽略大小写命中")

        let hitsChinese = LibrarySubtitleSearch.hits(
            in: track,
            itemID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            query: "你好\u{2009}world"
        )
        precondition(hitsChinese.count == 1, "查询里的窄空格也应归一")

        let misses = LibrarySubtitleSearch.hits(
            in: track,
            itemID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            query: "absent"
        )
        precondition(misses.isEmpty)
    }

    private static func assertEmptyQuery() {
        let track = VideoSubtitleTrack(cues: [cue(0, 1, "hello")])
        let id = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        precondition(LibrarySubtitleSearch.hits(in: track, itemID: id, query: "").isEmpty)
        precondition(LibrarySubtitleSearch.hits(in: track, itemID: id, query: "   ").isEmpty)
        let groups = LibrarySubtitleSearch.search(
            query: "  ",
            items: [LibrarySubtitleSearch.CatalogItem(id: id, title: "t", author: "a")],
            tracks: [id: track]
        )
        precondition(groups.isEmpty, "空白查询不得出结果")
    }

    private static func assertGroupingAndContext() {
        let firstID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let secondID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let thirdID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let first = VideoSubtitleTrack(cues: [
            cue(0, 1, "alpha\n甲。"),
            cue(1, 2, "needle here\n命中句。"),
            cue(2, 3, "omega\n丙。")
        ])
        let second = VideoSubtitleTrack(cues: [
            cue(10, 11, "other video\n另一个。")
        ])
        let third = VideoSubtitleTrack(cues: [
            cue(4, 5, "needle again\n再次命中。")
        ])
        let groups = LibrarySubtitleSearch.search(
            query: "needle",
            items: [
                LibrarySubtitleSearch.CatalogItem(id: firstID, title: "First", author: "Ann"),
                LibrarySubtitleSearch.CatalogItem(id: secondID, title: "Second", author: "Bob"),
                LibrarySubtitleSearch.CatalogItem(id: thirdID, title: "Third", author: "Cara")
            ],
            tracks: [firstID: first, secondID: second, thirdID: third]
        )
        precondition(groups.count == 2, "无命中的视频不得占一组，实际 \(groups.count)")
        precondition(groups[0].item.id == firstID)
        precondition(groups[1].item.id == thirdID)
        precondition(groups[0].hits.count == 1)
        let hit = groups[0].hits[0]
        precondition(hit.startTime == 1)
        precondition(hit.contextBefore == "甲。", "上文应取上一句译文，实际 \(hit.contextBefore ?? "nil")")
        precondition(hit.contextAfter == "丙。", "下文应取下一句译文，实际 \(hit.contextAfter ?? "nil")")
        precondition(hit.text.contains("命中句"))
        precondition(groups[0].hits[0].contextBefore != nil)
        precondition(groups[1].hits[0].contextBefore == nil)
        precondition(groups[1].hits[0].contextAfter == nil)
    }

    private static func assertSentenceAggregation() {
        let id = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let track = VideoSubtitleTrack(cues: [
            cue(0.0, 3.2, "In this video, I'm going to show you the\n在这个视频中，我将向你展示"),
            cue(1.4, 5.3, "exact system I use to manage every\n我用来管理我生活中每个"),
            cue(3.2, 7.4, "aspect of my life\n方面的确切系统。")
        ])
        let hits = LibrarySubtitleSearch.hits(in: track, itemID: id, query: "exact system")
        precondition(hits.count == 1, "跨片一句只能命中一次，实际 \(hits.count)")
        precondition(hits[0].startTime == 0.0, "跳转时刻取句首")
        precondition(LibrarySubtitleSearch.previewText(hits[0].text) == "在这个视频中，我将向你展示我用来管理我生活中每个方面的确切系统。")
    }

    private static func assertFilenameAndPreferredTrack() {
        let id = UUID(uuidString: "9D0A346E-068C-41CE-B3FC-938A773AADC9")!
        precondition(
            LibrarySubtitleSearch.itemID(fromSubtitleFileName: "9D0A346E-068C-41CE-B3FC-938A773AADC9.zh.srt") == id
        )
        precondition(
            LibrarySubtitleSearch.itemID(fromSubtitleFileName: "9D0A346E-068C-41CE-B3FC-938A773AADC9.en-orig.srt") == id
        )
        precondition(LibrarySubtitleSearch.itemID(fromSubtitleFileName: "notes.txt") == nil)

        let urls = [
            URL(fileURLWithPath: "/tmp/\(id.uuidString).en.srt"),
            URL(fileURLWithPath: "/tmp/\(id.uuidString).zh.srt"),
            URL(fileURLWithPath: "/tmp/\(id.uuidString).en-orig.srt")
        ]
        let preferred = LibrarySubtitleSearch.preferredSubtitleURL(from: urls)
        precondition(preferred?.lastPathComponent.hasSuffix(".zh.srt") == true)
    }

    private static func assertTimecode() {
        precondition(LibrarySubtitleSearch.formatTimecode(0) == "0:00")
        precondition(LibrarySubtitleSearch.formatTimecode(65) == "1:05")
        precondition(LibrarySubtitleSearch.formatTimecode(3661) == "1:01:01")
        precondition(LibrarySubtitleSearch.formatTimecode(.nan) == "0:00")
    }

    private static func assertLoadTracksFromFolder() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("replay-search-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let winner = UUID(uuidString: "9D0A346E-068C-41CE-B3FC-938A773AADC9")!
        let extra = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let bilingual = """
        1
        00:00:01,000 --> 00:00:02,000
        needle
        命中
        """
        let englishOnly = """
        1
        00:00:01,000 --> 00:00:02,000
        other
        """
        try! bilingual.write(
            to: directory.appendingPathComponent("\(winner.uuidString).zh.srt"),
            atomically: true,
            encoding: .utf8
        )
        try! englishOnly.write(
            to: directory.appendingPathComponent("\(winner.uuidString).en.srt"),
            atomically: true,
            encoding: .utf8
        )
        try! englishOnly.write(
            to: directory.appendingPathComponent("\(extra.uuidString).en.srt"),
            atomically: true,
            encoding: .utf8
        )
        try! "not a subtitle".write(
            to: directory.appendingPathComponent("readme.txt"),
            atomically: true,
            encoding: .utf8
        )

        let tracks = LibrarySubtitleSearch.loadTracks(in: directory)
        precondition(tracks[winner] != nil)
        precondition(tracks[winner]?.text(at: 1.5)?.contains("命中") == true, "同视频应选用双语 .zh")
        precondition(tracks[extra] != nil)
        precondition(tracks.count == 2)
    }
}
