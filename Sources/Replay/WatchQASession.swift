import AppKit
import AVFoundation
import SwiftUI

struct WatchQAClientError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum WatchQAFrameCapture {
    static let missingHint = "没拿到当前画面，按回车重试"

    static func jpegBase64(
        asset: AVAsset,
        time: CMTime,
        maxWidth: Double = WatchQARequestBuilder.frameMaxWidth
    ) -> String? {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        generator.maximumSize = CGSize(width: maxWidth, height: maxWidth)
        guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else {
            return nil
        }
        let representation = NSBitmapImageRep(cgImage: cgImage)
        guard let data = representation.representation(
            using: .jpeg,
            properties: [.compressionFactor: 0.82]
        ) else {
            return nil
        }
        return data.base64EncodedString()
    }
}

enum WatchQAClient {
    static func stream(
        input: WatchQARequestInput,
        apiKey: String,
        session: URLSession = .shared,
        onDelta: @escaping (String) -> Void
    ) async throws {
        var request = URLRequest(url: WatchQARequestBuilder.endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(WatchQARequestBuilder.anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        guard let httpBody = WatchQARequestBuilder.jsonData(from: input) else {
            throw WatchQAClientError(message: WatchQAFrameCapture.missingHint)
        }
        request.httpBody = httpBody

        let (bytes, response) = try await session.bytes(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            var body = ""
            for try await line in bytes.lines {
                body += line
                if body.count > 2_000 { break }
            }
            throw WatchQAClientError(message: httpErrorMessage(status: http.statusCode, body: body))
        }

        for try await line in bytes.lines {
            try Task.checkCancellation()
            if let delta = WatchQASSEParser.textDelta(fromLine: line), !delta.isEmpty {
                await MainActor.run {
                    onDelta(delta)
                }
            }
        }
    }

    private static func httpErrorMessage(status: Int, body: String) -> String {
        if let data = body.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = object["error"] as? [String: Any],
               let message = error["message"] as? String,
               !message.isEmpty {
                return message
            }
            if let message = object["message"] as? String, !message.isEmpty {
                return message
            }
        }
        return "问答请求失败（\(status)）"
    }
}

@MainActor
final class WatchQASession: ObservableObject {
    @Published var isPresented = false
    @Published var question = ""
    @Published var answer = ""
    @Published var statusMessage: String?
    @Published var isStreaming = false

    private var streamTask: Task<Void, Never>?

    func present() {
        guard !isPresented else { return }
        isPresented = true
        question = ""
        answer = ""
        isStreaming = false
        streamTask?.cancel()
        streamTask = nil
        statusMessage = WatchQAAPIKey.resolve() == nil ? WatchQAAPIKey.missingKeyHint : nil
    }

    @discardableResult
    func dismiss(resume: Bool = true) -> Bool {
        guard isPresented else { return false }
        cancel()
        isPresented = false
        question = ""
        answer = ""
        statusMessage = nil
        if resume {
            PlaybackCommandCenter.shared.play()
        }
        return true
    }

    func cancel() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
    }

    func submit(
        item: WatchItem,
        snapshot: PlaybackSnapshot,
        subtitleTrack: VideoSubtitleTrack?,
        persistURL: URL? = nil,
        onPersisted: ((WatchQAEntry) -> Void)? = nil
    ) {
        guard let apiKey = WatchQAAPIKey.resolve() else {
            statusMessage = WatchQAAPIKey.missingKeyHint
            return
        }
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming else { return }

        let currentTime = snapshot.currentTime
        let askedAt = Date()
        let title = item.title
        let author = item.author
        let chapters = item.availableChapters
        let cues = subtitleTrack?.cues(
            around: currentTime,
            window: WatchQARequestBuilder.subtitleWindow
        ) ?? []
        let frameSource: (asset: AVAsset, time: CMTime)? = {
            guard let player = PlaybackCommandCenter.shared.activeRoutePlayer,
                  let asset = player.currentItem?.asset else { return nil }
            return (asset, player.currentTime())
        }()

        answer = ""
        statusMessage = nil
        isStreaming = true
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            let jpeg = await Task.detached {
                guard let frameSource else { return nil as String? }
                return WatchQAFrameCapture.jpegBase64(asset: frameSource.asset, time: frameSource.time)
            }.value
            guard !Task.isCancelled else { return }
            guard let jpeg, !jpeg.isEmpty else {
                self?.statusMessage = WatchQAFrameCapture.missingHint
                self?.isStreaming = false
                return
            }
            let input = WatchQARequestInput(
                title: title,
                author: author,
                chapterTitle: WatchQAChapter.title(at: currentTime, in: chapters),
                currentTime: currentTime,
                cues: cues,
                jpegBase64: jpeg,
                question: trimmed
            )
            do {
                try await WatchQAClient.stream(input: input, apiKey: apiKey) { delta in
                    self?.answer += delta
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self?.statusMessage = error.localizedDescription
                self?.isStreaming = false
                return
            }
            self?.isStreaming = false
            let completedAnswer = self?.answer ?? ""
            guard !completedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let persistURL else { return }
            let entry = WatchQAEntry(
                id: UUID(),
                time: currentTime,
                question: trimmed,
                answer: completedAnswer,
                askedAt: askedAt,
                model: WatchQARequestBuilder.model
            )
            await Task.detached {
                WatchQAStore.append(entry, to: persistURL)
            }.value
            onPersisted?(entry)
        }
    }
}

struct WatchQAOverlay: View {
    @ObservedObject var session: WatchQASession
    var isQuestionFieldFocused: FocusState<Bool>.Binding
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let status = session.statusMessage {
                Text(status)
                    .font(.callout)
                    .foregroundStyle(OpenMyChrome.ink.opacity(0.86))
                    .textSelection(.enabled)
            }

            if session.isStreaming || !session.answer.isEmpty {
                ScrollView {
                    Text(session.answer.isEmpty ? "正在回答…" : session.answer)
                        .font(.body)
                        .foregroundStyle(OpenMyChrome.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 220)
            }

            HStack(spacing: 8) {
                TextField("问画面或字幕…", text: $session.question)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .foregroundStyle(OpenMyChrome.ink)
                    .focused(isQuestionFieldFocused)
                    .onSubmit(onSubmit)

                Button(action: onSubmit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(OpenMyChrome.ink.opacity(canSubmit ? 1 : 0.35))
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
                .help("发送（回车）")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                OpenMyChrome.raise,
                in: RoundedRectangle(cornerRadius: OpenMyChrome.radiusLg, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: OpenMyChrome.radiusLg, style: .continuous)
                    .strokeBorder(OpenMyChrome.fieldBorder)
            }
        }
        .padding(14)
        .frame(maxWidth: 640)
        .background(
            OpenMyChrome.canvas.opacity(0.94),
            in: RoundedRectangle(cornerRadius: OpenMyChrome.radiusXl, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: OpenMyChrome.radiusXl, style: .continuous)
                .strokeBorder(OpenMyChrome.hair)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    private var canSubmit: Bool {
        !session.isStreaming
            && !session.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
