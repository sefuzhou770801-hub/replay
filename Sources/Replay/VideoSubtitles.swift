import Foundation

struct VideoSubtitleCue: Equatable, Sendable {
    let startTime: Double
    let endTime: Double
    let text: String
}

struct VideoSubtitleTrack: Equatable, Sendable {
    let cues: [VideoSubtitleCue]

    init(cues: [VideoSubtitleCue]) {
        self.cues = cues
    }

    init?(contentsOf url: URL) {
        guard let source = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let parsed = Self.parse(source)
        guard !parsed.isEmpty else { return nil }
        cues = parsed
    }

    func text(at time: Double) -> String? {
        guard time.isFinite else { return nil }
        var seen: Set<String> = []
        let active = cues.compactMap { cue -> String? in
            guard cue.startTime <= time, time < cue.endTime, seen.insert(cue.text).inserted else { return nil }
            return cue.text
        }
        return active.isEmpty ? nil : active.joined(separator: "\n")
    }

    /// 短于该时长且紧邻后续更长 cue 的条目视为 YouTube 滚动字幕闪现帧，从列表中折叠。
    private static let rollingFlashDurationThreshold: Double = 0.05
    /// 闪现 cue 结束与下一条开始之间允许的空隙（含时间戳四舍五入误差）。
    private static let rollingFlashGapTolerance: Double = 0.05

    static func parse(_ source: String) -> [VideoSubtitleCue] {
        let normalized = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\n[ \\t]*\n", with: "\n\n", options: .regularExpression)

        let raw = normalized.components(separatedBy: "\n\n").compactMap { block -> VideoSubtitleCue? in
            let lines = block.components(separatedBy: "\n")
            guard let timingIndex = lines.firstIndex(where: { $0.contains("-->") }) else { return nil }
            let timing = lines[timingIndex].components(separatedBy: "-->")
            guard timing.count == 2,
                  let start = parseTimestamp(timing[0]),
                  let end = parseTimestamp(timing[1]),
                  end > start else { return nil }

            let caption = cleanCaption(lines.dropFirst(timingIndex + 1).joined(separator: "\n"))
            guard !caption.isEmpty else { return nil }
            return VideoSubtitleCue(startTime: start, endTime: end, text: caption)
        }
        .sorted { lhs, rhs in
            lhs.startTime == rhs.startTime ? lhs.endTime < rhs.endTime : lhs.startTime < rhs.startTime
        }
        return collapseRollingFlashCues(raw)
    }

    /// 去掉 YouTube 自动字幕的「10ms 闪现 + 扩展句」成对重复，保留双语两行完整 cue。
    /// 除时长/邻接外必须核对文本连续性：闪现须与下一条相同、为其前缀，或为其子集（滚动窗）；
    /// 内容无关的短 cue（如音效标注）一律保留。
    static func collapseRollingFlashCues(_ cues: [VideoSubtitleCue]) -> [VideoSubtitleCue] {
        guard cues.count > 1 else { return cues }
        var kept: [VideoSubtitleCue] = []
        kept.reserveCapacity(cues.count)
        var index = 0
        while index < cues.count {
            let cue = cues[index]
            let duration = cue.endTime - cue.startTime
            if duration < rollingFlashDurationThreshold, index + 1 < cues.count {
                let next = cues[index + 1]
                let gap = next.startTime - cue.endTime
                let nextDuration = next.endTime - next.startTime
                // 时长邻接 + 文本连续（相同 / 前缀 / 子集）才折叠。
                if gap >= -0.001,
                   gap < rollingFlashGapTolerance,
                   nextDuration > duration,
                   isRollingFlashContinuation(cue.text, of: next.text) {
                    index += 1
                    continue
                }
            }
            kept.append(cue)
            index += 1
        }
        return kept
    }

    /// 判断极短 cue 是否为下一条的滚动闪现（文本相同、前缀或子集），而非独立内容。
    static func isRollingFlashContinuation(_ flash: String, of next: String) -> Bool {
        if flash == next { return true }
        if next.hasPrefix(flash) { return true }

        let flashLines = flash
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let nextLines = next
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard let flashFirst = flashLines.first, let nextFirst = nextLines.first else { return false }

        // 原文首行扩展：YouTube 滚动主轨几乎总是首行前缀关系。
        if nextFirst.hasPrefix(flashFirst) { return true }

        // 逐行前缀：闪现各行是下一条对应行的前缀（双语两行同时扩展）。
        if flashLines.count <= nextLines.count,
           zip(flashLines, nextLines).allSatisfy({ flashLine, nextLine in
               nextLine.hasPrefix(flashLine)
           }) {
            return true
        }

        // 去换行后的前缀 / 连续子串子集（行切分不一致时）。
        let flashJoined = flashLines.joined(separator: " ")
        let nextJoined = nextLines.joined(separator: " ")
        if nextJoined.hasPrefix(flashJoined) { return true }
        if !flashJoined.isEmpty, nextJoined.contains(flashJoined) { return true }

        return false
    }

    private static func parseTimestamp(_ rawValue: String) -> Double? {
        let token = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .first?
            .replacingOccurrences(of: ",", with: ".") ?? ""
        let fields = token.split(separator: ":").compactMap { Double($0) }
        switch fields.count {
        case 3:
            return fields[0] * 3_600 + fields[1] * 60 + fields[2]
        case 2:
            return fields[0] * 60 + fields[1]
        default:
            return nil
        }
    }

    private static func cleanCaption(_ rawValue: String) -> String {
        var value = rawValue
            .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\{\\[^}]+\}"#, with: "", options: .regularExpression)
        let entities = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&#39;": "'",
            "&#x27;": "'",
            "&nbsp;": " ",
            "&lrm;": "",
            "&rlm;": ""
        ]
        for (entity, replacement) in entities {
            value = value.replacingOccurrences(of: entity, with: replacement)
        }
        return value.components(separatedBy: "\n")
            .map {
                $0.replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}
