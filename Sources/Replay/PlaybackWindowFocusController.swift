import AppKit

extension Notification.Name {
    static let replayTextFocusShouldResign = Notification.Name("ReplayTextFocusShouldResign")
}

enum TextFocusResignReason: String {
    case escape
    case other

    static let userInfoKey = "reason"
    /// 在卸第一响应者之前写入，标题编辑用它判断 Esc 取消还是点走保存。
    static var latest: TextFocusResignReason = .other
}

/// 窗口层焦点闸门：启动时不把键盘交给链接输入框，点击输入框以外立即失焦。
/// SwiftUI 手势覆盖不到 AppKit 视频面和控制按钮，所以用窗口级鼠标监听。
final class PlaybackWindowFocusController {
    private static let byWindow = NSMapTable<NSWindow, PlaybackWindowFocusController>.weakToStrongObjects()

    private weak var window: NSWindow?
    private var mouseMonitor: Any?
    private var keyWindowObserver: NSObjectProtocol?
    static let urlFieldAccessibilityID = "replay.url-field"

    private(set) var allowTextFocus = false
    private var swiftUITextFieldFocused = false

    static func attached(to window: NSWindow?) -> PlaybackWindowFocusController? {
        guard let window else { return nil }
        return byWindow.object(forKey: window)
    }

    static func resign(in window: NSWindow?, reason: TextFocusResignReason = .other) {
        if let controller = attached(to: window) {
            controller.resignTextFocus(reason: reason)
            return
        }
        postResignNotification(window: window, reason: reason)
        window?.makeFirstResponder(nil)
    }

    private static func postResignNotification(window: NSWindow?, reason: TextFocusResignReason) {
        TextFocusResignReason.latest = reason
        NotificationCenter.default.post(
            name: .replayTextFocusShouldResign,
            object: window,
            userInfo: [TextFocusResignReason.userInfoKey: reason.rawValue]
        )
    }

    func setSwiftUITextFieldFocused(_ focused: Bool) {
        swiftUITextFieldFocused = focused
        if focused {
            allowTextFocus = true
        }
    }

    func attach(to window: NSWindow) {
        guard self.window !== window else { return }
        detach()
        self.window = window
        Self.byWindow.setObject(self, forKey: window)
        window.initialFirstResponder = window.contentView
        window.makeFirstResponder(nil)
        installMouseMonitor()
        installKeyWindowObserver()
        rejectUnsolicitedTextFocus()
        scheduleInitialFocusClear(in: window)
    }

    func detach() {
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
            self.mouseMonitor = nil
        }
        if let keyWindowObserver {
            NotificationCenter.default.removeObserver(keyWindowObserver)
            self.keyWindowObserver = nil
        }
        if let window {
            Self.byWindow.removeObject(forKey: window)
        }
        window = nil
        allowTextFocus = false
        swiftUITextFieldFocused = false
    }

    func resignTextFocus(reason: TextFocusResignReason = .other) {
        guard let window else { return }
        clearTextFocus(in: window, reason: reason)
    }

    @discardableResult
    func rejectUnsolicitedTextFocus() -> Bool {
        guard let window, !allowTextFocus else { return false }
        guard PlaybackKeyboardRouting.isEditingText(in: window) else { return false }
        clearTextFocus(in: window)
        return true
    }

    private func scheduleInitialFocusClear(in window: NSWindow) {
        for delay in [0.0, 0.05, 0.15, 0.3, 0.75] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak window] in
                guard let self, let window, self.window === window else { return }
                self.rejectUnsolicitedTextFocus()
            }
        }
    }

    private func installKeyWindowObserver() {
        guard let window else { return }
        keyWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.rejectUnsolicitedTextFocus()
        }
    }

    private func installMouseMonitor() {
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
            [weak self] event in
            self?.handleMouseDown(event)
            return event
        }
    }

    private func handleMouseDown(_ event: NSEvent) {
        guard let window else { return }
        if event.window === window, clickHitsEditableText(event) {
            allowTextFocus = true
            return
        }

        allowTextFocus = false
        if PlaybackKeyboardRouting.isEditingText(in: window) {
            clearTextFocus(in: window, reason: .other)
        }
        // SwiftUI @FocusState 可能在下一拍把输入框焦点抢回来，再清一次。
        DispatchQueue.main.async { [weak self] in
            self?.rejectUnsolicitedTextFocus()
        }
    }

    private func clickHitsEditableText(_ event: NSEvent) -> Bool {
        guard let window = event.window else { return false }
        let location = event.locationInWindow

        let root = window.contentView?.superview ?? window.contentView
        guard let root else { return false }
        if ancestorIsEditableText(root.hitTest(location)) {
            return true
        }
        return viewTreeContainsEditableField(root, containing: location)
    }

    private func ancestorIsEditableText(_ view: NSView?) -> Bool {
        var current = view
        while let view = current {
            if PlaybackKeyboardRouting.isEditableTextSurface(view) {
                return true
            }
            if view.accessibilityIdentifier() == Self.urlFieldAccessibilityID {
                return true
            }
            if PlaybackKeyboardRouting.isTextInputClassName(view.className) {
                return true
            }
            current = view.superview
        }
        return false
    }

    private func viewTreeContainsEditableField(_ view: NSView, containing location: NSPoint) -> Bool {
        if PlaybackKeyboardRouting.isEditableTextSurface(view),
           view.convert(view.bounds, to: nil).contains(location) {
            return true
        }
        for subview in view.subviews {
            if viewTreeContainsEditableField(subview, containing: location) {
                return true
            }
        }
        return false
    }

    private func clearTextFocus(in window: NSWindow, reason: TextFocusResignReason = .other) {
        allowTextFocus = false
        swiftUITextFieldFocused = false
        // 先广播原因，再卸第一响应者，避免标题编辑的失焦回调抢在 Esc 取消之前把草稿存掉。
        Self.postResignNotification(window: window, reason: reason)
        window.makeFirstResponder(nil)
    }
}
