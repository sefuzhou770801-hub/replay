import AppKit
import SwiftUI

@main
struct DigestHighlightCommentProof {
    static let fieldPath = "/tmp/digest-highlight-comment-field.png"
    static let typingPath = "/tmp/digest-highlight-comment-typing.png"
    static let savedPath = "/tmp/digest-highlight-comment-saved.png"
    static let canvasWidth = 360
    static let canvasHeight = 180

    @MainActor
    static func main() {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        OpenMyChrome.applyAppearance()

        precondition(DigestBookChrome.commentFieldHeight == 28)
        precondition(DigestBookChrome.commentFieldPadding == 10)
        precondition(DigestBookChrome.commentFieldSpacing == 6)
        precondition(DigestBookChrome.commentPlaceholder == "写一句批语")
        precondition(DigestBookChrome.commentHintIdle == "回车保存 · Esc 取消")
        precondition(DigestBookChrome.commentHintTyping == "回车保存")
        precondition(DigestBookChrome.commentSavedSize == 11)
        precondition(DigestBookChrome.commentHintSpacing == 10)

        let idleHint = DigestBookChrome.commentHintIdle
        let typingHint = DigestBookChrome.commentHintTyping
        let idleWidth = DigestCommentHintLayout.width(of: idleHint)
        let typingWidth = DigestCommentHintLayout.width(of: typingHint)
        let pads = DigestBookChrome.commentFieldPadding * 2
        let hideIdleWidth = pads + idleWidth + DigestBookChrome.commentHintSpacing - 1
        let showIdleWidth = pads + idleWidth + DigestBookChrome.commentHintSpacing + 1
        precondition(
            !DigestCommentHintLayout.shouldShow(columnWidth: hideIdleWidth, hint: idleHint),
            "窄于提示全宽加 10 点间距须隐藏"
        )
        precondition(
            DigestCommentHintLayout.shouldShow(columnWidth: showIdleWidth, hint: idleHint),
            "够放下提示全宽加 10 点间距须显示"
        )
        precondition(
            !DigestCommentHintLayout.shouldShow(
                columnWidth: pads + typingWidth + DigestBookChrome.commentHintSpacing - 1,
                hint: typingHint
            ),
            "输入中窄列须隐藏提示"
        )

        let hiddenView = DigestCommentFieldView(
            frame: NSRect(x: 0, y: 0, width: hideIdleWidth, height: DigestBookChrome.commentFieldHeight)
        )
        hiddenView.layout()
        precondition(hiddenView.hintLabel.isHidden, "窄列布局须隐藏提示，不得截断")
        precondition(
            abs(hiddenView.field.frame.width - (hideIdleWidth - pads)) < 1,
            "隐藏提示后输入区须占满内宽"
        )

        let empty = render(editing: true, comment: "", path: fieldPath)
        printMetrics(name: "输入态", result: empty)
        assertEditing(empty, expectedHint: DigestBookChrome.commentHintIdle)

        let typing = render(editing: true, comment: "这句是关键", path: typingPath)
        printMetrics(name: "输入中", result: typing)
        assertEditing(typing, expectedHint: DigestBookChrome.commentHintTyping)

        let saved = render(editing: false, comment: "这句是关键", path: savedPath)
        printMetrics(name: "已保存", result: saved)
        guard let savedComment = saved.hits["comment"] else {
            fatalError("digest_highlight_comment_proof: 已保存须画出文本行")
        }
        precondition(saved.hits["comment-pen"] != nil, "已保存须有笔形图标")
        precondition(
            savedComment.height + 0.5 < DigestBookChrome.commentFieldHeight,
            "已保存须是文本行，不得保留输入框高度：\(savedComment.height)"
        )
        precondition(saved.fieldView == nil, "已保存不得保留输入框")

        print(
            "digest_highlight_comment_proof field=\(fieldPath) typing=\(typingPath) saved=\(savedPath)"
        )
        print("digest_highlight_comment_proof=passed")
    }

    @MainActor
    private static func assertEditing(_ result: RenderResult, expectedHint: String) {
        guard let comment = result.hits["comment"] else {
            fatalError("digest_highlight_comment_proof: 编辑态须画出输入框")
        }
        guard let cue = result.hits["cue-text"] else {
            fatalError("digest_highlight_comment_proof: 须有句子正文")
        }
        guard let mark = result.hits["highlight-mark"] else {
            fatalError("digest_highlight_comment_proof: 须有划线竖线")
        }
        guard let fieldView = result.fieldView else {
            fatalError("digest_highlight_comment_proof: 找不到输入框视图")
        }

        let chrome = fieldView.bounds
        let inner = fieldView.field.frame
        let hint = fieldView.hintLabel.frame
        precondition(
            abs(comment.height - DigestBookChrome.commentFieldHeight) < 1.5,
            "输入框高度须为 28，实际 \(comment.height)"
        )
        precondition(
            abs(inner.minX - DigestBookChrome.commentFieldPadding) < 1,
            "左内边距须为 10，实际 \(inner.minX)"
        )
        let rightPad = chrome.width - hint.maxX
        precondition(
            abs(rightPad - DigestBookChrome.commentFieldPadding) < 1.5,
            "右内边距须为 10，实际 \(rightPad)"
        )
        let spacing = comment.minY - cue.maxY
        precondition(
            abs(spacing - DigestBookChrome.commentFieldSpacing) < 2,
            "与句子间距须为 6，实际 \(spacing)"
        )
        precondition(
            mark.maxY <= comment.minY + 0.5,
            "竖线不得延伸进输入框：mark.maxY=\(mark.maxY) comment.minY=\(comment.minY)"
        )
        precondition(
            abs(comment.minX - cue.minX) < 2,
            "输入框左缘须对齐正文列：comment=\(comment.minX) cue=\(cue.minX)"
        )
        precondition(
            comment.width + 1 >= cue.width,
            "输入框须占满正文列宽：comment=\(comment.width) cue=\(cue.width)"
        )
        precondition(
            fieldView.hintLabel.stringValue == expectedHint,
            "提示须为「\(expectedHint)」，实际「\(fieldView.hintLabel.stringValue)」"
        )
        let needed = DigestCommentHintLayout.width(of: expectedHint)
        if DigestCommentHintLayout.shouldShow(columnWidth: chrome.width, hint: expectedHint) {
            precondition(!fieldView.hintLabel.isHidden, "列宽足够时提示须完整显示")
            precondition(
                fieldView.hintLabel.frame.width + 0.5 >= needed,
                "提示不得截断：frame=\(fieldView.hintLabel.frame.width) 文本=\(needed)"
            )
            precondition(
                fieldView.hintLabel.lineBreakMode == .byClipping,
                "提示不得用截断换行"
            )
        } else {
            precondition(fieldView.hintLabel.isHidden, "列宽不足时提示须整体隐藏")
        }
        precondition(result.hits["explain"] == nil, "编辑期间不得显示解释")
        precondition(result.hits["highlight-action"] == nil, "编辑期间不得显示划线按钮")

        let fill = hexString(fieldView.layer?.backgroundColor)
        precondition(fill == "#1E1E1E", "底色须为 raise #1E1E1E，实际 \(fill)")
        let radius = fieldView.layer?.cornerRadius ?? -1
        precondition(abs(radius - OpenMyChrome.radiusSm) < 0.5, "圆角须为 8，实际 \(radius)")
        let border = fieldView.layer?.borderWidth ?? -1
        precondition(abs(border - 1) < 0.1, "描边须为 1 点，实际 \(border)")
    }

    @MainActor
    private static func printMetrics(name: String, result: RenderResult) {
        let comment = result.hits["comment"]
        let cue = result.hits["cue-text"]
        let mark = result.hits["highlight-mark"]
        print("---- \(name) ----")
        print("  comment=\(fmtRect(comment))")
        print("  cue-text=\(fmtRect(cue))")
        print("  highlight-mark=\(fmtRect(mark))")
        if let comment, let cue {
            print("  spacing=\(fmt(comment.minY - cue.maxY)) alignDx=\(fmt(comment.minX - cue.minX))")
        }
        if let comment, let mark {
            print("  markY=\(fmt(mark.minY))..\(fmt(mark.maxY)) vs comment.minY=\(fmt(comment.minY))")
        }
        if let fieldView = result.fieldView {
            print(
                "  chrome=\(fmtNS(fieldView.frame)) field=\(fmtNS(fieldView.field.frame)) hint=\(fmtNS(fieldView.hintLabel.frame))"
            )
            print(
                "  paddingLeft=\(fmt(fieldView.field.frame.minX)) paddingRight=\(fmt(fieldView.frame.width - fieldView.hintLabel.frame.maxX))"
            )
            print(
                "  fill=\(hexString(fieldView.layer?.backgroundColor)) border=\(hexString(fieldView.layer?.borderColor)) width=\(fmt(fieldView.layer?.borderWidth ?? 0)) radius=\(fmt(fieldView.layer?.cornerRadius ?? 0))"
            )
            print("  hintText=\(fieldView.hintLabel.stringValue)")
        }
        if let pen = result.hits["comment-pen"] {
            print("  comment-pen=\(fmtRect(pen))")
        }
    }

    @MainActor
    private static func render(editing: Bool, comment: String, path: String) -> RenderResult {
        let sink = CommentHitSink()
        let root = DigestHighlightCommentProofView(
            isEditing: editing,
            comment: comment,
            sink: sink
        )
        let hosting = NSHostingView(rootView: root)
        hosting.appearance = NSAppearance(named: .darkAqua)
        let size = CGSize(width: canvasWidth, height: canvasHeight)
        hosting.frame = NSRect(origin: .zero, size: size)
        let window = OneXWindow(
            contentRect: hosting.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.alphaValue = 0
        window.ignoresMouseEvents = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = OpenMyChrome.nsCanvas
        window.contentView = hosting
        window.orderBack(nil)
        hosting.layoutSubtreeIfNeeded()
        window.layoutIfNeeded()
        hosting.displayIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        hosting.layoutSubtreeIfNeeded()
        hosting.displayIfNeeded()

        let fieldView = findCommentField(in: hosting)
        fieldView?.layoutSubtreeIfNeeded()

        let bounds = NSRect(origin: .zero, size: size)
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: canvasWidth,
            pixelsHigh: canvasHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        guard let rep else { fatalError("digest_highlight_comment_proof: 无法生成位图 \(path)") }
        rep.size = bounds.size
        hosting.cacheDisplay(in: bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            fatalError("digest_highlight_comment_proof: 无法编码 \(path)")
        }
        do {
            try png.write(to: URL(fileURLWithPath: path))
        } catch {
            fatalError("digest_highlight_comment_proof: 写 \(path) 失败 \(error)")
        }
        window.close()
        return RenderResult(hits: sink.hits, fieldView: fieldView)
    }

    private static func findCommentField(in view: NSView) -> DigestCommentFieldView? {
        if let field = view as? DigestCommentFieldView { return field }
        for child in view.subviews {
            if let found = findCommentField(in: child) { return found }
        }
        return nil
    }

    private static func fmt(_ value: CGFloat) -> String {
        String(format: "%.2f", Double(value))
    }

    private static func fmtRect(_ rect: CGRect?) -> String {
        guard let rect else { return "nil" }
        return "x=\(fmt(rect.minX)) y=\(fmt(rect.minY)) w=\(fmt(rect.width)) h=\(fmt(rect.height)) maxY=\(fmt(rect.maxY))"
    }

    private static func fmtNS(_ rect: NSRect) -> String {
        "x=\(fmt(rect.minX)) y=\(fmt(rect.minY)) w=\(fmt(rect.width)) h=\(fmt(rect.height))"
    }

    private static func hexString(_ color: CGColor?) -> String {
        guard let color else { return "nil" }
        guard let converted = color.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil),
              let comps = converted.components, comps.count >= 3 else {
            return "nil"
        }
        let r = Int((comps[0] * 255).rounded())
        let g = Int((comps[1] * 255).rounded())
        let b = Int((comps[2] * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

struct RenderResult {
    var hits: [String: CGRect]
    var fieldView: DigestCommentFieldView?
}

final class CommentHitSink {
    var hits: [String: CGRect] = [:]
}

private struct DigestHighlightCommentProofView: View {
    let isEditing: Bool
    let comment: String
    let sink: CommentHitSink

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DigestBookToolbar(
                query: "",
                onQueryChange: { _ in },
                matchCount: 0,
                activeIndex: nil,
                highlightCount: 1,
                step: { _ in }
            )
            VStack(alignment: .leading, spacing: 0) {
                DigestCueRow(
                    timeLabel: "0:10",
                    cueText: "Hello world.\n大家好。",
                    timeColumnWidth: 52,
                    isHighlighted: true,
                    showsActions: false
                )
                DigestHighlightCommentRow(
                    text: comment,
                    isEditing: isEditing
                )
                .padding(.top, DigestBookChrome.commentFieldSpacing)
                .padding(.leading, 62)
            }
            .padding(.leading, 10)
            .padding(.trailing, 14)
            .padding(.vertical, DigestCueDisplay.rowVerticalPadding)
            Spacer(minLength: 0)
        }
        .frame(
            width: CGFloat(DigestHighlightCommentProof.canvasWidth),
            height: CGFloat(DigestHighlightCommentProof.canvasHeight),
            alignment: .top
        )
        .background(OpenMyChrome.canvas)
        .coordinateSpace(name: "digest-book-page")
        .onPreferenceChange(DigestBookHitKey.self) { sink.hits = $0 }
    }
}

private final class OneXWindow: NSWindow {
    override var backingScaleFactor: CGFloat { 1 }
}
