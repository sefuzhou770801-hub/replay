import AppKit
import SwiftUI

@main
struct DigestHighlightCommentProof {
    static let fieldPath = "/tmp/digest-highlight-comment-field.png"
    static let savedPath = "/tmp/digest-highlight-comment-saved.png"
    static let narrowPath = "/tmp/digest-highlight-comment-field-narrow.png"
    static let wideWidth = 360
    static let canvasHeight = 160

    @MainActor
    static func main() {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        OpenMyChrome.applyAppearance()

        let fieldHits = render(editing: true, comment: "", width: wideWidth, path: fieldPath)
        guard let field = fieldHits["comment"] else {
            fatalError("digest_highlight_comment_proof: 划线后未输入须画出输入框")
        }
        precondition(
            abs(field.height - DigestBookChrome.commentFieldHeight) < 2,
            "输入框高度须为 \(DigestBookChrome.commentFieldHeight)，实际 \(field.height)"
        )
        if let text = fieldHits["cue-text"] {
            precondition(
                field.width + 1 >= text.width,
                "输入框须占满正文列宽：field=\(field.width) text=\(text.width)"
            )
        }

        let savedHits = render(editing: false, comment: "这句是关键", width: wideWidth, path: savedPath)
        guard let saved = savedHits["comment"] else {
            fatalError("digest_highlight_comment_proof: 已保存批语须画出文本行")
        }
        precondition(
            saved.height + 0.5 < DigestBookChrome.commentFieldHeight,
            "已保存批语须是文本行，不得保留输入框高度：\(saved.height)"
        )

        let narrowWidth = Int(DigestBookChrome.minColumnWidth)
        let narrowHits = render(
            editing: true,
            comment: "",
            width: narrowWidth,
            path: narrowPath
        )
        guard let narrow = narrowHits["comment"] else {
            fatalError("digest_highlight_comment_proof: 最窄宽度须画出输入框")
        }
        precondition(
            abs(narrow.height - DigestBookChrome.commentFieldHeight) < 2,
            "最窄宽度输入框高度须为 \(DigestBookChrome.commentFieldHeight)，实际 \(narrow.height)"
        )
        if let text = narrowHits["cue-text"] {
            precondition(
                narrow.width + 1 >= text.width,
                "最窄宽度输入框须占满正文列宽：field=\(narrow.width) text=\(text.width)"
            )
        }
        let trailing = CGFloat(narrowWidth) - narrow.maxX
        precondition(
            trailing <= 16,
            "最窄宽度输入框右侧不得留出空列：trailing=\(trailing)"
        )

        print(
            "digest_highlight_comment_proof field=\(fieldPath) saved=\(savedPath) narrow=\(narrowPath)"
        )
        print("digest_highlight_comment_proof=passed")
    }

    @MainActor
    private static func render(
        editing: Bool,
        comment: String,
        width: Int,
        path: String
    ) -> [String: CGRect] {
        let sink = CommentHitSink()
        let root = DigestHighlightCommentProofView(
            isEditing: editing,
            comment: comment,
            canvasWidth: width,
            sink: sink
        )
        let hosting = NSHostingView(rootView: root)
        hosting.appearance = NSAppearance(named: .darkAqua)
        let size = CGSize(width: width, height: canvasHeight)
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

        let bounds = NSRect(origin: .zero, size: size)
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
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
        return sink.hits
    }
}

final class CommentHitSink {
    var hits: [String: CGRect] = [:]
}

private struct DigestHighlightCommentProofView: View {
    let isEditing: Bool
    let comment: String
    let canvasWidth: Int
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
            VStack(alignment: .leading, spacing: DigestCueDisplay.pairSpacing) {
                DigestCueRow(
                    timeLabel: "0:10",
                    cueText: "Hello world.\n大家好。",
                    timeColumnWidth: 52,
                    isHighlighted: true
                )
                DigestHighlightCommentRow(
                    text: comment,
                    isEditing: isEditing
                )
                .padding(.leading, 62)
            }
            .padding(.leading, 10)
            .padding(.trailing, 14)
            .padding(.vertical, DigestCueDisplay.rowVerticalPadding)
            Spacer(minLength: 0)
        }
        .frame(
            width: CGFloat(canvasWidth),
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
