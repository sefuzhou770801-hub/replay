import Foundation

@main
struct QAStoreCheck {
    static func main() throws {
        checkFileNaming()
        try checkRoundTrip()
        try checkAppendOrder()
        checkMissingEmptyAndCorrupt()
        checkTimelineInsert()
        print("qa_store_check=passed")
    }

    private static func checkFileNaming() {
        let id = UUID(uuidString: "9D0A346E-068C-41CE-B3FC-938A773AADC9")!
        let folder = URL(fileURLWithPath: "/tmp/replay-media", isDirectory: true)
        let url = WatchQAStore.fileURL(itemID: id, in: folder)
        precondition(
            url.lastPathComponent == "9D0A346E-068C-41CE-B3FC-938A773AADC9.qa.json",
            "sidecar 须为 {UUID}.qa.json，与 {UUID}.zh.srt 同一前缀规则"
        )
        precondition(
            url.lastPathComponent.hasPrefix(id.uuidString + "."),
            "文件名须带 UUID. 前缀，删除本地文件时才能被现有前缀扫描清掉"
        )
    }

    private static func checkRoundTrip() throws {
        let url = scratchURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let entry = WatchQAEntry(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            time: 75.5,
            question: "画面里是什么",
            answer: "大象站在栅栏后面。\n字幕里说 we are in front of the elephants。",
            askedAt: Date(timeIntervalSince1970: 1_700_000_000),
            model: "claude-sonnet-5"
        )
        WatchQAStore.save([entry], to: url)

        let loaded = WatchQAStore.load(from: url)
        precondition(loaded.count == 1)
        precondition(loaded[0].id == entry.id)
        precondition(loaded[0].time == 75.5)
        precondition(loaded[0].question == "画面里是什么")
        precondition(loaded[0].answer == entry.answer)
        precondition(loaded[0].askedAt.timeIntervalSince1970 == 1_700_000_000)
        precondition(loaded[0].model == "claude-sonnet-5")

        let data = try Data(contentsOf: url)
        let objects = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        precondition(objects?.count == 1, "sidecar 须是对象数组")
        let object = objects?[0] ?? [:]
        precondition(object["id"] as? String == entry.id.uuidString)
        precondition((object["time"] as? NSNumber)?.doubleValue == 75.5)
        precondition(object["question"] as? String == "画面里是什么")
        precondition(object["answer"] as? String == entry.answer)
        precondition(object["model"] as? String == "claude-sonnet-5")
        precondition(object["askedAt"] as? String == "2023-11-14T22:13:20Z")
    }

    private static func checkAppendOrder() throws {
        let url = scratchURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let first = WatchQAEntry(
            id: UUID(),
            time: 40,
            question: "先问",
            answer: "先答",
            askedAt: Date(timeIntervalSince1970: 100),
            model: "claude-sonnet-5"
        )
        let second = WatchQAEntry(
            id: UUID(),
            time: 10,
            question: "后问",
            answer: "后答",
            askedAt: Date(timeIntervalSince1970: 200),
            model: "claude-sonnet-5"
        )
        WatchQAStore.append(first, to: url)
        WatchQAStore.append(second, to: url)
        let loaded = WatchQAStore.load(from: url)
        precondition(loaded.map(\.question) == ["先问", "后问"], "磁盘按追加顺序，不按时间重排")
        precondition(loaded.map(\.id) == [first.id, second.id])
    }

    private static func checkMissingEmptyAndCorrupt() {
        let missing = scratchURL()
        precondition(
            WatchQAStore.load(from: missing).isEmpty,
            "文件不存在视为空"
        )

        let empty = scratchURL()
        defer { try? FileManager.default.removeItem(at: empty) }
        FileManager.default.createFile(atPath: empty.path, contents: Data(), attributes: nil)
        precondition(WatchQAStore.load(from: empty).isEmpty, "空文件视为空")

        let blank = scratchURL()
        defer { try? FileManager.default.removeItem(at: blank) }
        try? Data("   \n".utf8).write(to: blank)
        precondition(WatchQAStore.load(from: blank).isEmpty, "空白文件视为空")

        let emptyArray = scratchURL()
        defer { try? FileManager.default.removeItem(at: emptyArray) }
        try? Data("[]".utf8).write(to: emptyArray)
        precondition(WatchQAStore.load(from: emptyArray).isEmpty, "空数组是合法的空问答")

        let corrupt = scratchURL()
        defer { try? FileManager.default.removeItem(at: corrupt) }
        try? Data("{not json".utf8).write(to: corrupt)
        precondition(WatchQAStore.load(from: corrupt).isEmpty, "损坏文件视为空，不得抛错")

        let notArray = scratchURL()
        defer { try? FileManager.default.removeItem(at: notArray) }
        try? Data(#"{"question":"x"}"#.utf8).write(to: notArray)
        precondition(WatchQAStore.load(from: notArray).isEmpty, "非数组视为损坏")

        WatchQAStore.append(
            WatchQAEntry(
                id: UUID(),
                time: 1,
                question: "恢复",
                answer: "新答",
                askedAt: Date(timeIntervalSince1970: 1),
                model: "claude-sonnet-5"
            ),
            to: corrupt
        )
        precondition(
            WatchQAStore.load(from: corrupt).map(\.question) == ["恢复"],
            "损坏文件上追加须写成合法数组，不得把坏内容留下"
        )
    }

    private static func checkTimelineInsert() {
        let cues = [
            VideoSubtitleCue(startTime: 10, endTime: 18, text: "开场"),
            VideoSubtitleCue(startTime: 18, endTime: 25, text: "大象"),
            VideoSubtitleCue(startTime: 40, endTime: 50, text: "结尾")
        ]
        let before = entry(id: 1, time: 3, question: "片头前")
        let duringFirst = entry(id: 2, time: 12, question: "开场中")
        let atSecondStart = entry(id: 3, time: 18, question: "第二句起点")
        let inGap = entry(id: 4, time: 30, question: "句间空隙")
        let afterLast = entry(id: 5, time: 80, question: "片尾后")
        let sameSlotLater = entry(id: 6, time: 12.5, question: "开场中稍后")
        let nanTime = entry(id: 7, time: .nan, question: "无效时间")

        let insertions = WatchQATimeline.insertions(
            cues: cues,
            entries: [afterLast, inGap, nanTime, before, sameSlotLater, duringFirst, atSecondStart]
        )
        precondition(
            insertions.leading.map(\.question) == ["片头前"],
            "早于第一句的问答排在字幕流最前"
        )
        precondition(insertions.after.count == cues.count)
        precondition(
            insertions.after[0].map(\.question) == ["开场中", "开场中稍后"],
            "问答插在对应句块之后，同一句内按时间排"
        )
        precondition(
            insertions.after[1].map(\.question) == ["第二句起点", "句间空隙"],
            "句间空隙跟在上一句后面，排在下一句之前"
        )
        precondition(
            insertions.after[2].map(\.question) == ["片尾后"],
            "晚于最后一句的问答跟在末句后面"
        )
        precondition(
            !insertions.leading.contains(where: { $0.question == "无效时间" })
                && insertions.after.allSatisfy { $0.allSatisfy { $0.question != "无效时间" } },
            "无效时间不得进入时间轴"
        )

        let emptyCues = WatchQATimeline.insertions(
            cues: [],
            entries: [inGap, before]
        )
        precondition(
            emptyCues.leading.map(\.question) == ["片头前", "句间空隙"],
            "无字幕时问答仍按时间出现"
        )
        precondition(emptyCues.after.isEmpty)

        let emptyAll = WatchQATimeline.insertions(cues: [], entries: [])
        precondition(emptyAll.leading.isEmpty)
        precondition(emptyAll.after.isEmpty)
    }

    private static func entry(id: Int, time: Double, question: String) -> WatchQAEntry {
        WatchQAEntry(
            id: UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", id))")!,
            time: time,
            question: question,
            answer: "答",
            askedAt: Date(timeIntervalSince1970: Double(id)),
            model: "claude-sonnet-5"
        )
    }

    private static func scratchURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("qa-store-\(UUID().uuidString).qa.json")
    }
}
