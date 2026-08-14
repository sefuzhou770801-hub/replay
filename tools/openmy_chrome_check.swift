import Foundation

@main
struct OpenMyChromeCheck {
    static func main() {
        precondition(OpenMyChrome.canvasHex == 0x0D0D0D, "画布必须是 openmy #0D0D0D")
        precondition(OpenMyChrome.raiseHex == 0x1E1E1E, "悬浮层必须是 openmy #1E1E1E")
        precondition(OpenMyChrome.hairHex == 0x222222, "细线必须是 openmy #222222")
        precondition(OpenMyChrome.fieldBorderHex == 0x2A2A2A)
        precondition(OpenMyChrome.inkHex == 0xECECEC, "正文必须是 openmy #ECECEC")
        precondition(OpenMyChrome.mutedHex == 0x9B9B9B)
        precondition(OpenMyChrome.faintHex == 0x666666)
        precondition(OpenMyChrome.successHex == 0x41B98C)
        precondition(OpenMyChrome.warningHex == 0xD9A44C)
        precondition(OpenMyChrome.recHex == 0xE0607E)
        precondition(OpenMyChrome.radiusSm == 8)
        precondition(OpenMyChrome.radiusMd == 10)
        precondition(OpenMyChrome.radiusLg == 12)
        precondition(OpenMyChrome.radiusXl == 16)
        print("openmy_chrome_check=passed")
    }
}
