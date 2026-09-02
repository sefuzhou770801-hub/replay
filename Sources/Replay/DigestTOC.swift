import Foundation

enum DigestTOCCopy {
    static let generateTitle = "生成目录"
    static let generatingLabel = "正在生成目录…"
    static let retryButtonTitle = "再试一次"
    static let missingKeyHint = DigestCopy.missingKeyHint

    static func collapsedTitle(chapterCount: Int, duration: Double) -> String {
        "目录 · \(chapterCount) 章 · \(DigestTimecode.format(duration))"
    }

    static func collapsedTitle(for toc: DigestOverviewPayload) -> String {
        collapsedTitle(chapterCount: toc.chapters.count, duration: toc.durationSeconds)
    }

    static func sourceNote(_ source: DigestTOCSource) -> String {
        switch source {
        case .videoChapters:
            return "章节来自视频，概括与金句由 AI 补"
        case .generated:
            return "章节与概括由 AI 生成"
        }
    }
}

enum DigestQuoteNormalize {
    static func apply(_ text: String) -> String {
        var mapped = ""
        mapped.reserveCapacity(text.count)
        for character in text {
            for scalar in character.unicodeScalars {
                if let half = halfwidth(scalar) {
                    mapped.append(Character(half))
                } else if scalar.value == 0x3000 {
                    continue
                } else {
                    mapped.append(Character(scalar))
                }
            }
        }
        let folded = mapped.lowercased()
        return folded.unicodeScalars
            .filter { !CharacterSet.whitespacesAndNewlines.contains($0) }
            .filter { !CharacterSet.punctuationCharacters.contains($0) }
            .filter { !CharacterSet.symbols.contains($0) }
            .map(String.init)
            .joined()
    }

    static func looselyMatches(quote: String, translation: String, cueText: String) -> Bool {
        let haystack = apply(cueText)
        guard !haystack.isEmpty else { return false }
        let original = apply(quote)
        if !original.isEmpty, haystack.contains(original) { return true }
        let translated = apply(translation)
        if !translated.isEmpty, haystack.contains(translated) { return true }
        return false
    }

    private static func halfwidth(_ scalar: Unicode.Scalar) -> Unicode.Scalar? {
        let value = scalar.value
        guard (0xFF01...0xFF5E).contains(value) else { return nil }
        return Unicode.Scalar(value - 0xFEE0)
    }
}

enum DigestTOCCompleteness {
    /// 结构完整：有章节且每章概括非空。金句缺省不算失败。
    static func hasAllSummaries(_ payload: DigestOverviewPayload) -> Bool {
        guard !payload.chapters.isEmpty else { return false }
        return payload.chapters.allSatisfy {
            !$0.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    static func fillingMissingSummaries(_ payload: DigestOverviewPayload) -> DigestOverviewPayload {
        var next = payload
        next.chapters = payload.chapters.map { chapter in
            var copy = chapter
            if copy.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                copy.summary = DigestCopy.missingSummaryPlaceholder
            }
            return copy
        }
        return next
    }
}

enum DigestTOCComposer {
    static func skeletonBlock(from chapters: [VideoChapter]) -> String {
        let sorted = chapters.sorted { $0.startTime < $1.startTime }
        guard !sorted.isEmpty else { return "" }
        let lines = sorted.enumerated().map { index, chapter in
            "\(index + 1). \(chapter.title) @ \(DigestTimecode.format(chapter.startTime))"
        }.joined(separator: "\n")
        return "视频自带章节（必须原样使用标题与时间，不得增删改名）：\n\(lines)"
    }

    static func compose(
        skeleton: [VideoChapter],
        ai: DigestOverviewPayload,
        duration: Double,
        cues: [VideoSubtitleCue]
    ) -> DigestOverviewPayload {
        let resolvedDuration = duration.isFinite ? max(0, duration) : 0
        if skeleton.isEmpty {
            return composeGenerated(ai: ai, duration: resolvedDuration, cues: cues)
        }
        return composeFromSkeleton(
            skeleton: skeleton,
            ai: ai,
            duration: resolvedDuration,
            cues: cues
        )
    }

    static func currentChapterIndex(at time: Double, in chapters: [DigestGeneratedChapter]) -> Int? {
        guard time.isFinite, !chapters.isEmpty else { return nil }
        let sorted = chapters.enumerated().sorted { $0.element.timestampSeconds < $1.element.timestampSeconds }
        var current: Int?
        for (offset, chapter) in sorted {
            if chapter.timestampSeconds <= time {
                current = offset
            }
        }
        return current
    }

    private static func composeFromSkeleton(
        skeleton: [VideoChapter],
        ai: DigestOverviewPayload,
        duration: Double,
        cues: [VideoSubtitleCue]
    ) -> DigestOverviewPayload {
        let chapters = skeleton.sorted { $0.startTime < $1.startTime }
        let ranges = chapterRanges(chapters, duration: duration)
        let aiChapters = ai.chapters.sorted { $0.timestampSeconds < $1.timestampSeconds }
        let countMatch = aiChapters.count == chapters.count
        var usedAI = Set<Int>()
        var usedQuoteTimes = Set<Double>()

        let composed: [DigestGeneratedChapter] = chapters.enumerated().map { index, chapter in
            let range = ranges[index]
            let matched: DigestGeneratedChapter?
            if countMatch {
                matched = aiChapters[index]
            } else {
                matched = firstUnused(aiChapters, used: &usedAI) { range.contains($0.timestampSeconds) }
            }
            let summary = matched?.summary.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let quote = pickQuote(
                matched: matched,
                extras: ai.keyQuotes,
                range: range,
                cues: cues,
                usedTimes: &usedQuoteTimes
            )
            return DigestGeneratedChapter(
                title: chapter.title,
                timestamp: DigestTimecode.format(chapter.startTime),
                timestampSeconds: chapter.startTime,
                summary: summary,
                quote: quote
            )
        }
        return DigestOverviewPayload(
            chapters: composed,
            keyQuotes: [],
            source: .videoChapters,
            durationSeconds: duration
        )
    }

    private static func composeGenerated(
        ai: DigestOverviewPayload,
        duration: Double,
        cues: [VideoSubtitleCue]
    ) -> DigestOverviewPayload {
        let chapters = ai.chapters.sorted { $0.timestampSeconds < $1.timestampSeconds }
        let bounds = chapters.map(\.timestampSeconds)
        var usedQuoteTimes = Set<Double>()
        let composed: [DigestGeneratedChapter] = chapters.enumerated().map { index, chapter in
            let start = chapter.timestampSeconds
            let end = index + 1 < bounds.count ? bounds[index + 1] : Double.infinity
            let range = start..<end
            let quote = pickQuote(
                matched: chapter,
                extras: ai.keyQuotes,
                range: range,
                cues: cues,
                usedTimes: &usedQuoteTimes
            )
            return DigestGeneratedChapter(
                title: chapter.title,
                timestamp: chapter.timestamp.isEmpty ? DigestTimecode.format(start) : chapter.timestamp,
                timestampSeconds: start,
                summary: chapter.summary,
                quote: quote
            )
        }
        return DigestOverviewPayload(
            chapters: composed,
            keyQuotes: [],
            source: .generated,
            durationSeconds: duration
        )
    }

    private static func chapterRanges(_ chapters: [VideoChapter], duration: Double) -> [Range<Double>] {
        chapters.enumerated().map { index, chapter in
            let start = chapter.startTime
            let end: Double
            if let explicit = chapter.endTime, explicit > start {
                end = explicit
            } else if index + 1 < chapters.count {
                end = chapters[index + 1].startTime
            } else {
                end = Double.infinity
            }
            if end > start {
                return start..<end
            }
            return start..<(start + 0.001)
        }
    }

    private static func firstUnused(
        _ chapters: [DigestGeneratedChapter],
        used: inout Set<Int>,
        matching: (DigestGeneratedChapter) -> Bool
    ) -> DigestGeneratedChapter? {
        for (index, chapter) in chapters.enumerated() where !used.contains(index) && matching(chapter) {
            used.insert(index)
            return chapter
        }
        return nil
    }

    private static func pickQuote(
        matched: DigestGeneratedChapter?,
        extras: [DigestKeyQuote],
        range: Range<Double>,
        cues: [VideoSubtitleCue],
        usedTimes: inout Set<Double>
    ) -> DigestKeyQuote? {
        if let nested = matched?.quote,
           !usedTimes.contains(nested.timestampSeconds),
           let snapped = snapQuoteToCue(nested, range: range, cues: cues) {
            usedTimes.insert(snapped.timestampSeconds)
            return snapped
        }
        let candidates = extras
            .filter { range.contains($0.timestampSeconds) && !usedTimes.contains($0.timestampSeconds) }
            .sorted { $0.timestampSeconds < $1.timestampSeconds }
        for candidate in candidates {
            if let snapped = snapQuoteToCue(candidate, range: range, cues: cues) {
                usedTimes.insert(snapped.timestampSeconds)
                return snapped
            }
        }
        return nil
    }

    static func quoteMatchesChapter(
        _ quote: DigestKeyQuote,
        range: Range<Double>,
        cues: [VideoSubtitleCue]
    ) -> Bool {
        snapQuoteToCue(quote, range: range, cues: cues) != nil
    }

    private static func snapQuoteToCue(
        _ quote: DigestKeyQuote,
        range: Range<Double>,
        cues: [VideoSubtitleCue]
    ) -> DigestKeyQuote? {
        let inRange = cues.filter { range.contains($0.startTime) }
        guard !inRange.isEmpty else { return nil }
        guard let cue = inRange.first(where: { cueMatches($0, quote: quote) }) else {
            return nil
        }
        return quoteFromCue(cue, fallbackTranslation: quote.translation)
    }

    private static func cueMatches(_ cue: VideoSubtitleCue, quote: DigestKeyQuote) -> Bool {
        DigestQuoteNormalize.looselyMatches(
            quote: quote.quote,
            translation: quote.translation,
            cueText: cue.text
        )
    }

    private static func quoteFromCue(
        _ cue: VideoSubtitleCue,
        fallbackTranslation: String
    ) -> DigestKeyQuote {
        let original = firstLine(cue.text)
        let translation: String
        let parts = cue.text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if parts.count >= 2 {
            translation = parts.dropFirst().joined(separator: " ")
        } else {
            translation = fallbackTranslation
        }
        return DigestKeyQuote(
            quote: original,
            translation: translation,
            timestamp: DigestTimecode.format(cue.startTime),
            timestampSeconds: cue.startTime
        )
    }

    private static func firstLine(_ text: String) -> String {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

}
