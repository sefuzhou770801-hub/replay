import AppKit
import Foundation

@main
struct KeyboardRoutingCheck {
    static func main() {
        _ = NSApplication.shared

        assertEditingDetection()
        assertIdlePlaybackShortcuts()
        assertEditingPassesText()
        assertEditingSpaceIsPassedThrough()
        assertSpacePassesWhenReceivingTextInput()
        assertLeftoverTextDoesNotBlockShortcuts()
        assertModifierCombinations()
        assertMissingPlayer()
        assertWindowFocusControllerClearsInitialResponder()

        print("keyboard_routing_check=passed")
    }

    private static func assertEditingDetection() {
        precondition(
            !PlaybackKeyboardRouting.isEditingText(firstResponder: nil),
            "无第一响应者时不得当作编辑态"
        )

        let editableView = NSTextView(frame: NSRect(x: 0, y: 0, width: 120, height: 24))
        editableView.isEditable = true
        precondition(
            PlaybackKeyboardRouting.isEditingText(firstResponder: editableView),
            "可编辑文本视图必须识别为编辑态"
        )

        editableView.isEditable = false
        precondition(
            !PlaybackKeyboardRouting.isEditingText(firstResponder: editableView),
            "只读文本视图不得识别为编辑态"
        )

        let field = NSTextField(string: "hello world")
        field.isEditable = true
        precondition(
            PlaybackKeyboardRouting.isEditingText(firstResponder: field),
            "可编辑输入框必须识别为编辑态"
        )

        field.isEditable = false
        precondition(
            !PlaybackKeyboardRouting.isEditingText(firstResponder: field),
            "只读输入框不得识别为编辑态"
        )
        precondition(
            !PlaybackKeyboardRouting.isEditableTextSurface(field),
            "只读输入框不得当作可编辑文字面"
        )
        field.isEditable = true
        precondition(PlaybackKeyboardRouting.isEditableTextSurface(field))
    }

    private static func assertWindowFocusControllerClearsInitialResponder() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        let field = NSTextField(string: "hello world")
        field.isEditable = true
        window.contentView = field
        window.makeFirstResponder(field)

        let controller = PlaybackWindowFocusController()
        controller.attach(to: window)
        precondition(
            !controller.allowTextFocus,
            "窗口挂上时不得把输入框当作用户正在编辑"
        )
        precondition(
            !controller.isUserEditingText,
            "启动后未点击输入框时，快捷键闸门必须视为空闲"
        )
        if window.firstResponder != nil {
            precondition(
                !PlaybackKeyboardRouting.isEditingText(in: window),
                "窗口创建后第一响应者不得停在链接输入框"
            )
        }

        controller.detach()
        window.close()
    }

    private static func assertIdlePlaybackShortcuts() {
        precondition(
            route(keyCode: 49, hasActivePlayer: true) == .togglePlayback,
            "空闲时空格必须切换播放"
        )
        precondition(
            route(character: "f", keyCode: 3, hasActivePlayer: true) == .toggleFullscreen,
            "空闲时 F 必须切换全屏"
        )
        precondition(
            route(character: "F", keyCode: 3, hasActivePlayer: true) == .toggleFullscreen,
            "大写 F 必须与小写同样切换全屏"
        )
        precondition(
            route(keyCode: 53, hasActivePlayer: true) == .exitFullscreen,
            "空闲时 Esc 必须退出全屏"
        )
        precondition(
            route(keyCode: 123, hasActivePlayer: true) == .skip(-10),
            "空闲时左方向键必须快退 10 秒"
        )
        precondition(
            route(keyCode: 124, hasActivePlayer: true) == .skip(10),
            "空闲时右方向键必须快进 10 秒"
        )
        precondition(
            route(keyCode: 126, hasActivePlayer: true) == .adjustRate(0.1),
            "空闲时上方向键必须加快播放速度"
        )
        precondition(
            route(keyCode: 125, hasActivePlayer: true) == .adjustRate(-0.1),
            "空闲时下方向键必须减慢播放速度"
        )
    }

    private static func assertEditingSpaceIsPassedThrough() {
        precondition(
            route(isEditingText: true, character: " ", keyCode: 49, hasActivePlayer: true)
                == .passThrough,
            "编辑态空格放行：有播放器时也必须交给输入框，不得拦截但不动作"
        )
        precondition(
            route(isEditingText: true, character: " ", keyCode: 49, hasActivePlayer: false)
                == .passThrough,
            "编辑态空格放行：无播放器时同样交给输入框"
        )
        for character in ["a", "h", "1", ".", "/", "w"] {
            precondition(
                route(isEditingText: true, character: character, keyCode: 0, hasActivePlayer: true)
                    == .passThrough,
                "编辑态可打印字符必须原样交给输入框"
            )
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        let field = NSTextField(string: "")
        field.isEditable = true
        window.contentView = field
        let controller = PlaybackWindowFocusController()
        controller.attach(to: window)
        window.makeFirstResponder(field)

        precondition(
            !controller.allowTextFocus,
            "HID 聚焦不经过点击监听时，allowTextFocus 仍为假"
        )
        precondition(
            PlaybackKeyboardRouting.isEditingText(in: window),
            "输入框持有第一响应者时必须判定为编辑态"
        )
        precondition(
            PlaybackKeyboardRouting.action(
                in: window,
                keyCode: 49,
                character: " ",
                modifiers: [],
                hasActivePlayer: true
            ) == .passThrough,
            "编辑态空格放行：按键决策必须只看第一响应者，不得因 allowTextFocus 为假而吞掉空格"
        )
        precondition(
            PlaybackKeyboardRouting.isEditingText(in: window),
            "判定编辑态空格时不得先清掉输入框焦点"
        )

        controller.detach()
        window.close()
    }

    private static func assertSpacePassesWhenReceivingTextInput() {
        precondition(
            PlaybackKeyboardRouting.isTextInputClassName("SwiftUI.TextFieldHost"),
            "SwiftUI 输入框类名必须识别为文字输入"
        )
        precondition(!PlaybackKeyboardRouting.isTextInputClassName("NSButton"))

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSView(frame: window.contentLayoutRect)
        let controller = PlaybackWindowFocusController()
        controller.attach(to: window)
        precondition(
            !PlaybackKeyboardRouting.isReceivingTextInput(in: window),
            "未点击输入框时不得当作正在接收文字"
        )
        precondition(
            PlaybackKeyboardRouting.action(
                in: window,
                keyCode: 49,
                character: " ",
                modifiers: [],
                hasActivePlayer: true
            ) == .togglePlayback,
            "未在输入时，空格才是播放快捷键"
        )

        controller.noteTextInputStarted()
        precondition(
            PlaybackKeyboardRouting.action(
                in: window,
                keyCode: 49,
                character: " ",
                modifiers: [],
                hasActivePlayer: true
            ) == .togglePlayback,
            "第一响应者不是输入框时，空格必须仍是播放快捷键"
        )
        precondition(
            PlaybackKeyboardRouting.action(
                in: window,
                keyCode: 4,
                character: "h",
                modifiers: [],
                hasActivePlayer: true
            ) == .passThrough
        )

        controller.setSwiftUITextFieldFocused(false)
        controller.resignTextFocus()
        precondition(
            PlaybackKeyboardRouting.action(
                in: window,
                keyCode: 49,
                character: " ",
                modifiers: [],
                hasActivePlayer: true
            ) == .togglePlayback,
            "失焦后空格必须恢复为播放快捷键"
        )

        let editor = NSTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        editor.isEditable = true
        editor.string = "hi"
        editor.setSelectedRange(NSRange(location: (editor.string as NSString).length, length: 0))
        window.contentView = editor
        window.makeFirstResponder(editor)
        controller.noteTextInputStarted()
        precondition(
            PlaybackKeyboardRouting.insertPlainText(" ", in: window),
            "编辑态空格必须能写入字段编辑器"
        )
        precondition(
            editor.string == "hi ",
            "写入后字段必须含空格"
        )
        precondition(
            PlaybackKeyboardRouting.insertPlainText("x", in: window)
        )
        precondition(editor.string == "hi x")

        controller.detach()
        window.close()
    }

    private static func assertEditingPassesText() {
        precondition(
            route(isEditingText: true, keyCode: 49, hasActivePlayer: true) == .passThrough,
            "编辑态空格必须留给文字"
        )
        precondition(
            route(isEditingText: true, character: "f", keyCode: 3, hasActivePlayer: true) == .passThrough,
            "编辑态 F 必须留给文字"
        )
        precondition(
            route(isEditingText: true, keyCode: 123, hasActivePlayer: true) == .passThrough,
            "编辑态左方向键必须移动光标"
        )
        precondition(
            route(isEditingText: true, keyCode: 124, hasActivePlayer: true) == .passThrough,
            "编辑态右方向键必须移动光标"
        )
        precondition(
            route(isEditingText: true, keyCode: 125, hasActivePlayer: true) == .passThrough,
            "编辑态下方向键必须留给文字"
        )
        precondition(
            route(isEditingText: true, keyCode: 126, hasActivePlayer: true) == .passThrough,
            "编辑态上方向键必须留给文字"
        )
        precondition(
            route(
                isEditingText: true,
                character: "v",
                keyCode: 9,
                modifiers: .command,
                hasActivePlayer: true
            ) == .passThrough,
            "编辑态 Command-V 必须走系统粘贴"
        )
        precondition(
            route(isEditingText: true, character: "h", keyCode: 4, hasActivePlayer: true) == .passThrough,
            "编辑态普通字母必须留给文字"
        )
        precondition(
            route(isEditingText: true, keyCode: 53, hasActivePlayer: true) == .resignTextFocus,
            "编辑态 Esc 必须退出输入框，不得再交给全屏"
        )
        precondition(
            route(
                isEditingText: true,
                keyCode: 53,
                modifiers: .command,
                hasActivePlayer: true
            ) == .passThrough,
            "编辑态带修饰键的 Esc 必须放行"
        )
    }

    private static func assertLeftoverTextDoesNotBlockShortcuts() {
        precondition(
            route(isEditingText: false, keyCode: 49, hasActivePlayer: true) == .togglePlayback,
            "输入框有未提交文字但已失焦时，空格必须仍切换播放"
        )
        precondition(
            route(isEditingText: false, character: "f", keyCode: 3, hasActivePlayer: true)
                == .toggleFullscreen,
            "输入框有未提交文字但已失焦时，F 必须仍切换全屏"
        )
        precondition(
            route(isEditingText: false, keyCode: 53, hasActivePlayer: true) == .exitFullscreen,
            "输入框有未提交文字但已失焦时，Esc 必须仍退出全屏"
        )
        precondition(
            route(isEditingText: false, keyCode: 123, hasActivePlayer: true) == .skip(-10),
            "输入框有未提交文字但已失焦时，方向键必须仍快退"
        )
    }

    private static func assertModifierCombinations() {
        precondition(
            route(keyCode: 49, modifiers: .shift, hasActivePlayer: true) == .passThrough,
            "Shift-空格不得切换播放"
        )
        precondition(
            route(character: "f", keyCode: 3, modifiers: .command, hasActivePlayer: true)
                == .passThrough,
            "Command-F 不得切换全屏"
        )
        precondition(
            route(keyCode: 49, modifiers: .option, hasActivePlayer: true) == .passThrough,
            "Option-空格不得切换播放"
        )
        precondition(
            route(keyCode: 49, modifiers: .control, hasActivePlayer: true) == .passThrough,
            "Control-空格不得切换播放"
        )
        precondition(
            route(character: "v", keyCode: 9, modifiers: .command, hasActivePlayer: true) == .pasteURL,
            "空闲时 Command-V 必须按链接粘贴"
        )
        precondition(
            route(character: "V", keyCode: 9, modifiers: .command, hasActivePlayer: false) == .pasteURL,
            "无播放器时 Command-V 仍必须按链接粘贴"
        )
        precondition(
            route(
                character: "v",
                keyCode: 9,
                modifiers: [.command, .shift],
                hasActivePlayer: true
            ) == .passThrough,
            "Command-Shift-V 不得按链接粘贴"
        )
        precondition(
            route(keyCode: 123, modifiers: .shift, hasActivePlayer: true) == .passThrough,
            "Shift-左方向键不得快退"
        )
    }

    private static func assertMissingPlayer() {
        precondition(
            route(keyCode: 49, hasActivePlayer: false) == .passThrough,
            "无播放器时空格必须放行"
        )
        precondition(
            route(character: "f", keyCode: 3, hasActivePlayer: false) == .passThrough,
            "无播放器时 F 必须放行"
        )
        precondition(
            route(keyCode: 123, hasActivePlayer: false) == .passThrough,
            "无播放器时左方向键必须放行"
        )
        precondition(
            route(keyCode: 124, hasActivePlayer: false) == .passThrough,
            "无播放器时右方向键必须放行"
        )
        precondition(
            route(keyCode: 125, hasActivePlayer: false) == .passThrough,
            "无播放器时下方向键必须放行"
        )
        precondition(
            route(keyCode: 126, hasActivePlayer: false) == .passThrough,
            "无播放器时上方向键必须放行"
        )
        precondition(
            route(keyCode: 53, hasActivePlayer: false) == .exitFullscreen,
            "无播放器时 Esc 仍交给退出全屏，由调用方决定是否消费"
        )
    }

    private static func route(
        isEditingText: Bool = false,
        character: String? = nil,
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags = [],
        hasActivePlayer: Bool
    ) -> PlaybackKeyboardAction {
        PlaybackKeyboardRouting.action(
            isEditingText: isEditingText,
            keyCode: keyCode,
            character: character,
            modifiers: modifiers,
            hasActivePlayer: hasActivePlayer
        )
    }
}
