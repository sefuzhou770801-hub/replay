import Foundation

@main
struct SubtitleOverlayLayoutCheck {
    static func main() {
        // 固定测宽：每个字符在 1pt 字号下占 1pt，便于用字面量推导期望值。
        let measure: (String, CGFloat) -> CGFloat = { text, size in
            CGFloat(text.count) * size
        }

        precondition(SubtitleOverlayLayout.maxOverlayWidth == 900)
        precondition(SubtitleOverlayLayout.baseFontSize(forSurfaceWidth: 420) == 16)
        precondition(SubtitleOverlayLayout.baseFontSize(forSurfaceWidth: 800) == 24)
        precondition(SubtitleOverlayLayout.baseFontSize(forSurfaceWidth: 1_280) == 32)
        precondition(SubtitleOverlayLayout.baseFontSize(forSurfaceWidth: 1_920) == 40)
        precondition(
            SubtitleOverlayLayout.baseFontSize(forSurfaceWidth: 1_920)
                > SubtitleOverlayLayout.baseFontSize(forSurfaceWidth: 800),
            "全屏基准字号必须明显大于窗口模式"
        )

        let english = "I've heard this before"
        let chinese = "我听过"
        let window = SubtitleOverlayLayout.resolve(
            lines: [english, chinese],
            surfaceWidth: 800,
            measure: measure
        )
        let chineseOnly = SubtitleOverlayLayout.resolve(
            lines: [chinese],
            surfaceWidth: 800,
            measure: measure
        )
        precondition(window.lines.count == 2)
        precondition(
            window.overlayWidth > chineseOnly.overlayWidth,
            "浮层宽度应取两行中较宽者，不得被短译文压窄"
        )
        precondition(window.lines[0].fontSize == 24, "英文行在窗口宽度内应保持基准字号")
        precondition(window.lines[1].fontSize == 24, "短译文应独立保持基准字号")
        precondition(!window.lines[0].isTruncated)
        precondition(!window.lines[1].isTruncated)
        precondition(window.overlayWidth <= SubtitleOverlayLayout.maxOverlayWidth)

        let independent = SubtitleOverlayLayout.resolve(
            lines: [String(repeating: "A", count: 80), "短"],
            surfaceWidth: 800,
            measure: measure
        )
        precondition(independent.lines.count == 2)
        precondition(
            independent.lines[0].fontSize < independent.lines[1].fontSize,
            "超长原文应单独缩小，短译文不得被牵连"
        )
        precondition(independent.lines[1].fontSize == 24)
        precondition(!independent.lines[0].isTruncated)
        precondition(!independent.lines[1].isTruncated)

        let narrow = SubtitleOverlayLayout.resolve(
            lines: [String(repeating: "W", count: 120), "短译"],
            surfaceWidth: 320,
            measure: measure
        )
        precondition(narrow.overlayWidth <= 320)
        precondition(!narrow.lines[0].isTruncated, "最窄窗口下也不得截断到省略号")
        precondition(
            narrow.lines[0].wraps || narrow.lines[0].fontSize
                < SubtitleOverlayLayout.baseFontSize(forSurfaceWidth: 320),
            "超长英文在最窄窗口下应缩小字号或折行"
        )
        precondition(
            narrow.lines[1].fontSize == SubtitleOverlayLayout.baseFontSize(forSurfaceWidth: 320),
            "短译文在窄窗口下仍保持自身基准字号"
        )

        let fullscreen = SubtitleOverlayLayout.resolve(
            lines: [english, chinese],
            surfaceWidth: 1_920,
            measure: measure
        )
        precondition(
            fullscreen.lines[0].fontSize > window.lines[0].fontSize,
            "全屏原文字号应大于窗口模式，实际全屏 \(fullscreen.lines[0].fontSize) 窗口 \(window.lines[0].fontSize)"
        )
        precondition(fullscreen.overlayWidth <= SubtitleOverlayLayout.maxOverlayWidth)

        let longFullscreen = SubtitleOverlayLayout.resolve(
            lines: [String(repeating: "A", count: 80), "短"],
            surfaceWidth: 1_920,
            measure: measure
        )
        precondition(longFullscreen.lines[0].fontSize == 40, "全屏长句应保持分级字号并折行，不得压回窗口字号")
        precondition(longFullscreen.lines[0].wraps)
        precondition(longFullscreen.lines[1].fontSize == 40)
        precondition(!longFullscreen.lines[0].isTruncated)

        let hiddenInset = SubtitleOverlayLayout.overlayBottomInset(controlsVisible: false)
        let visibleInset = SubtitleOverlayLayout.overlayBottomInset(controlsVisible: true)
        precondition(hiddenInset == 16)
        precondition(visibleInset > hiddenInset, "悬浮控制条出现时字幕必须上移避让")

        let realType = SubtitleOverlayLayout.resolve(
            lines: [
                "I've heard this before and I want the whole sentence visible.",
                "我听过"
            ],
            surfaceWidth: 800
        )
        precondition(realType.lines.count == 2)
        precondition(!realType.lines[0].isTruncated)
        precondition(!realType.lines[1].isTruncated)
        precondition(realType.lines[0].fontSize >= 12)
        precondition(
            realType.overlayWidth > 80,
            "真实英文行必须把浮层撑到足够宽度，实际 \(realType.overlayWidth)"
        )

        print("subtitle_overlay_layout_check=passed")
    }
}
