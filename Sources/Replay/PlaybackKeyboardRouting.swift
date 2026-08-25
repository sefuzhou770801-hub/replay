import AppKit

enum PlaybackKeyboardAction: Equatable {
    case passThrough
    case togglePlayback
    case toggleFullscreen
    case exitFullscreen
    case skip(Double)
    case adjustRate(Double)
    case pasteURL
    case resignTextFocus
}

enum PlaybackKeyboardRouting {
    private static let shortcutModifiers: NSEvent.ModifierFlags = [
        .command, .option, .control, .shift
    ]

    static func action(
        isEditingText: Bool,
        keyCode: UInt16,
        character: String?,
        modifiers: NSEvent.ModifierFlags,
        hasActivePlayer: Bool
    ) -> PlaybackKeyboardAction {
        let mods = modifiers.intersection(shortcutModifiers)

        if isEditingText {
            if keyCode == 53, mods.isEmpty {
                return .resignTextFocus
            }
            return .passThrough
        }

        if mods == .command, character?.lowercased() == "v" {
            return .pasteURL
        }

        guard mods.isEmpty else { return .passThrough }

        if keyCode == 53 {
            return .exitFullscreen
        }

        guard hasActivePlayer else { return .passThrough }

        if keyCode == 49 {
            return .togglePlayback
        }
        if character?.lowercased() == "f" {
            return .toggleFullscreen
        }

        switch keyCode {
        case 123:
            return .skip(-10)
        case 124:
            return .skip(10)
        case 126:
            return .adjustRate(0.1)
        case 125:
            return .adjustRate(-0.1)
        default:
            return .passThrough
        }
    }

    static func isEditingText(in window: NSWindow?) -> Bool {
        isEditingText(firstResponder: window?.firstResponder)
    }

    static func isEditingText(firstResponder: NSResponder?) -> Bool {
        guard let responder = firstResponder else { return false }
        if let view = responder as? NSView, isEditableTextSurface(view) {
            return true
        }
        if let control = responder as? NSControl {
            return control.currentEditor() != nil
        }
        return false
    }

    static func isEditableTextSurface(_ view: NSView) -> Bool {
        if let textView = view as? NSTextView {
            return textView.isEditable
        }
        if let textField = view as? NSTextField {
            return textField.isEditable
        }
        return false
    }
}
