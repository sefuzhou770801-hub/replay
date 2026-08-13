import Foundation

@main
struct SidePaneSelectionCheck {
    static func main() {
        precondition(SidePaneSelection.openingMode(hasChapters: true) == .chapters)
        precondition(SidePaneSelection.openingMode(hasChapters: false) == .lyrics)

        precondition(
            SidePaneSelection.resolvedMode(
                preferred: .chapters,
                hasChapters: false,
                hasSubtitles: true
            ) == .chapters,
            "无章节时点章节应停在章节空态，不得弹回字幕"
        )
        precondition(
            SidePaneSelection.resolvedMode(
                preferred: .lyrics,
                hasChapters: true,
                hasSubtitles: false
            ) == .lyrics,
            "无字幕时点字幕应停在字幕空态，不得弹回章节"
        )
        precondition(
            SidePaneSelection.resolvedMode(
                preferred: .chapters,
                hasChapters: true,
                hasSubtitles: true
            ) == .chapters
        )

        precondition(SidePaneSelection.visibleTitle(for: .chapters) == "章节")
        precondition(SidePaneSelection.visibleTitle(for: .lyrics) == "字幕")
        precondition(SidePaneSelection.visibleTitle(for: .lyrics) != "歌词")

        print("side_pane_selection_check=passed")
    }
}
