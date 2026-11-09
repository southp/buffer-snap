import SwiftUI

/// Clear Submitted, which asks first. The confirmation is attached here so it points at the button, and whether it's
/// showing is the only state: the list above it stays stateless.
struct ClearSubmittedButton: View {
    /// How many ideas would go, as the confirmation says.
    let ideaCount: Int
    /// Called once the user has confirmed.
    let onClear: () -> Void

    @State private var isConfirming = false

    private var confirmation: ClearSubmittedConfirmation {
        ClearSubmittedConfirmation(ideaCount: ideaCount)
    }

    var body: some View {
        Button("Clear Submitted") {
            isConfirming = true
        }
        .confirmationDialog(confirmation.title, isPresented: $isConfirming, titleVisibility: .visible) {
            Button("Clear", role: .destructive, action: onClear)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(confirmation.message)
        }
    }
}

/// What Clear Submitted asks before it removes anything, for `ideaCount` ideas.
struct ClearSubmittedConfirmation: Equatable {
    let title: String
    let message: String

    init(ideaCount: Int) {
        if ideaCount == 1 {
            title = "Clear 1 submitted idea?"
            message = "It stays in Buffer, and is only removed from this iPhone."
        } else {
            title = "Clear \(ideaCount) submitted ideas?"
            message = "They stay in Buffer, and are only removed from this iPhone."
        }
    }
}
