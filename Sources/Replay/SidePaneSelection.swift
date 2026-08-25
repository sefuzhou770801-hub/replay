import Foundation

enum SidePaneMode: String {
    case chapters
    case lyrics
}

enum SidePaneSelection {
    static func openingMode(hasChapters: Bool) -> SidePaneMode {
        hasChapters ? .chapters : .lyrics
    }

    static func resolvedMode(
        preferred: SidePaneMode,
        hasChapters _: Bool,
        hasSubtitles _: Bool
    ) -> SidePaneMode {
        preferred
    }

    static func recomputedMode(
        current: SidePaneMode,
        hasChapters: Bool,
        userHasManuallySwitched: Bool
    ) -> SidePaneMode {
        if userHasManuallySwitched {
            return current
        }
        return openingMode(hasChapters: hasChapters)
    }

    static func visibleTitle(for mode: SidePaneMode) -> String {
        switch mode {
        case .chapters:
            return "章节"
        case .lyrics:
            return "字幕"
        }
    }
}
