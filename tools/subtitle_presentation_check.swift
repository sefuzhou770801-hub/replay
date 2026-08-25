import Foundation

@main
struct SubtitlePresentationCheck {
    static func main() {
        let bilingual = VideoSubtitleTrack(cues: [
            VideoSubtitleCue(startTime: 0, endTime: 2, text: "I've heard this before\n我以前听过"),
            VideoSubtitleCue(startTime: 2.4, endTime: 4, text: "Next sentence\n下一句")
        ])

        let bilingualPresentation = VideoSubtitlePresentation.resolve(
            track: bilingual,
            isEnabled: true,
            at: 1
        )
        precondition(bilingualPresentation?.text == "I've heard this before\n我以前听过")
        precondition(
            VideoSubtitlePresentation.displayLines(from: "I've heard this before\n我以前听过")
                == ["I've heard this before", "我以前听过"]
        )

        let identical = VideoSubtitleTrack(cues: [
            VideoSubtitleCue(startTime: 0, endTime: 2, text: "Sundar Pichai\nSundar Pichai")
        ])
        let identicalPresentation = VideoSubtitlePresentation.resolve(
            track: identical,
            isEnabled: true,
            at: 1
        )
        precondition(
            identicalPresentation?.text == "Sundar Pichai",
            "原文与译文相同时只显示一行，实际：\(identicalPresentation?.text ?? "nil")"
        )
        precondition(
            VideoSubtitlePresentation.displayLines(from: "Sundar Pichai\nSundar Pichai")
                == ["Sundar Pichai"]
        )
        precondition(
            VideoSubtitlePresentation.displayLines(from: "Hello\nHello\n你好") == ["Hello", "你好"]
        )

        let shortGapTrack = VideoSubtitleTrack(cues: [
            VideoSubtitleCue(startTime: 0, endTime: 2, text: "Hold me\n留着我"),
            VideoSubtitleCue(startTime: 2.5, endTime: 4, text: "Next\n下一句")
        ])
        let held = VideoSubtitlePresentation.resolve(
            track: shortGapTrack,
            isEnabled: true,
            at: 2.2
        )
        precondition(
            held?.text == "Hold me\n留着我",
            "句间空隙低于约一秒时应延续上一句，实际：\(held?.text ?? "nil")"
        )
        precondition(held?.id == shortGapTrack.cues[0].id)

        let longGapTrack = VideoSubtitleTrack(cues: [
            VideoSubtitleCue(startTime: 0, endTime: 2, text: "Fade out\n淡出"),
            VideoSubtitleCue(startTime: 4, endTime: 6, text: "Later\n之后")
        ])
        let faded = VideoSubtitlePresentation.resolve(
            track: longGapTrack,
            isEnabled: true,
            at: 3
        )
        precondition(
            faded == nil,
            "句间空隙超过约一秒时不得延续，实际：\(faded?.text ?? "nil")"
        )

        let afterLast = VideoSubtitlePresentation.resolve(
            track: shortGapTrack,
            isEnabled: true,
            at: 5
        )
        precondition(afterLast == nil, "最后一句结束后不得延续")

        precondition(
            VideoSubtitlePresentation.resolve(track: bilingual, isEnabled: false, at: 1) == nil
        )
        precondition(
            VideoSubtitlePresentation.resolve(track: nil, isEnabled: true, at: 1) == nil
        )

        let oneSecondGap = VideoSubtitleTrack(cues: [
            VideoSubtitleCue(startTime: 0, endTime: 1, text: "Edge"),
            VideoSubtitleCue(startTime: 2, endTime: 3, text: "After")
        ])
        let atThreshold = VideoSubtitlePresentation.resolve(
            track: oneSecondGap,
            isEnabled: true,
            at: 1.4
        )
        precondition(
            atThreshold?.text == "Edge",
            "空隙刚好约一秒时仍应延续上一句，实际：\(atThreshold?.text ?? "nil")"
        )

        print("subtitle_presentation_check=passed")
    }
}
