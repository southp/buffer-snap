import Foundation
import Observation

/// The idea being typed on the capture screen, and saving it as a capture.
@Observable
@MainActor
public final class CaptureModel {
    /// What the last save did, until the text changes.
    public enum SaveResult: Sendable, Equatable {
        case saved
        case failed
    }

    /// The most characters a capture can have. A longer draft stays editable but can't be saved.
    public static let characterLimit = 300

    /// The draft, as typed.
    public private(set) var text = ""
    public private(set) var saveResult: SaveResult?
    private var isSaving = false

    private let store: any CaptureStore
    private let onSaved: @MainActor () -> Void

    /// `onSaved` runs after each capture is stored, which is when it can start on its way to Buffer.
    public init(store: any CaptureStore, onSaved: @escaping @MainActor () -> Void = {}) {
        self.store = store
        self.onSaved = onSaved
    }

    /// How many characters would be saved: what a person sees as one character counts as one.
    public var characterCount: Int {
        trimmedText.count
    }

    public var isOverLimit: Bool {
        characterCount > Self.characterLimit
    }

    public var canSave: Bool {
        !trimmedText.isEmpty && !isOverLimit && !isSaving
    }

    /// Replaces the draft.
    public func update(text newText: String) {
        // SwiftUI can set a binding to the value it already has, which mustn't clear the result.
        guard newText != text else {
            return
        }
        text = newText
        saveResult = nil
    }

    /// Forgets the last save's result, so "Saved" doesn't greet the next idea when the app comes back later.
    public func clearSaveResult() {
        saveResult = nil
    }

    /// Saves the draft as a pending text capture and clears it. A failed save keeps the draft, so it can be retried.
    public func save() async {
        guard canSave else {
            return
        }
        isSaving = true
        defer {
            isSaving = false
        }
        let draft = text
        do {
            try await store.add(Capture(kind: .text, text: trimmedText))
            onSaved()
            // Anything typed while the write ran belongs to the next capture, so keep it.
            if text == draft {
                text = ""
                saveResult = .saved
            }
        } catch {
            saveResult = .failed
        }
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
