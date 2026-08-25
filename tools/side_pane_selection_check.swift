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

        precondition(
            SidePaneSelection.recomputedMode(
                current: .lyrics,
                hasChapters: true,
                userHasManuallySwitched: false
            ) == .chapters,
            "章节落地且用户未手切页签时，必须重算到章节页"
        )
        precondition(
            SidePaneSelection.recomputedMode(
                current: .lyrics,
                hasChapters: true,
                userHasManuallySwitched: true
            ) == .lyrics,
            "用户本次会话已手切页签时，不得因章节落地被强制切走"
        )
        precondition(
            SidePaneSelection.recomputedMode(
                current: .chapters,
                hasChapters: false,
                userHasManuallySwitched: false
            ) == .lyrics,
            "无章节且未手切时，按有章节优先章节页重算到字幕页"
        )
        precondition(
            SidePaneSelection.recomputedMode(
                current: .chapters,
                hasChapters: false,
                userHasManuallySwitched: true
            ) == .chapters,
            "用户手切到章节页后，缺章节也要停在章节空态"
        )
        precondition(
            SidePaneSelection.recomputedMode(
                current: .chapters,
                hasChapters: true,
                userHasManuallySwitched: false
            ) == .chapters
        )

        print("side_pane_selection_check=passed")
    }
}
