import Foundation

@main
struct QAContextCheck {
    static func main() {
        checkSubtitleWindow()
        checkChapterLookup()
        checkRequestJSON()
        checkMissingKeyHint()
        print("qa_context_check=passed")
    }

    private static func checkSubtitleWindow() {
        let empty = VideoSubtitleTrack(cues: [])
        precondition(empty.cues(around: 12, window: 90).isEmpty, "空轨应返回空切片")
        precondition(empty.cues(around: .infinity, window: 90).isEmpty)
        precondition(empty.cues(around: 12, window: .nan).isEmpty)

        let cues = [
            VideoSubtitleCue(startTime: 0, endTime: 2, text: "head"),
            VideoSubtitleCue(startTime: 80, endTime: 100, text: "span-edge"),
            VideoSubtitleCue(startTime: 0, endTime: 200, text: "span-all"),
            VideoSubtitleCue(startTime: 400, endTime: 410, text: "tail"),
            VideoSubtitleCue(startTime: 500, endTime: 510, text: "far")
        ]
        let track = VideoSubtitleTrack(cues: cues)

        let aroundHead = track.cues(around: 5, window: 90)
        precondition(
            aroundHead.map(\.text) == ["head", "span-edge", "span-all"],
            "片头越界仍应收下与窗口相交的 cue"
        )

        let aroundTail = track.cues(around: 405, window: 90)
        precondition(aroundTail.map(\.text) == ["tail"], "片尾越界不得把远处 cue 拉进来")

        let aroundFar = track.cues(around: 1000, window: 90)
        precondition(aroundFar.isEmpty, "窗口完全落在轨外应为空")

        let crossing = track.cues(around: 90, window: 10)
        precondition(crossing.map(\.text) == ["span-edge", "span-all"], "跨窗 cue 必须保留")
        precondition(!crossing.map(\.text).contains("head"))
    }

    private static func checkChapterLookup() {
        let chapters = [
            VideoChapter(title: "开场", startTime: 0, endTime: 30),
            VideoChapter(title: "中段", startTime: 30, endTime: 90),
            VideoChapter(title: "尾声", startTime: 90, endTime: nil)
        ]
        precondition(WatchQAChapter.title(at: 0, in: chapters) == "开场")
        precondition(WatchQAChapter.title(at: 29.9, in: chapters) == "开场")
        precondition(WatchQAChapter.title(at: 30, in: chapters) == "中段")
        precondition(WatchQAChapter.title(at: 120, in: chapters) == "尾声")
        precondition(WatchQAChapter.title(at: 15, in: []) == nil)
        precondition(WatchQAChapter.title(at: .nan, in: chapters) == nil)
    }

    private static func checkRequestJSON() {
        let cues = [
            VideoSubtitleCue(startTime: 12, endTime: 18, text: "all right, so here we are\n好，我们到了"),
            VideoSubtitleCue(startTime: 18, endTime: 25, text: "in front of the elephants")
        ]
        let full = WatchQARequestInput(
            title: "Me at the zoo",
            author: "jawed",
            chapterTitle: "开场",
            currentTime: 15,
            cues: cues,
            jpegBase64: "framemock",
            question: "画面里是什么"
        )
        let fullRoot = requestJSON(from: full)
        precondition(fullRoot["model"] as? String == "claude-sonnet-5")
        precondition((fullRoot["max_tokens"] as? NSNumber)?.intValue == 1024)
        precondition((fullRoot["stream"] as? NSNumber)?.boolValue == true)
        let system = fullRoot["system"] as? String ?? ""
        precondition(system.contains("简洁"), "系统提示须要求简洁")
        precondition(system.contains("依据"), "系统提示须要求引用时说明依据")

        let text = userText(from: fullRoot)
        precondition(text.contains("标题：Me at the zoo"))
        precondition(text.contains("作者：jawed"))
        precondition(text.contains("章节：开场"))
        precondition(text.contains("时间：0:15"))
        precondition(text.contains("[0:12-0:18] all right, so here we are"))
        precondition(text.contains("好，我们到了"))
        precondition(text.contains("[0:18-0:25] in front of the elephants"))
        precondition(text.contains("问题：画面里是什么"))

        let image = imageBlock(from: fullRoot)
        precondition(image["type"] as? String == "image")
        let source = image["source"] as? [String: Any] ?? [:]
        precondition(source["type"] as? String == "base64")
        precondition(source["media_type"] as? String == "image/jpeg")
        precondition(source["data"] as? String == "framemock")

        let noSubtitles = WatchQARequestInput(
            title: "Me at the zoo",
            author: "jawed",
            chapterTitle: "开场",
            currentTime: 15,
            cues: [],
            jpegBase64: "framemock",
            question: "画面里是什么"
        )
        let noSubRoot = requestJSON(from: noSubtitles)
        let noSubText = userText(from: noSubRoot)
        precondition(noSubText.contains("标题：Me at the zoo"))
        precondition(noSubText.contains("章节：开场"))
        precondition(!noSubText.contains("字幕"), "无字幕时上下文只少字幕段")
        precondition(noSubText.contains("问题：画面里是什么"))
        let noSubImage = imageBlock(from: noSubRoot)
        precondition(noSubImage["type"] as? String == "image", "无字幕仍须带当前画面")
        precondition((noSubImage["source"] as? [String: Any])?["data"] as? String == "framemock")

        let noFrame = WatchQARequestInput(
            title: "Me at the zoo",
            author: "jawed",
            chapterTitle: "开场",
            currentTime: 15,
            cues: cues,
            jpegBase64: nil,
            question: "画面里是什么"
        )
        precondition(WatchQARequestBuilder.jsonObject(from: noFrame) == nil, "无画面不得组装请求")
        precondition(WatchQARequestBuilder.jsonData(from: noFrame) == nil, "无画面不得生成请求体")

        let noChapter = WatchQARequestInput(
            title: "Me at the zoo",
            author: "jawed",
            chapterTitle: nil,
            currentTime: 15,
            cues: cues,
            jpegBase64: "framemock",
            question: "他刚才说了什么"
        )
        let noChapterText = userText(from: requestJSON(from: noChapter))
        precondition(!noChapterText.contains("章节："), "无章节时不得输出空章节行")
        precondition(noChapterText.contains("字幕（当前前后 90 秒）："))
        precondition(noChapterText.contains("问题：他刚才说了什么"))
    }

    private static func checkMissingKeyHint() {
        precondition(
            WatchQAAPIKey.missingKeyHint
                == "未配置密钥，终端执行 defaults write com.mg.replay AnthropicAPIKey -string sk-…"
        )
        let suite = "qa.context.check.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        precondition(WatchQAAPIKey.resolve(defaults: defaults, environment: [:]) == nil)
        defaults.set("sk-from-defaults", forKey: WatchQAAPIKey.defaultsKey)
        precondition(
            WatchQAAPIKey.resolve(
                defaults: defaults,
                environment: [WatchQAAPIKey.environmentKey: "sk-from-env"]
            ) == "sk-from-defaults"
        )
        defaults.removeObject(forKey: WatchQAAPIKey.defaultsKey)
        precondition(
            WatchQAAPIKey.resolve(
                defaults: defaults,
                environment: [WatchQAAPIKey.environmentKey: "sk-from-env"]
            ) == "sk-from-env"
        )
        defaults.removePersistentDomain(forName: suite)
    }

    private static func requestJSON(from input: WatchQARequestInput) -> [String: Any] {
        guard let data = WatchQARequestBuilder.jsonData(from: input) else {
            preconditionFailure("合法输入应能组装请求")
        }
        return decode(data)
    }

    private static func decode(_ data: Data) -> [String: Any] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            preconditionFailure("request JSON did not decode")
        }
        return object
    }

    private static func contentBlocks(from root: [String: Any]) -> [[String: Any]] {
        let messages = root["messages"] as? [[String: Any]] ?? []
        return messages.first?["content"] as? [[String: Any]] ?? []
    }

    private static func userText(from root: [String: Any]) -> String {
        contentBlocks(from: root).first { $0["type"] as? String == "text" }?["text"] as? String ?? ""
    }

    private static func imageBlock(from root: [String: Any]) -> [String: Any] {
        contentBlocks(from: root).first { $0["type"] as? String == "image" } ?? [:]
    }
}
