import BufferSnapCore
import SwiftUI

/// The signed-out screen: the app's name, a tagline, the button that starts sign-in, and what happened to the last try.
struct SignInView: View {
    /// What to tell the user about the last sign-in, or why they're back here.
    var notice: AppModel.SignInNotice?
    /// Whether a sign-in is under way, which turns the button off.
    var isSigningIn = false
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
            if let notice {
                SignInNoticeLabel(notice: notice)
            }
            Button(action: onSignIn) {
                Text("Authenticate using your Buffer account")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isSigningIn)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
}

/// What happened to the last sign-in. Closing the page was the user's own choice, so only that isn't shown as an error.
private struct SignInNoticeLabel: View {
    let notice: AppModel.SignInNotice

    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(notice == .cancelled ? AnyShapeStyle(.secondary) : AnyShapeStyle(.red))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var message: LocalizedStringKey {
        switch notice {
        case .cancelled:
            "Sign-in cancelled. BufferSnap needs your Buffer account to save ideas there."
        case .denied:
            "Buffer access wasn't allowed. BufferSnap needs it to save ideas to your account."
        case .unreachable:
            "Couldn't reach Buffer. Check your connection and try again."
        case .failed:
            "Buffer couldn't finish signing you in. Try again."
        case .sessionEnded:
            "Buffer ended your session. Sign in again to keep saving ideas."
        case .signOutFailed:
            "Couldn't remove your saved sign-in, so the app may sign back in when it reopens."
        }
    }
}
