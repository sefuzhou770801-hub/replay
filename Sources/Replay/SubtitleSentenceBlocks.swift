import Foundation

/// 右栏字幕列表的句级聚合：ASR 逐片切分的 cue 按句末标点合并成句块。
/// 只作用于显示层，字幕文件与播放浮层不受影响；时间码取句首，跨度与片数设上限防失控。
enum SubtitleSentenceBlocks {
    static let maxFragments = 6
    static let preferredFragments = 4
    static let maxSpan: Double = 12

    static func aggregate(_ cues: [VideoSubtitleCue]) -> [VideoSubtitleCue] {
        var blocks: [VideoSubtitleCue] = []
        var sourceParts: [String] = []
        var translationParts: [String] = []
        var fragmentCount = 0
        var blockStart: Double = 0
        var blockEnd: Double = 0

        func flush() {
            guard fragmentCount > 0 else { return }
            let source = sourceParts.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            let translation = translationParts.joined().trimmingCharacters(in: .whitespaces)
            let text = [source, translation].filter { !$0.isEmpty }.joined(separator: "\n")
            if !text.isEmpty {
                blocks.append(VideoSubtitleCue(startTime: blockStart, endTime: blockEnd, text: text))
            }
            sourceParts = []
            translationParts = []
            fragmentCount = 0
        }

        for cue in cues {
            let lines = cue.text
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard !lines.isEmpty else { continue }
            let source = lines.first ?? ""
            let translation = lines.dropFirst().joined(separator: " ")

            if fragmentCount == 0 {
                blockStart = cue.startTime
                blockEnd = cue.endTime
            }
            blockEnd = max(blockEnd, cue.endTime)
            if !source.isEmpty { sourceParts.append(source) }
            if !translation.isEmpty { translationParts.append(translation) }
            fragmentCount += 1

            let probe = translation.isEmpty ? source : translation
            let sentenceClosed = endsSentence(probe)
            // 块偏长后优先在分句标点落刀，避免硬上限把短语拦腰切断。
            let clauseClosed = fragmentCount >= preferredFragments && endsClause(probe)
            let overCap = fragmentCount >= maxFragments || cue.endTime - blockStart >= maxSpan
            if sentenceClosed || clauseClosed || overCap {
                flush()
            }
        }
        flush()
        return blocks
    }

    static func endsSentence(_ text: String) -> Bool {
        guard let last = text.trimmingCharacters(in: .whitespaces).last else { return false }
        return "。！？!?.…”』」".contains(last)
    }

    static func endsClause(_ text: String) -> Bool {
        guard let last = text.trimmingCharacters(in: .whitespaces).last else { return false }
        return "，、；：,;:".contains(last)
    }

    /// 中西文排版规则：中文与拉丁字母或数字相接处垫窄空格（U+2009），只作用于显示层。
    /// 覆盖「在Twitter上」「E结尾的」「Lauren Tan我想」全部边界；已有空格处不重复垫。
    static func withCJKLatinSpacing(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        var result = ""
        var previous: Character?
        for character in text {
            if let previous, needsGap(previous, character) {
                result.append("\u{2009}")
            }
            result.append(character)
            previous = character
        }
        return result
    }

    private static func isCJK(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        let value = Int(scalar.value)
        return (0x4E00...0x9FFF).contains(value) || (0x3400...0x4DBF).contains(value)
    }

    private static func isLatinAlnum(_ character: Character) -> Bool {
        character.isASCII && (character.isLetter || character.isNumber)
    }

    private static func needsGap(_ a: Character, _ b: Character) -> Bool {
        isCJK(a) && isLatinAlnum(b) || isLatinAlnum(a) && isCJK(b)
    }
}
