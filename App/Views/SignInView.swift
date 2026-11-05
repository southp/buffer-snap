import SwiftUI

/// The signed-out screen: the app's name, a tagline, and the button that starts sign-in.
struct SignInView: View {
    /// Called when the user taps the authenticate button.
    let onSignIn: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bolt.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("BufferSnap")
                .font(.largeTitle.bold())
            Text("Capture inspiration in one touch.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button(action: onSignIn) {
                Text("Authenticate using your Buffer account")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
}
