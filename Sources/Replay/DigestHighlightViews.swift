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
                .frame(minHeight: 18)
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

struct DigestHighlightCommentField: NSViewRepresentable {
    var text: String
    var onSave: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSave: onSave)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: text)
        field.placeholderString = DigestBookChrome.commentPlaceholder
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = NSFont.systemFont(ofSize: 12)
        field.textColor = OpenMyChrome.nsMuted
        field.lineBreakMode = .byTruncatingTail
        field.cell?.usesSingleLineMode = true
        field.cell?.wraps = false
        field.delegate = context.coordinator
        context.coordinator.parent = self
        DispatchQueue.main.async {
            field.window?.makeFirstResponder(field)
        }
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        context.coordinator.onSave = onSave
        field.delegate = context.coordinator
        if field.currentEditor() == nil, field.stringValue != text {
            field.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: DigestHighlightCommentField?
        var onSave: (String) -> Void

        init(onSave: @escaping (String) -> Void) {
            self.onSave = onSave
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
                onSave(parent?.text ?? control.stringValue)
                return true
            }
            return false
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            onSave(field.stringValue)
        }
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
