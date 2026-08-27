import Foundation

struct WatchBrief: Equatable, Codable {
    var summary: String
    var density: String
    var highlights: [WatchBriefHighlight]
}

struct WatchBriefHighlight: Equatable, Codable {
    var time: Double
    var label: String

    enum CodingKeys: String, CodingKey {
        case time
        case label
    }

    init(time: Double, label: String) {
        self.time = time
        self.label = label
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try? container.decode(Double.self, forKey: .time) {
            time = value
        } else if let value = try? container.decode(Int.self, forKey: .time) {
            time = Double(value)
        } else if let value = try? container.decode(String.self, forKey: .time),
                  let parsed = WatchBriefTimeFormat.parse(value) {
            time = parsed
        } else {
            time = 0
        }
        label = try container.decode(String.self, forKey: .label)
    }
}

enum WatchBriefStatus: Equatable {
    case idle
    case generating
    case failed(String)
}

enum WatchBriefError: LocalizedError, Equatable {
    case missingKey
    case missingSubtitle
    case emptyTranscript
    case invalidResponse
    case httpStatus(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return WatchBriefAPIKey.missingKeyHint
        case .missingSubtitle:
            return "还没有字幕，无法生成预审。"
        case .emptyTranscript:
            return "字幕是空的，无法生成预审。"
        case .invalidResponse:
            return "预审结果无法解析。"
        case .httpStatus(let code, let message):
            return message.isEmpty ? "预审请求失败（\(code)）" : message
        }
    }
}

enum WatchBriefAPIKey {
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

enum WatchBriefFile {
    static func url(for itemID: UUID, in folder: URL) -> URL {
        folder.appendingPathComponent("\(itemID.uuidString).brief.json")
    }

    static func load(from url: URL) -> WatchBrief? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WatchBrief.self, from: data)
    }

    static func save(_ brief: WatchBrief, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(brief)
        try data.write(to: url, options: .atomic)
    }
}

enum WatchBriefSubtitle {
    static func isChinese(_ url: URL?) -> Bool {
        guard let url else { return false }
        let path = url.path
        guard !path.isEmpty, path != "/" else { return false }
        let name = url.deletingPathExtension().lastPathComponent.lowercased()
        return name.contains(".zh")
    }

    static func firstChineseSubtitle(
        itemID: UUID,
        in folder: URL,
        fileManager: FileManager = .default
    ) -> URL? {
        let prefix = itemID.uuidString + "."
        let files = (try? fileManager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        return files
            .filter { $0.lastPathComponent.hasPrefix(prefix) && isChinese($0) }
            .sorted { lhs, rhs in
                let left = SubtitleTrackRank.value(for: lhs)
                let right = SubtitleTrackRank.value(for: rhs)
                if left != right { return left < right }
                return lhs.lastPathComponent.count < rhs.lastPathComponent.count
            }
            .first
    }
}

enum WatchBriefAutoAction: Equatable {
    case generate
    case skip
}

enum WatchBriefManualAction: Equatable {
    case generate
    case missingKey
    case missingSubtitle
}

enum WatchBriefPolicy {
    static func autoAction(
        isNewlyCompleted: Bool,
        chineseSubtitlePresent: Bool,
        briefAlreadyExists: Bool,
        hasAPIKey: Bool
    ) -> WatchBriefAutoAction {
        guard isNewlyCompleted, chineseSubtitlePresent, !briefAlreadyExists, hasAPIKey else {
            return .skip
        }
        return .generate
    }

    static func manualAction(
        subtitlePresent: Bool,
        hasAPIKey: Bool
    ) -> WatchBriefManualAction {
        if !hasAPIKey { return .missingKey }
        if !subtitlePresent { return .missingSubtitle }
        return .generate
    }
}

enum WatchBriefTimeFormat {
    static func string(from seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let remaining = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, remaining)
            : String(format: "%d:%02d", minutes, remaining)
    }

    static func parse(_ raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let value = Double(trimmed), value.isFinite {
            return value
        }
        let parts = trimmed.split(separator: ":")
        guard !parts.isEmpty, parts.count <= 3 else { return nil }
        var total = 0
        for part in parts {
            guard let value = Int(part), value >= 0 else { return nil }
            total = total * 60 + value
        }
        return Double(total)
    }
}

enum WatchBriefRequestBuilder {
    static let model = "claude-sonnet-5"
    static let maxTokens = 2048
    static let maxTranscriptCharacters = 30_000
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    static let anthropicVersion = "2023-06-01"

    static let systemPrompt = """
    你是视频预审助手。只输出一个 JSON 对象，不要 markdown，不要解释。
    字段必须是：
    - summary: 两三句说明这支视频讲什么
    - density: 以「高」「中」或「低」开头，随后用一句话说明为什么
    - highlights: 2 到 5 个重点，time 为秒（数字），label 为短中文说明
    """

    static func urlRequest(apiKey: String) -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        return request
    }

    static func transcript(
        from cues: [VideoSubtitleCue],
        limit: Int = maxTranscriptCharacters
    ) -> String {
        guard limit > 0 else { return "" }
        var lines: [String] = []
        var count = 0
        for cue in cues {
            var line = "[\(WatchBriefTimeFormat.string(from: cue.startTime))] \(cue.text)"
            let extra = (lines.isEmpty ? 0 : 1) + line.count
            if count + extra <= limit {
                lines.append(line)
                count += extra
                continue
            }
            if lines.isEmpty {
                line = String(line.prefix(limit))
                return line
            }
            break
        }
        return lines.joined(separator: "\n")
    }

    static func userText(title: String, author: String, cues: [VideoSubtitleCue]) -> String {
        var lines: [String] = []
        lines.append("标题：\(title)")
        if !author.isEmpty {
            lines.append("作者：\(author)")
        }
        let body = transcript(from: cues)
        if !body.isEmpty {
            lines.append("")
            lines.append("字幕：")
            lines.append(body)
        }
        return lines.joined(separator: "\n")
    }

    static func jsonObject(title: String, author: String, cues: [VideoSubtitleCue]) -> [String: Any] {
        [
            "model": model,
            "max_tokens": maxTokens,
            "stream": false,
            "system": systemPrompt,
            "messages": [
                [
                    "role": "user",
                    "content": userText(title: title, author: author, cues: cues)
                ]
            ]
        ]
    }

    static func jsonData(title: String, author: String, cues: [VideoSubtitleCue]) -> Data {
        let object = jsonObject(title: title, author: author, cues: cues)
        return (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
    }
}

enum WatchBriefParser {
    static func parse(_ text: String) throws -> WatchBrief {
        let slice = extractJSONObject(from: text)
        guard let data = slice.data(using: .utf8) else {
            throw WatchBriefError.invalidResponse
        }
        guard let brief = try? JSONDecoder().decode(WatchBrief.self, from: data) else {
            throw WatchBriefError.invalidResponse
        }
        let summary = brief.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let density = brief.density.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !summary.isEmpty, !density.isEmpty else {
            throw WatchBriefError.invalidResponse
        }
        return WatchBrief(
            summary: summary,
            density: density,
            highlights: brief.highlights.filter { !$0.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        )
    }

    static func extractJSONObject(from text: String) -> String {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("```") {
            if let firstNewline = trimmed.firstIndex(of: "\n") {
                trimmed = String(trimmed[trimmed.index(after: firstNewline)...])
            }
            if trimmed.hasSuffix("```") {
                trimmed = String(trimmed.dropLast(3))
            }
            trimmed = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let start = trimmed.firstIndex(of: "{"),
              let end = trimmed.lastIndex(of: "}"),
              start < end else {
            return trimmed
        }
        return String(trimmed[start...end])
    }
}

struct WatchBriefUsage: Equatable {
    var inputTokens: Int
    var outputTokens: Int
}

struct WatchBriefAPIResponse {
    var text: String
    var usage: WatchBriefUsage?

    static func parse(_ data: Data) throws -> WatchBriefAPIResponse {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw WatchBriefError.invalidResponse
        }
        if let error = object["error"] as? [String: Any] {
            let message = error["message"] as? String ?? ""
            throw WatchBriefError.httpStatus(0, message)
        }
        let content = object["content"] as? [[String: Any]] ?? []
        let text = content.compactMap { block -> String? in
            guard block["type"] as? String == "text" else { return nil }
            return block["text"] as? String
        }.joined()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WatchBriefError.invalidResponse
        }
        var usage: WatchBriefUsage?
        if let usageObject = object["usage"] as? [String: Any] {
            let input = (usageObject["input_tokens"] as? NSNumber)?.intValue ?? 0
            let output = (usageObject["output_tokens"] as? NSNumber)?.intValue ?? 0
            usage = WatchBriefUsage(inputTokens: input, outputTokens: output)
        }
        return WatchBriefAPIResponse(text: text, usage: usage)
    }
}

struct WatchBriefClientResult {
    var brief: WatchBrief
    var usage: WatchBriefUsage?
}

enum WatchBriefClient {
    static func generate(
        title: String,
        author: String,
        cues: [VideoSubtitleCue],
        apiKey: String,
        session: URLSession = .shared
    ) async throws -> WatchBriefClientResult {
        var request = WatchBriefRequestBuilder.urlRequest(apiKey: apiKey)
        request.httpBody = WatchBriefRequestBuilder.jsonData(title: title, author: author, cues: cues)
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw WatchBriefError.httpStatus(http.statusCode, httpErrorMessage(status: http.statusCode, body: data))
        }
        let parsed = try WatchBriefAPIResponse.parse(data)
        let brief = try WatchBriefParser.parse(parsed.text)
        return WatchBriefClientResult(brief: brief, usage: parsed.usage)
    }

    private static func httpErrorMessage(status: Int, body: Data) -> String {
        if let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
            if let error = object["error"] as? [String: Any],
               let message = error["message"] as? String,
               !message.isEmpty {
                return message
            }
            if let message = object["message"] as? String, !message.isEmpty {
                return message
            }
        }
        if let text = String(data: body, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            return String(text.prefix(240))
        }
        return "预审请求失败（\(status)）"
    }
}

