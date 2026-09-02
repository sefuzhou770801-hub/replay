import Combine
import Foundation

@MainActor
final class DigestSession: ObservableObject {
    @Published var notes: [DigestNote] = []
    @Published var annotations: [DigestAnnotation] = []
    @Published var collapsedAnnotationIDs: Set<UUID> = []
    @Published var overview: DigestOverviewPayload?
    @Published var isGeneratingOverview = false
    @Published var overviewMessage: String?
    @Published var selectedText = ""
    @Published var selectedCueTime = 0.0
    @Published var selectedCueIndex: Int?
    @Published var explanation: String?
    @Published var explanationByCue: [Int: String] = [:]
    @Published var isExplaining = false
    @Published var explainingCueIndex: Int?
    @Published var explainMessage: String?
    @Published var explainMessageByCue: [Int: String] = [:]
    @Published var pendingDeletions: [UUID: Date] = [:]
    @Published var showsHighlightsOnly = false
    @Published var editingCommentNoteID: UUID?
    @Published var noteJustSaved = false
    @Published var explainNeedsRetry = false
    @Published var retryCueIndices: Set<Int> = []
    @Published var shouldAutoGenerateOverview = false

    var apiKeyDefaults: UserDefaults = .standard
    var apiKeyEnvironment: [String: String] = ProcessInfo.processInfo.environment
    var completeFn: DigestCompleteFn?

    private var itemID: UUID?
    private var folder: URL?
    private var explainTask: Task<Void, Never>?
    private var overviewTask: Task<Void, Never>?
    private var noteDeleteTask: Task<Void, Never>?
    private var noteSavedTask: Task<Void, Never>?

    var hasAPIKey: Bool {
        DigestAPIKey.resolve(
            provider: DigestProvider.resolve(defaults: apiKeyDefaults),
            defaults: apiKeyDefaults,
            environment: apiKeyEnvironment
        ) != nil
    }

    func load(itemID: UUID, folder: URL) {
        explainTask?.cancel()
        overviewTask?.cancel()
        self.itemID = itemID
        self.folder = folder
        notes = DigestNotesStore.load(itemID: itemID, folder: folder)
            .sorted { $0.createdAt > $1.createdAt }
        annotations = DigestAnnotationsStore.load(itemID: itemID, folder: folder)
        collapsedAnnotationIDs = []
        if let record = DigestOverviewStore.load(itemID: itemID, folder: folder) {
            overview = record.payload
            shouldAutoGenerateOverview = false
        } else {
            overview = nil
            shouldAutoGenerateOverview = DigestOverviewStore.fileExists(itemID: itemID, folder: folder)
        }
        isGeneratingOverview = false
        overviewMessage = nil
        pendingDeletions = [:]
        showsHighlightsOnly = false
        editingCommentNoteID = nil
        noteJustSaved = false
        explainNeedsRetry = false
        explanationByCue = [:]
        explainMessageByCue = [:]
        retryCueIndices = []
        explainingCueIndex = nil
        noteDeleteTask?.cancel()
        noteSavedTask?.cancel()
        clearSelection()
    }

    func clearSelection() {
        selectedText = ""
        selectedCueTime = 0
        selectedCueIndex = nil
        explanation = nil
        isExplaining = false
        explainMessage = nil
        explainNeedsRetry = false
        explainingCueIndex = nil
        explainTask?.cancel()
        explainTask = nil
    }

    var highlightCount: Int {
        DigestHighlight.visibleCount(notes: notes, pending: pendingDeletions)
    }

    func isHighlighted(_ cue: VideoSubtitleCue) -> Bool {
        note(for: cue) != nil
    }

    func note(for cue: VideoSubtitleCue) -> DigestNote? {
        DigestHighlightFilter.matchingVisibleNote(
            time: cue.startTime,
            text: cue.text,
            notes: notes,
            pending: pendingDeletions
        )
    }

    var latestPendingDeletionID: UUID? {
        pendingDeletions.max(by: { $0.value < $1.value })?.key
    }

    func toggleHighlightFilter() {
        showsHighlightsOnly.toggle()
    }

    func beginEditComment(noteID: UUID) {
        editingCommentNoteID = noteID
    }

    func updateComment(noteID: UUID, comment: String) {
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else { return }
        notes[index].comment = DigestNoteComment.normalized(comment)
        persistNotes()
        if editingCommentNoteID == noteID {
            editingCommentNoteID = nil
        }
    }

    func explanation(for index: Int) -> String? {
        explanationByCue[index]
    }

    func annotation(for cue: VideoSubtitleCue) -> DigestAnnotation? {
        DigestAnnotationAnchor.matching(time: cue.startTime, text: cue.text, in: annotations)
    }

    func isAnnotationCollapsed(_ id: UUID) -> Bool {
        DigestAnnotationCollapse.isCollapsed(id, in: collapsedAnnotationIDs)
    }

    func toggleAnnotationCollapsed(_ id: UUID) {
        collapsedAnnotationIDs = DigestAnnotationCollapse.toggling(id, in: collapsedAnnotationIDs)
    }

    func deleteAnnotation(_ id: UUID) {
        guard let removed = annotations.first(where: { $0.id == id }) else { return }
        annotations.removeAll { $0.id == id }
        collapsedAnnotationIDs.remove(id)
        if explanation == removed.explanation {
            explanation = nil
        }
        explanationByCue = explanationByCue.filter { $0.value != removed.explanation }
        persistAnnotations()
    }

    func recordAnnotation(time: Double, text: String, explanation: String, model: String) {
        let existing = DigestAnnotationAnchor.matching(time: time, text: text, in: annotations)
        let annotation = DigestAnnotation(
            id: existing?.id ?? UUID(),
            time: time,
            text: text,
            explanation: explanation,
            createdAt: Date(),
            model: model
        )
        annotations = DigestAnnotationUpsert.applying(annotation, to: annotations)
        if let existing {
            collapsedAnnotationIDs.remove(existing.id)
        }
        persistAnnotations()
    }

    func isExplainingCue(_ index: Int) -> Bool {
        isExplaining && explainingCueIndex == index
    }

    func needsRetry(_ index: Int) -> Bool {
        retryCueIndices.contains(index)
    }

    func explainMessage(for index: Int) -> String? {
        explainMessageByCue[index]
    }

    func selectText(_ text: String, cueIndex: Int, time: Double) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            if selectedCueIndex == cueIndex {
                clearSelection()
            }
            return
        }
        if selectedCueIndex != cueIndex || selectedText != trimmed {
            explanation = nil
            explainMessage = nil
            explainNeedsRetry = false
        }
        selectedText = trimmed
        selectedCueIndex = cueIndex
        selectedCueTime = time
    }

    @discardableResult
    func saveSelectedNote(cues: [VideoSubtitleCue] = []) -> DigestNote? {
        guard !noteJustSaved else { return nil }
        let noteCues = cues.map { DigestNoteSource(startTime: $0.startTime, text: $0.text) }
        let selected = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selected.isEmpty, let itemID, let folder else { return nil }
        let captured = DigestNoteCapture.sources(
            selected: selected,
            hintIndex: selectedCueIndex ?? 0,
            cues: noteCues
        )
        guard !captured.isEmpty else { return nil }
        var next = notes
        var last: DigestNote?
        let createdAt = Date()
        for source in captured.reversed() {
            let note = DigestNote(id: UUID(), time: source.startTime, text: source.text, createdAt: createdAt)
            next.insert(note, at: 0)
            last = note
        }
        do {
            try DigestNotesStore.save(next, itemID: itemID, folder: folder)
            notes = next
            noteJustSaved = true
            noteSavedTask?.cancel()
            noteSavedTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard !Task.isCancelled else { return }
                self?.noteJustSaved = false
            }
            return last
        } catch {
            return nil
        }
    }

    func requestDeleteNote(_ id: UUID) {
        guard notes.contains(where: { $0.id == id }) else { return }
        DigestNoteUndo.request(pending: &pendingDeletions, id: id)
        scheduleDeletionCommit()
    }

    func undoDeleteNote(_ id: UUID) {
        DigestNoteUndo.undo(pending: &pendingDeletions, id: id)
    }

    func commitExpiredDeletions(now: Date = Date()) {
        let expired = DigestNoteUndo.expiredIDs(pending: pendingDeletions, now: now)
        guard !expired.isEmpty else { return }
        notes.removeAll { expired.contains($0.id) }
        for id in expired {
            pendingDeletions.removeValue(forKey: id)
        }
        persistNotes()
    }

    private func persistNotes() {
        guard let itemID, let folder else { return }
        try? DigestNotesStore.save(notes, itemID: itemID, folder: folder)
    }

    private func persistAnnotations() {
        guard let itemID, let folder else { return }
        try? DigestAnnotationsStore.save(annotations, itemID: itemID, folder: folder)
    }

    private func scheduleDeletionCommit() {
        noteDeleteTask?.cancel()
        noteDeleteTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let session = self else { return }
                let now = Date()
                session.commitExpiredDeletions(now: now)
                guard let next = session.pendingDeletions.values.min() else { return }
                let wait = next.timeIntervalSince(now)
                if wait > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
                }
            }
        }
    }

    func generateOverview(
        title: String,
        author: String,
        duration: Double?,
        cues: [VideoSubtitleCue],
        chapters: [VideoChapter] = []
    ) {
        guard !isGeneratingOverview else { return }
        let provider = DigestProvider.resolve(defaults: apiKeyDefaults)
        guard let apiKey = DigestAPIKey.resolve(
            provider: provider,
            defaults: apiKeyDefaults,
            environment: apiKeyEnvironment
        ) else {
            overviewMessage = DigestCopy.missingKeyHint
            return
        }
        guard !cues.isEmpty else {
            overviewMessage = DigestCopy.noSubtitles
            return
        }
        guard let itemID, let folder else { return }

        let resolvedDuration = DigestOverviewPrompt.resolvedDuration(itemDuration: duration, cues: cues)
        let transcript = DigestOverviewPrompt.timestampedTranscript(from: cues)
        let skeletonBlock = DigestTOCComposer.skeletonBlock(from: chapters)
        let system = DigestOverviewPrompt.systemPrompt(
            duration: resolvedDuration,
            skeletonBlock: skeletonBlock
        )
        let user = DigestOverviewPrompt.userPrompt(
            title: title,
            author: author,
            duration: resolvedDuration,
            transcript: transcript,
            skeletonBlock: skeletonBlock
        )

        isGeneratingOverview = true
        overviewMessage = nil
        shouldAutoGenerateOverview = false
        overviewTask?.cancel()
        overviewTask = Task { [weak self] in
            guard let self else { return }
            do {
                let text = try await self.complete(
                    system: system,
                    user: user,
                    apiKey: apiKey,
                    maxTokens: DigestRequestBuilder.overviewMaxTokens,
                    provider: provider,
                    temperature: nil
                )
                guard !Task.isCancelled else { return }
                guard let parsed = DigestOverviewCodec.parse(text) else {
                    self.overviewMessage = DigestCopy.writeFailed
                    self.isGeneratingOverview = false
                    return
                }
                let payload = DigestTOCComposer.compose(
                    skeleton: chapters,
                    ai: parsed,
                    duration: resolvedDuration,
                    cues: cues
                )
                guard !payload.chapters.isEmpty else {
                    self.overviewMessage = DigestCopy.writeFailed
                    self.isGeneratingOverview = false
                    return
                }
                let record = DigestOverviewRecord(
                    payload: payload,
                    generatedAt: Date(),
                    model: provider.activeModel
                )
                try DigestOverviewStore.save(record, itemID: itemID, folder: folder)
                self.overview = payload
                self.isGeneratingOverview = false
                self.overviewMessage = nil
            } catch {
                guard !Task.isCancelled else { return }
                self.isGeneratingOverview = false
                self.overviewMessage = error.localizedDescription
            }
        }
    }

    func explainCue(index: Int, title: String, cues: [VideoSubtitleCue]) {
        guard cues.indices.contains(index) else { return }
        selectText(cues[index].text, cueIndex: index, time: cues[index].startTime)
        explainSelection(title: title, cues: cues)
    }

    @discardableResult
    func toggleHighlight(cue: VideoSubtitleCue) -> DigestHighlightToggle.Action {
        let action = DigestHighlightToggle.action(
            time: cue.startTime,
            text: cue.text,
            notes: notes,
            pending: pendingDeletions
        )
        switch action {
        case .requestDelete(let id):
            editingCommentNoteID = nil
            requestDeleteNote(id)
        case .undoDelete(let id):
            undoDeleteNote(id)
        case .add:
            guard let itemID, let folder else { return action }
            let captured = DigestNoteCapture.sources(
                selected: cue.text,
                hintIndex: 0,
                cues: [DigestNoteSource(startTime: cue.startTime, text: cue.text)]
            )
            guard let source = captured.first else { return action }
            let note = DigestNote(id: UUID(), time: source.startTime, text: source.text, createdAt: Date())
            notes.insert(note, at: 0)
            try? DigestNotesStore.save(notes, itemID: itemID, folder: folder)
            editingCommentNoteID = note.id
        }
        return action
    }

    func explainSelection(
        title: String,
        cues: [VideoSubtitleCue]
    ) {
        let selected = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selected.isEmpty else { return }
        let cueIndex = selectedCueIndex ?? 0
        let provider = DigestProvider.resolve(defaults: apiKeyDefaults)
        guard let apiKey = DigestAPIKey.resolve(
            provider: provider,
            defaults: apiKeyDefaults,
            environment: apiKeyEnvironment
        ) else {
            explanation = nil
            explanationByCue[cueIndex] = nil
            explainMessage = DigestCopy.missingKeyHint
            explainMessageByCue[cueIndex] = DigestCopy.missingKeyHint
            retryCueIndices.remove(cueIndex)
            explainNeedsRetry = false
            return
        }
        let passage = DigestExplainPrompt.passage(selected: selected, around: cueIndex, in: cues)
        let cueTime = cues.indices.contains(cueIndex) ? cues[cueIndex].startTime : selectedCueTime
        let cueText = cues.indices.contains(cueIndex) ? cues[cueIndex].text : selected
        isExplaining = true
        explainingCueIndex = cueIndex
        explainMessage = nil
        explainMessageByCue[cueIndex] = nil
        explanation = nil
        explanationByCue[cueIndex] = nil
        explainNeedsRetry = false
        retryCueIndices.remove(cueIndex)
        explainTask?.cancel()
        explainTask = Task { [weak self] in
            guard let self else { return }
            do {
                let text = try await self.complete(
                    system: DigestExplainPrompt.systemPrompt,
                    user: DigestExplainPrompt.userText(videoTitle: title, passage: passage),
                    apiKey: apiKey,
                    maxTokens: DigestExplainPrompt.maxTokens,
                    provider: provider,
                    temperature: DigestExplainPrompt.temperature
                )
                guard !Task.isCancelled else { return }
                self.isExplaining = false
                self.explainingCueIndex = nil
                let trimmedAnswer = text.trimmingCharacters(in: .whitespacesAndNewlines)
                switch DigestExplainQuality.verdict(selected: selected, explanation: trimmedAnswer) {
                case .ok:
                    self.explanation = nil
                    self.explanationByCue[cueIndex] = nil
                    self.recordAnnotation(
                        time: cueTime,
                        text: cueText,
                        explanation: trimmedAnswer,
                        model: provider.activeModel
                    )
                    self.explainNeedsRetry = false
                    self.retryCueIndices.remove(cueIndex)
                    self.explainMessage = nil
                    self.explainMessageByCue[cueIndex] = nil
                case .empty, .tooShort, .unrelated:
                    self.explanation = nil
                    self.explanationByCue[cueIndex] = nil
                    self.explainNeedsRetry = true
                    self.retryCueIndices.insert(cueIndex)
                    self.explainMessage = nil
                    self.explainMessageByCue[cueIndex] = nil
                }
            } catch {
                guard !Task.isCancelled else { return }
                self.isExplaining = false
                self.explainingCueIndex = nil
                self.explainMessage = error.localizedDescription
                self.explainMessageByCue[cueIndex] = error.localizedDescription
            }
        }
    }

    private func complete(
        system: String,
        user: String,
        apiKey: String,
        maxTokens: Int,
        provider: DigestProviderKind,
        temperature: Double?
    ) async throws -> String {
        if let completeFn {
            return try await completeFn(system, user, apiKey, maxTokens, provider, temperature)
        }
        return try await DigestAPIClient.complete(
            system: system,
            user: user,
            apiKey: apiKey,
            maxTokens: maxTokens,
            provider: provider,
            temperature: temperature
        )
    }
}
