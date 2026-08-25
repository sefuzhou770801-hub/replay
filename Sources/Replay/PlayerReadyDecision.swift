import Foundation

enum PlayerReadyDecision {
    enum LoadSignal: Equatable {
        case none
        case load
        case unload
    }

    static func isPlayable(state: DownloadState, localFileExists: Bool) -> Bool {
        state == .ready && localFileExists
    }

    static func loadSignal(previousPlayable: Bool, currentPlayable: Bool) -> LoadSignal {
        switch (previousPlayable, currentPlayable) {
        case (false, true):
            return .load
        case (true, false):
            return .unload
        default:
            return .none
        }
    }
}
