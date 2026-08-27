import Foundation

struct WatchQARequestInput: Equatable {
    var title: String
    var author: String
    var chapterTitle: String?
    var currentTime: Double
    var cues: [VideoSubtitleCue]
    var jpegBase64: String?
    var question: String
}

enum WatchQAChapter {
    static func title(at time: Double, in chapters: [VideoChapter]) -> String? {
        guard time.isFinite else { return nil }
        let sorted = chapters.sorted { $0.startTime < $1.startTime }
        return sorted.last { chapter in
            guard chapter.startTime <= time else { return false }
            if let endTime = chapter.endTime {
                return time < endTime
            }
            return true
        }?.title
    }
}

enum WatchQAAPIKey {
    static let defaultsKey = "AnthropicAPIKey"
    static let environmentKey = "ANTHROPIC_API_KEY"
    static let missingKeyHint = "未配置密钥，终端执行 defaults write com.mg.replay AnthropicAPIKey -string sk-…"

    static func resolve(
        defaults: UserDefaults = .standard,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String? {
        let fromDefaults = defaults.string(forKey: defaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !fromDefaults.isEmpty { return fromDefaults }
        let fromEnvironment = environment[environmentKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !fromEnvironment.isEmpty { return fromEnvironment }
        return nil
    }
}

enum WatchQARequestBuilder {
    static let model = "claude-sonnet-5"
    static let maxTokens = 1024
    static let subtitleWindow: Double = 90
    static let frameMaxWidth: Double = 1024
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    static let anthropicVersion = "2023-06-01"

    static let systemPrompt = """
    你是视频播放器里的问答助手。根据用户提供的当前画面和字幕上下文回答问题。
    要求：
    - 用中文简洁、直接地回答问题，不要寒暄，不要复述问题
    - 引用字幕或画面内容时说明依据，例如「字幕里说…」「画面中可以看到…」
    - 如果画面或字幕不足以回答，明确说看不清或字幕里没有提到
    """

    static func userText(from input: WatchQARequestInput) -> String {
        var lines: [String] = []
        lines.append("标题：\(input.title)")
        if !input.author.isEmpty {
            lines.append("作者：\(input.author)")
        }
        if let chapterTitle = input.chapterTitle, !chapterTitle.isEmpty {
            lines.append("章节：\(chapterTitle)")
        }
        lines.append("时间：\(formatTimecode(input.currentTime))")
        if !input.cues.isEmpty {
            lines.append("")
            lines.append("字幕（当前前后 90 秒）：")
            for cue in input.cues {
                let body = cue.text
                if let firstNewline = body.firstIndex(of: "\n") {
                    let firstLine = String(body[..<firstNewline])
                    let rest = String(body[body.index(after: firstNewline)...])
                    lines.append("[\(formatTimecode(cue.startTime))-\(formatTimecode(cue.endTime))] \(firstLine)")
                    if !rest.isEmpty {
                        lines.append(rest)
                    }
                } else {
                    lines.append("[\(formatTimecode(cue.startTime))-\(formatTimecode(cue.endTime))] \(body)")
                }
            }
        }
        lines.append("")
        lines.append("问题：\(input.question)")
        return lines.joined(separator: "\n")
    }

    static func jsonObject(from input: WatchQARequestInput) -> [String: Any]? {
        guard let jpegBase64 = input.jpegBase64, !jpegBase64.isEmpty else {
            return nil
        }
        let content: [[String: Any]] = [
            [
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": jpegBase64
                ]
            ],
            [
                "type": "text",
                "text": userText(from: input)
            ]
        ]
        return [
            "model": model,
            "max_tokens": maxTokens,
            "stream": true,
            "system": systemPrompt,
            "messages": [
                [
                    "role": "user",
                    "content": content
                ]
            ]
        ]
    }

    static func jsonData(from input: WatchQARequestInput) -> Data? {
        guard let object = jsonObject(from: input) else { return nil }
        return try? JSONSerialization.data(withJSONObject: object)
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
}

enum WatchQASSEParser {
    static func textDelta(fromLine line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("data:") else { return nil }
        let payload = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
        guard payload != "[DONE]",
              let data = payload.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let delta = object["delta"] as? [String: Any],
              let text = delta["text"] as? String
        else { return nil }
        return text
    }
}
