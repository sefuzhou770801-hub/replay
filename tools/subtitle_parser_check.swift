import Foundation

@main
struct SubtitleParserCheck {
    static func main() {
        let srt = """
        1
        00:00:01,250 --> 00:00:03,500
        Hello <i>offline</i> world &amp; friends.

        2
        00:00:03,500 --> 00:00:05,000
        Second line
        continues here.
        """
        let srtCues = VideoSubtitleTrack.parse(srt)
        precondition(srtCues.count == 2)
        precondition(srtCues[0].startTime == 1.25)
        precondition(srtCues[0].text == "Hello offline world & friends.")
        let srtTrack = VideoSubtitleTrack(cues: srtCues)
        precondition(srtTrack.text(at: 0.5) == nil)
        precondition(srtTrack.text(at: 2) == "Hello offline world & friends.")
        precondition(srtTrack.text(at: 4) == "Second line\ncontinues here.")

        let vtt = """
        WEBVTT

        cue-1
        00:06.000 --> 00:08.250 align:middle
        A WebVTT caption
        """
        let vttCues = VideoSubtitleTrack.parse(vtt)
        precondition(vttCues.count == 1)
        precondition(vttCues[0].startTime == 6)
        precondition(vttCues[0].endTime == 8.25)

        // YouTube 滚动字幕：10ms 闪现 cue 紧跟更长扩展句，歌词轴会成对重复。
        // 样本取自韩语工作音乐 .zh.srt 8:52 一带（双语两行保留）。
        let rollingSrt = """
        1
        00:08:51,750 --> 00:08:51,760
        rhythm in the beat. Nothing loud and
        节拍中安静的节奏。没有喧嚣，没有

        2
        00:08:51,760 --> 00:08:54,710
        rhythm in the beat. Nothing loud and nothing strong. Just the city's moving
        节拍中安静的节奏。没有喧嚣，没有强烈。只有城市流动的

        3
        00:08:54,710 --> 00:08:54,720
        nothing strong. Just the city's moving
        没有强烈。只有城市流动的

        4
        00:08:54,720 --> 00:08:57,910
        nothing strong. Just the city's moving song. Coffee warmth and open view.
        没有强烈。只有城市流动的歌声。咖啡的温暖和开阔的视野。
        """
        let rollingCues = VideoSubtitleTrack.parse(rollingSrt)
        precondition(
            rollingCues.count == 2,
            "expected flash cues collapsed, got \(rollingCues.count)"
        )
        precondition(rollingCues[0].startTime == 531.76)
        precondition(rollingCues[0].endTime == 534.71)
        precondition(rollingCues[0].text.contains("\n"), "bilingual two-line cue must stay intact")
        precondition(rollingCues[0].text.contains("nothing strong"))
        precondition(rollingCues[0].text.contains("节拍中安静的节奏"))
        precondition(rollingCues[1].startTime == 534.72)
        precondition(rollingCues[1].text.contains("Coffee warmth"))
        precondition(rollingCues[1].text.contains("咖啡的温暖"))
        // 画面字幕取数：扩展句时间窗内仍是双语两行
        let rollingTrack = VideoSubtitleTrack(cues: rollingCues)
        let caption = rollingTrack.text(at: 533)
        precondition(caption != nil)
        precondition(caption!.contains("\n"))
        precondition(caption!.contains("rhythm in the beat"))
        precondition(caption!.contains("节拍中安静的节奏"))

        // 正常邻接 cue（时长均非闪现）不得被误删
        let normalAdjacent = """
        1
        00:00:01,000 --> 00:00:03,000
        Hello

        2
        00:00:03,000 --> 00:00:05,000
        World
        """
        let normalCues = VideoSubtitleTrack.parse(normalAdjacent)
        precondition(normalCues.count == 2)
        precondition(normalCues[0].text == "Hello")
        precondition(normalCues[1].text == "World")

        // 极短但内容无关（审查 S1）：不得因时长邻接误删
        let distinctShort = """
        1
        00:00:01,000 --> 00:00:01,040
        [door slams]

        2
        00:00:01,040 --> 00:00:03,000
        Hello
        """
        let distinctCues = VideoSubtitleTrack.parse(distinctShort)
        precondition(
            distinctCues.count == 2,
            "distinct short cue must be kept, got \(distinctCues.count)"
        )
        precondition(distinctCues[0].text == "[door slams]")
        precondition(distinctCues[0].startTime == 1.0)
        precondition(distinctCues[0].endTime == 1.04)
        precondition(distinctCues[1].text == "Hello")
        precondition(distinctCues[1].startTime == 1.04)

        if CommandLine.arguments.count > 1 {
            let downloadedURL = URL(fileURLWithPath: CommandLine.arguments[1])
            guard let downloadedTrack = VideoSubtitleTrack(contentsOf: downloadedURL) else {
                preconditionFailure("Could not parse the downloaded subtitle fixture")
            }
            precondition(downloadedTrack.cues.count > 10)
            print("downloaded_subtitle_cues=\(downloadedTrack.cues.count)")
        }

        print("subtitle_parser_check=passed")
    }
}
