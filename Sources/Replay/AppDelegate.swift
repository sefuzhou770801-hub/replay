import AppKit
import Foundation

@MainActor
final class URLInbox: ObservableObject {
    @Published private(set) var urls: [URL] = []
    @Published private(set) var clipboardValues: [String] = []

    func receive(_ incoming: [URL]) {
        urls.append(contentsOf: incoming)
    }

    func receiveClipboard(_ value: String) {
        clipboardValues.append(value)
    }

    func clear() {
        urls.removeAll()
    }

    func clearClipboard() {
        clipboardValues.removeAll()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let inbox = URLInbox()
    private var pasteMonitor: Any?
    private var mediaKeyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        SystemMediaController.shared.start()
        mediaKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .systemDefined) { event in
            guard let action = HardwareMediaKeyEventPolicy.action(
                subtype: Int(event.subtype.rawValue),
                data1: event.data1
            ), PlaybackCommandCenter.shared.hasActivePlayer else { return event }

            switch action {
            case .togglePlayback:
                PlaybackCommandCenter.shared.togglePlayback()
            case .skip(let seconds):
                PlaybackCommandCenter.shared.skip(by: seconds)
            }
            return nil
        }
        pasteMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let shortcutModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])

            // SwiftUI text fields use AppKit's shared field editor. Let it
            // receive navigation, editing, and paste keys before considering
            // any app-wide playback or URL shortcuts.
            if Self.isEditingText(in: event.window) {
                return event
            }

            if shortcutModifiers.isEmpty {
                if event.keyCode == 49, PlaybackCommandCenter.shared.hasActivePlayer {
                    if !event.isARepeat {
                        PlaybackCommandCenter.shared.togglePlayback()
                    }
                    return nil
                }

                if event.charactersIgnoringModifiers?.lowercased() == "f",
                   PlaybackCommandCenter.shared.hasActivePlayer {
                    if !event.isARepeat {
                        PlaybackCommandCenter.shared.toggleFullscreen()
                    }
                    return nil
                }

                if event.keyCode == 53,
                   PlaybackCommandCenter.shared.exitFullscreen() {
                    return nil
                }

                if event.keyCode == 126,
                   PlaybackCommandCenter.shared.adjustPlaybackRate(by: 0.1) {
                    return nil
                }
                if event.keyCode == 125,
                   PlaybackCommandCenter.shared.adjustPlaybackRate(by: -0.1) {
                    return nil
                }

                let skipAmount: Double?
                switch event.keyCode {
                case 123: skipAmount = -10
                case 124: skipAmount = 10
                default: skipAmount = nil
                }
                if let skipAmount, PlaybackCommandCenter.shared.skip(by: skipAmount) {
                    return nil
                }
            }

            guard shortcutModifiers == .command,
                  event.charactersIgnoringModifiers?.lowercased() == "v" else {
                return event
            }

            let pasteboard = NSPasteboard.general
            let urlType = NSPasteboard.PasteboardType("public.url")
            guard let value = pasteboard.string(forType: .string)
                    ?? pasteboard.string(forType: urlType) else {
                NSSound.beep()
                return nil
            }

            self?.inbox.receiveClipboard(value)
            return nil
        }
    }

    private static func isEditingText(in window: NSWindow?) -> Bool {
        guard let responder = window?.firstResponder else { return false }
        if let textView = responder as? NSTextView {
            return textView.isEditable
        }
        if let textField = responder as? NSTextField {
            return textField.isEditable
        }
        if let control = responder as? NSControl {
            return control.currentEditor() != nil
        }
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        SystemMediaController.shared.stop()
        if let pasteMonitor {
            NSEvent.removeMonitor(pasteMonitor)
        }
        if let mediaKeyMonitor {
            NSEvent.removeMonitor(mediaKeyMonitor)
        }
    }

    /// 与基线 WindowGroup 一致：关最后一窗后进程保留，等 reopen / 再次 open 重建。
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        inbox.receive(urls)
        Self.activateFocusOrReopenMainWindow(application)
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        inbox.receive(filenames.map { URL(fileURLWithPath: $0) })
        sender.reply(toOpenOrPrint: .success)
        Self.activateFocusOrReopenMainWindow(sender)
    }

    /// 有可见主窗口时只置前；无窗口时用捕获的 openWindow 重建，避免叠第二个。
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        sender.activate(ignoringOtherApps: true)
        if flag || Self.focusExistingMainWindow(in: sender) {
            return false
        }
        if Self.reopenMainWindowIfNeeded() {
            return false
        }
        // openWindow 尚未挂上时退回系统：允许 WindowGroup 建恰好一个。
        return true
    }

    private static func activateFocusOrReopenMainWindow(_ application: NSApplication) {
        application.activate(ignoringOtherApps: true)
        if focusExistingMainWindow(in: application) {
            return
        }
        _ = reopenMainWindowIfNeeded()
    }

    /// 只认主窗口：排除 LocalVideoPlayer 后台浮窗等 NSPanel。
    @discardableResult
    private static func focusExistingMainWindow(in application: NSApplication) -> Bool {
        let candidates = application.windows.filter { window in
            guard window.canBecomeKey || window.canBecomeMain else { return false }
            // 浮窗播放器是 NSPanel，不应当成主窗口置前目标。
            if window is NSPanel { return false }
            return true
        }
        guard let window = candidates.first(where: \.isVisible) ?? candidates.first else {
            return false
        }
        window.makeKeyAndOrderFront(nil)
        return true
    }

    @discardableResult
    private static func reopenMainWindowIfNeeded() -> Bool {
        guard let open = MainWindowOpener.open else { return false }
        open()
        return true
    }
}
