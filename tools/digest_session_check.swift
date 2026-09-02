import Foundation

@main
struct DigestSessionCheck {
    static func main() async throws {
        checkEmptySurface()
        checkCopyIsProductVoice()
        try await MainActor.run {
            try checkSwitchThreeVideosIsolated()
            checkMissingKeyHints()
        }
        try await checkExplainProgressVisibleWithDelay()
        print("digest_session_check=passed")
    }

    private static func checkEmptySurface() {
        precondition(DigestCopy.emptyTitle == "暂无字幕")
        precondition(DigestCopy.emptyDetail(hasSubtitleSource: false) == DigestCopy.emptyUnavailableDetail)
        precondition(DigestCopy.emptyDetail(hasSubtitleSource: true) == DigestCopy.emptyLoadingDetail)
        precondition(!DigestCopy.showsBook(cueCount: 0, qaCount: 0))
        precondition(DigestCopy.showsBook(cueCount: 0, qaCount: 1), "仅有看时问答时仍显示侧栏内容")
        precondition(DigestCopy.showsBook(cueCount: 1, qaCount: 0))
        precondition(!DigestCopy.showsDigestActions(cueCount: 0), "无字幕不得出现生成目录与划线入口")
        precondition(DigestCopy.showsDigestActions(cueCount: 1))
    }

    private static func checkCopyIsProductVoice() {
        let banned = ["验收", "任务书", "实现者", "ticket", "spec"]
        let phrases = [
            DigestCopy.missingKeyHint,
            DigestCopy.noSubtitles,
            DigestCopy.writeFailed,
            DigestCopy.emptyTitle,
            DigestCopy.emptyLoadingDetail,
            DigestCopy.emptyUnavailableDetail,
            DigestRequestBuilder.missingKeyHint,
            DigestTOCCopy.missingKeyHint,
            DigestTOCCopy.generatingLabel,
            "稍等…",
            DigestExplainQuality.retryPrompt
        ]
        for phrase in phrases {
            for word in banned {
                precondition(!phrase.contains(word), "状态文案不得含任务描述措辞「\(word)」：\(phrase)")
            }
        }
        precondition(DigestRequestBuilder.missingKeyHint == DigestCopy.missingKeyHint)
        precondition(DigestTOCCopy.missingKeyHint == DigestCopy.missingKeyHint)
        precondition(DigestCopy.missingKeyHint.contains("密钥"))
        precondition(DigestCopy.missingKeyHint.contains("AnthropicAPIKey"))
        precondition(DigestCopy.missingKeyHint.contains("GeminiAPIKey"))
    }

    @MainActor
    private static func checkSwitchThreeVideosIsolated() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("digest-switch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let ids = [UUID(), UUID(), UUID()]
        let notes = [
            DigestNote(id: UUID(), time: 1, text: "视频甲", createdAt: Date(), comment: "甲批语"),
            DigestNote(id: UUID(), time: 2, text: "视频乙", createdAt: Date(), comment: "乙批语"),
            DigestNote(id: UUID(), time: 3, text: "视频丙", createdAt: Date(), comment: "丙批语")
        ]
        let annotations = [
            DigestAnnotation(id: UUID(), time: 1, text: "视频甲", explanation: "甲解释", createdAt: Date(), model: "m"),
            DigestAnnotation(id: UUID(), time: 2, text: "视频乙", explanation: "乙解释", createdAt: Date(), model: "m"),
            DigestAnnotation(id: UUID(), time: 3, text: "视频丙", explanation: "丙解释", createdAt: Date(), model: "m")
        ]
        for index in 0..<3 {
            try DigestNotesStore.save([notes[index]], itemID: ids[index], folder: folder)
            try DigestAnnotationsStore.save([annotations[index]], itemID: ids[index], folder: folder)
            try DigestOverviewStore.save(
                DigestOverviewRecord(
                    payload: DigestOverviewPayload(
                        chapters: [
                            DigestGeneratedChapter(
                                title: "第\(index + 1)章",
                                timestamp: "0:00",
                                timestampSeconds: 0,
                                summary: "属于视频\(index)"
                            )
                        ],
                        keyQuotes: [],
                        source: .generated,
                        durationSeconds: 60
                    ),
                    generatedAt: Date(),
                    model: "m"
                ),
                itemID: ids[index],
                folder: folder
            )
        }

        let session = DigestSession()
        session.apiKeyEnvironment = [:]
        session.load(itemID: ids[0], folder: folder)
        session.showsHighlightsOnly = true
        precondition(session.notes.first?.text == "视频甲")
        precondition(session.annotations.first?.explanation == "甲解释")
        precondition(session.overview?.chapters.first?.summary == "属于视频0")
        precondition(session.showsHighlightsOnly)

        session.load(itemID: ids[1], folder: folder)
        precondition(!session.showsHighlightsOnly, "换视频必须退出只看划线")
        precondition(session.notes.first?.text == "视频乙", "乙的划线不得被甲污染")
        precondition(session.annotations.first?.explanation == "乙解释")
        precondition(session.overview?.chapters.first?.title == "第2章")
        precondition(session.notes.first?.text != "视频甲")

        session.load(itemID: ids[2], folder: folder)
        precondition(session.notes.first?.comment == "丙批语")
        precondition(session.annotations.first?.explanation == "丙解释")
        precondition(session.overview?.chapters.first?.summary == "属于视频2")

        session.showsHighlightsOnly = true
        session.load(itemID: ids[0], folder: folder)
        precondition(!session.showsHighlightsOnly)
        precondition(session.notes.first?.text == "视频甲", "切回甲时痕迹必须还在")
        precondition(session.annotations.first?.explanation == "甲解释")
    }

    @MainActor
    private static func checkMissingKeyHints() {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("digest-nokey-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let session = DigestSession()
        session.apiKeyDefaults = UserDefaults(suiteName: "digest-nokey-\(UUID().uuidString)")!
        session.apiKeyEnvironment = [:]
        session.load(itemID: UUID(), folder: folder)

        let cue = VideoSubtitleCue(startTime: 1, endTime: 2, text: "Hello world.\n大家好。")
        session.explainCue(index: 0, title: "Demo", cues: [cue])
        precondition(!session.isExplaining, "无密钥不得进入解释进行中")
        precondition(
            session.explainMessage(for: 0) == DigestCopy.missingKeyHint,
            "解释无密钥必须给出引导。实际：\(session.explainMessage(for: 0) ?? "nil")"
        )

        session.generateOverview(title: "Demo", author: "A", duration: 10, cues: [cue], chapters: [])
        precondition(!session.isGeneratingOverview)
        precondition(
            session.overviewMessage == DigestCopy.missingKeyHint,
            "生成目录无密钥必须给出引导。实际：\(session.overviewMessage ?? "nil")"
        )
    }

    @MainActor
    private static func checkExplainProgressVisibleWithDelay() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("digest-delay-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let session = DigestSession()
        let defaults = UserDefaults(suiteName: "digest-delay-\(UUID().uuidString)")!
        defaults.set("sk-test", forKey: WatchQAAPIKey.defaultsKey)
        session.apiKeyDefaults = defaults
        session.apiKeyEnvironment = [:]
        session.load(itemID: UUID(), folder: folder)

        session.completeFn = { _, _, _, _, _, _ in
            try await Task.sleep(nanoseconds: 250_000_000)
            return "attention 在这里指把注意力放在这句话上。"
        }

        let cue = VideoSubtitleCue(startTime: 1, endTime: 3, text: "Pay attention.\n请注意。")
        session.explainCue(index: 0, title: "Demo", cues: [cue])
        precondition(session.isExplaining, "慢网下解释开始后必须进入进行中")
        precondition(session.explainingCueIndex == 0)
        precondition(session.isExplainingCue(0))

        try await Task.sleep(nanoseconds: 80_000_000)
        precondition(session.isExplaining, "延迟未结束时进行中反馈必须仍在")

        try await Task.sleep(nanoseconds: 400_000_000)
        precondition(!session.isExplaining, "结束后不得停在进行中")
        precondition(session.annotation(for: cue)?.explanation.contains("注意力") == true)
    }
}


