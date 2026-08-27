import Foundation

@main
struct WatchBriefCheck {
    static func main() {
        checkFileNaming()
        checkRoundTrip()
        checkAPIKey()
        checkChineseSubtitle()
        checkAutoPolicy()
        checkManualPolicy()
        checkTimeFormat()
        checkTranscriptTruncation()
        checkRequestJSON()
        checkParser()
        checkAPIResponse()
        print("watch_brief_check=passed")
    }

    private static func checkFileNaming() {
        let id = UUID(uuidString: "9D0A346E-068C-41CE-B3FC-938A773AADC9")!
        let url = WatchBriefFile.url(for: id, in: URL(fileURLWithPath: "/tmp"))
        precondition(url.lastPathComponent == "9D0A346E-068C-41CE-B3FC-938A773AADC9.brief.json")
        precondition(url.deletingLastPathComponent().path == "/tmp")
    }

    private static func checkRoundTrip() {
        let brief = WatchBrief(
            summary: "作者在动物园自拍，介绍身后的大象。",
            density: "低：整段不到二十秒，几乎没有可摘的论点。",
            highlights: [
                WatchBriefHighlight(time: 5, label: "指向大象"),
                WatchBriefHighlight(time: 12.5, label: "收束")
            ]
        )
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("watch-brief-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let id = UUID()
        let url = WatchBriefFile.url(for: id, in: folder)
        try! WatchBriefFile.save(brief, to: url)
        let loaded = WatchBriefFile.load(from: url)
        precondition(loaded == brief)
        precondition(WatchBriefFile.load(from: folder.appendingPathComponent("missing.brief.json")) == nil)
    }

    private static func checkAPIKey() {
        precondition(
            WatchBriefAPIKey.missingKeyHint
                == "未配置密钥，终端执行 defaults write com.mg.replay AnthropicAPIKey -string sk-…"
        )
        let suite = "watch.brief.check.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        precondition(WatchBriefAPIKey.resolve(defaults: defaults, environment: [:]) == nil)
        defaults.set("   ", forKey: WatchBriefAPIKey.defaultsKey)
        precondition(WatchBriefAPIKey.resolve(defaults: defaults, environment: [:]) == nil)
        defaults.set("sk-from-defaults", forKey: WatchBriefAPIKey.defaultsKey)
        precondition(
            WatchBriefAPIKey.resolve(
                defaults: defaults,
                environment: [WatchBriefAPIKey.environmentKey: "sk-from-env"]
            ) == "sk-from-defaults"
        )
        defaults.removeObject(forKey: WatchBriefAPIKey.defaultsKey)
        precondition(
            WatchBriefAPIKey.resolve(
                defaults: defaults,
                environment: [WatchBriefAPIKey.environmentKey: "sk-from-env"]
            ) == "sk-from-env"
        )
        defaults.removePersistentDomain(forName: suite)
    }

    private static func checkChineseSubtitle() {
        let id = "9D0A346E-068C-41CE-B3FC-938A773AADC9"
        precondition(WatchBriefSubtitle.isChinese(URL(fileURLWithPath: "/tmp/\(id).zh.srt")))
        precondition(WatchBriefSubtitle.isChinese(URL(fileURLWithPath: "/tmp/\(id).zh-Hans.srt")))
        precondition(WatchBriefSubtitle.isChinese(URL(fileURLWithPath: "/tmp/\(id).zh-Hant.srt")))
        precondition(WatchBriefSubtitle.isChinese(URL(fileURLWithPath: "/tmp/\(id).zh-Hans-en.srt")))
        precondition(!WatchBriefSubtitle.isChinese(URL(fileURLWithPath: "/tmp/\(id).en.srt")))
        precondition(!WatchBriefSubtitle.isChinese(URL(fileURLWithPath: "/tmp/\(id).en-orig.srt")))
        precondition(!WatchBriefSubtitle.isChinese(URL(fileURLWithPath: "/tmp/\(id).srt")))
        precondition(!WatchBriefSubtitle.isChinese(nil))
        precondition(!WatchBriefSubtitle.isChinese(URL(fileURLWithPath: "")))

        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("watch-brief-subs-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let itemID = UUID()
        let english = folder.appendingPathComponent("\(itemID.uuidString).en.srt")
        let translated = folder.appendingPathComponent("\(itemID.uuidString).zh-Hans-en.srt")
        let preferred = folder.appendingPathComponent("\(itemID.uuidString).zh.srt")
        try! "en".write(to: english, atomically: true, encoding: .utf8)
        try! "zh-en".write(to: translated, atomically: true, encoding: .utf8)
        precondition(
            WatchBriefSubtitle.firstChineseSubtitle(itemID: itemID, in: folder)?.lastPathComponent
                == translated.lastPathComponent
        )
        try! "zh".write(to: preferred, atomically: true, encoding: .utf8)
        precondition(
            WatchBriefSubtitle.firstChineseSubtitle(itemID: itemID, in: folder)?.lastPathComponent
                == preferred.lastPathComponent
        )
        let otherID = UUID()
        precondition(WatchBriefSubtitle.firstChineseSubtitle(itemID: otherID, in: folder) == nil)
    }

    private static func checkAutoPolicy() {
        precondition(
            WatchBriefPolicy.autoAction(
                isNewlyCompleted: true,
                chineseSubtitlePresent: true,
                briefAlreadyExists: false,
                hasAPIKey: true
            ) == .generate
        )
        precondition(
            WatchBriefPolicy.autoAction(
                isNewlyCompleted: false,
                chineseSubtitlePresent: true,
                briefAlreadyExists: false,
                hasAPIKey: true
            ) == .skip,
            "启动扫历史库不得自动预审"
        )
        precondition(
            WatchBriefPolicy.autoAction(
                isNewlyCompleted: true,
                chineseSubtitlePresent: false,
                briefAlreadyExists: false,
                hasAPIKey: true
            ) == .skip
        )
        precondition(
            WatchBriefPolicy.autoAction(
                isNewlyCompleted: true,
                chineseSubtitlePresent: true,
                briefAlreadyExists: true,
                hasAPIKey: true
            ) == .skip
        )
        precondition(
            WatchBriefPolicy.autoAction(
                isNewlyCompleted: true,
                chineseSubtitlePresent: true,
                briefAlreadyExists: false,
                hasAPIKey: false
            ) == .skip,
            "无密钥自动路径必须静默"
        )
    }

    private static func checkManualPolicy() {
        precondition(
            WatchBriefPolicy.manualAction(subtitlePresent: true, hasAPIKey: true) == .generate
        )
        precondition(
            WatchBriefPolicy.manualAction(subtitlePresent: true, hasAPIKey: false) == .missingKey
        )
        precondition(
            WatchBriefPolicy.manualAction(subtitlePresent: false, hasAPIKey: true) == .missingSubtitle
        )
        precondition(
            WatchBriefPolicy.manualAction(subtitlePresent: false, hasAPIKey: false) == .missingKey
        )
    }

    private static func checkTimeFormat() {
        precondition(WatchBriefTimeFormat.string(from: 0) == "0:00")
        precondition(WatchBriefTimeFormat.string(from: 5) == "0:05")
        precondition(WatchBriefTimeFormat.string(from: 65) == "1:05")
        precondition(WatchBriefTimeFormat.string(from: 3723) == "1:02:03")
        precondition(WatchBriefTimeFormat.string(from: .nan) == "0:00")
        precondition(WatchBriefTimeFormat.parse("1:05") == 65)
        precondition(WatchBriefTimeFormat.parse("1:02:03") == 3723)
        precondition(WatchBriefTimeFormat.parse("12") == 12)
    }

    private static func checkTranscriptTruncation() {
        let cues = [
            VideoSubtitleCue(startTime: 1, endTime: 2, text: "hello\n你好"),
            VideoSubtitleCue(startTime: 3, endTime: 4, text: "elephants")
        ]
        let transcript = WatchBriefRequestBuilder.transcript(from: cues)
        precondition(transcript.contains("[0:01] hello"))
        precondition(transcript.contains("你好"))
        precondition(transcript.contains("[0:03] elephants"))

        let longBody = String(repeating: "字", count: 80)
        let many = (0..<400).map { index in
            VideoSubtitleCue(
                startTime: Double(index),
                endTime: Double(index) + 0.8,
                text: longBody
            )
        }
        let truncated = WatchBriefRequestBuilder.transcript(from: many, limit: 1_000)
        precondition(truncated.count <= 1_000)
        precondition(truncated.hasPrefix("[0:00]"))
        precondition(!truncated.contains("[6:39]"), "超长字幕应从尾部截断")

        let huge = VideoSubtitleCue(
            startTime: 0,
            endTime: 1,
            text: String(repeating: "长", count: 200)
        )
        let clipped = WatchBriefRequestBuilder.transcript(from: [huge], limit: 40)
        precondition(clipped.count <= 40)
        precondition(!clipped.isEmpty)
    }

    private static func checkRequestJSON() {
        let cues = [
            VideoSubtitleCue(startTime: 12, endTime: 18, text: "all right, so here we are\n好，我们到了")
        ]
        let root = decode(WatchBriefRequestBuilder.jsonData(
            title: "Me at the zoo",
            author: "jawed",
            cues: cues
        ))
        precondition(root["model"] as? String == "claude-sonnet-5")
        precondition((root["max_tokens"] as? NSNumber)?.intValue == 2048)
        precondition((root["stream"] as? NSNumber)?.boolValue == false)
        let system = root["system"] as? String ?? ""
        precondition(system.contains("JSON"))
        precondition(system.contains("summary"))
        let user = userText(from: root)
        precondition(user.contains("标题：Me at the zoo"))
        precondition(user.contains("作者：jawed"))
        precondition(user.contains("[0:12] all right, so here we are"))
        precondition(user.contains("好，我们到了"))
        let request = WatchBriefRequestBuilder.urlRequest(apiKey: "sk-test")
        precondition(request.url == WatchBriefRequestBuilder.endpoint)
        precondition(request.httpMethod == "POST")
        precondition(request.value(forHTTPHeaderField: "x-api-key") == "sk-test")
        precondition(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        precondition(request.value(forHTTPHeaderField: "content-type") == "application/json")
    }

    private static func checkParser() {
        let raw = """
        {"summary": "动物园自拍。", "density": "低：只有十几秒。", "highlights": [{"time": 5, "label": "大象"}, {"time": 12.5, "label": "收束"}]}
        """
        let parsed = try! WatchBriefParser.parse(raw)
        precondition(parsed.summary == "动物园自拍。")
        precondition(parsed.density == "低：只有十几秒。")
        precondition(parsed.highlights.count == 2)
        precondition(parsed.highlights[0].time == 5)
        precondition(parsed.highlights[0].label == "大象")
        precondition(parsed.highlights[1].time == 12.5)

        let fenced = """
        ```json
        {"summary": "围栏里的摘要", "density": "中：有一个观点。", "highlights": [{"time": "0:08", "label": "开场"}]}
        ```
        """
        let fromFence = try! WatchBriefParser.parse(fenced)
        precondition(fromFence.summary == "围栏里的摘要")
        precondition(fromFence.highlights[0].time == 8)
        precondition(fromFence.highlights[0].label == "开场")

        let mixed = "先说一句。\n{\"summary\":\"夹心\",\"density\":\"高：全是干货。\",\"highlights\":[]}\n完"
        let fromMixed = try! WatchBriefParser.parse(mixed)
        precondition(fromMixed.summary == "夹心")
        precondition(fromMixed.highlights.isEmpty)

        do {
            _ = try WatchBriefParser.parse("这不是 JSON")
            preconditionFailure("非 JSON 必须抛错")
        } catch WatchBriefError.invalidResponse {
            ()
        } catch {
            preconditionFailure("应抛 invalidResponse，实际 \(error)")
        }
    }

    private static func checkAPIResponse() {
        let json = """
        {
          "content": [{"type": "text", "text": "{\\"summary\\":\\"来自接口\\",\\"density\\":\\"低：短。\\",\\"highlights\\":[]}"}],
          "usage": {"input_tokens": 900, "output_tokens": 120}
        }
        """
        let parsed = try! WatchBriefAPIResponse.parse(Data(json.utf8))
        precondition(parsed.usage?.inputTokens == 900)
        precondition(parsed.usage?.outputTokens == 120)
        let brief = try! WatchBriefParser.parse(parsed.text)
        precondition(brief.summary == "来自接口")

        let errorJSON = """
        {"error":{"type":"invalid_request_error","message":"model not found"}}
        """
        do {
            _ = try WatchBriefAPIResponse.parse(Data(errorJSON.utf8))
            preconditionFailure("错误体必须抛错")
        } catch WatchBriefError.httpStatus(_, let message) {
            precondition(message == "model not found")
        } catch {
            preconditionFailure("应抛 httpStatus，实际 \(error)")
        }
    }

    private static func decode(_ data: Data) -> [String: Any] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            preconditionFailure("request JSON did not decode")
        }
        return object
    }

    private static func userText(from root: [String: Any]) -> String {
        let messages = root["messages"] as? [[String: Any]] ?? []
        return messages.first?["content"] as? String ?? ""
    }
}
