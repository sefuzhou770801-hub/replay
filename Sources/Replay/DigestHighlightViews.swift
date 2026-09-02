import AppKit
import SwiftUI

struct DigestHighlightCommentRow: View {
    let text: String
    var isEditing = false
    var showPlaceholder = false
    var onBeginEdit: () -> Void = {}
    var onSave: (String) -> Void = { _ in }

    var body: some View {
        if isEditing {
            DigestHighlightCommentField(text: text, onSave: onSave)
                .frame(maxWidth: .infinity)
                .frame(height: DigestBookChrome.commentFieldHeight)
                .background(hitBackground)
                .accessibilityLabel(DigestBookChrome.commentPlaceholder)
        } else if DigestNoteComment.shouldDisplay(text) {
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(OpenMyChrome.muted)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(perform: onBeginEdit)
                .background(hitBackground)
                .accessibilityLabel(text)
        } else if showPlaceholder {
            Text(DigestBookChrome.commentPlaceholder)
                .font(.system(size: 12))
                .foregroundStyle(OpenMyChrome.faint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(perform: onBeginEdit)
                .accessibilityLabel(DigestBookChrome.commentPlaceholder)
        }
    }

    private var hitBackground: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: DigestBookHitKey.self,
                value: ["comment": proxy.frame(in: .named("digest-book-page"))]
            )
        }
    }
}

final class DigestCommentFieldView: NSView, NSTextFieldDelegate {
    let field = NSTextField(string: "")
    var onSave: (String) -> Void = { _ in }
    var parentText = ""

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        applyChrome(focused: false)
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = NSFont.systemFont(ofSize: 12)
        field.textColor = OpenMyChrome.nsInk
        field.lineBreakMode = .byTruncatingTail
        field.cell?.usesSingleLineMode = true
        field.cell?.wraps = false
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.delegate = self
        addSubview(field)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        let pad = DigestBookChrome.commentFieldPadding
        field.frame = bounds.insetBy(dx: pad, dy: 0)
    }

    func applyChrome(focused: Bool) {
        layer?.backgroundColor = OpenMyChrome.nsRaise.cgColor
        layer?.cornerRadius = OpenMyChrome.radiusSm
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.borderColor = (focused ? OpenMyChrome.nsRowSelectedStroke : OpenMyChrome.nsFieldBorder).cgColor
    }

    func control(
        _ control: NSControl,
        textView: NSTextView,
        doCommandBy commandSelector: Selector
    ) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            onSave(control.stringValue)
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            onSave(parentText)
            return true
        }
        return false
    }

    func controlTextDidBeginEditing(_ obj: Notification) {
        applyChrome(focused: true)
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        applyChrome(focused: false)
        onSave(field.stringValue)
    }
}

struct DigestHighlightCommentField: NSViewRepresentable {
    var text: String
    var onSave: (String) -> Void

    func makeNSView(context: Context) -> DigestCommentFieldView {
        let view = DigestCommentFieldView(frame: .zero)
        view.field.stringValue = text
        view.parentText = text
        view.onSave = onSave
        applyPlaceholder(to: view.field)
        DispatchQueue.main.async {
            let scroll = view.enclosingScrollView
            let clip = scroll?.contentView
            let origin = clip?.bounds.origin
            view.window?.makeFirstResponder(view.field)
            if let scroll, let clip, let origin {
                clip.scroll(to: origin)
                scroll.reflectScrolledClipView(clip)
            }
        }
        return view
    }

    func updateNSView(_ view: DigestCommentFieldView, context: Context) {
        view.parentText = text
        view.onSave = onSave
        applyPlaceholder(to: view.field)
        if view.field.currentEditor() == nil, view.field.stringValue != text {
            view.field.stringValue = text
        }
    }

    private func applyPlaceholder(to field: NSTextField) {
        field.placeholderAttributedString = NSAttributedString(
            string: DigestBookChrome.commentPlaceholder,
            attributes: [
                .foregroundColor: OpenMyChrome.nsFaint,
                .font: NSFont.systemFont(ofSize: 12)
            ]
        )
    }
}

struct DigestCollapsedHint: View {
    let hiddenCount: Int

    var body: some View {
        Text(DigestHighlightFilter.collapsedHint(hiddenCount))
            .font(.system(size: 12))
            .foregroundStyle(OpenMyChrome.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: DigestBookHitKey.self,
                        value: ["collapsed-hint": proxy.frame(in: .named("digest-book-page"))]
                    )
                }
            )
            .accessibilityLabel(DigestHighlightFilter.collapsedHint(hiddenCount))
    }
}
