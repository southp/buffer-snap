import BufferSnapCore
import SwiftUI

/// The top of the list while nobody is signed in: says plainly that the app is in offline mode, what that means for
/// the ideas, how the last sign-in went, and the way to sign in. Always shown then, so it isn't a screen to get past:
/// `docs/decisions/68-sign-in-from-the-list.md`.
struct SignInPromptRow: View {
    let prompt: AppModel.SignInPrompt
    /// Called when the user taps the authenticate button.
    let onSignIn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Badge {
                    Image(systemName: "iphone")
                        .font(.inter(.subheadline, weight: .bold))
                }
                .accessibilityHidden(true)
                Text("Offline mode")
                    .font(.inter(.headline, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
            Text(
                """
                Everything is stored locally on this iPhone. Ideas are only submitted to Buffer once you \
                authenticate your Buffer account.
                """
            )
            .font(.inter(.subheadline))
            .foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
            if let notice = prompt.notice {
                SignInNoticeLabel(notice: notice)
            }
            Button(action: onSignIn) {
                Text("Authenticate using your Buffer account")
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.paperInkPrimary)
            .disabled(prompt.isSigningIn)
            // Shown before the tap too: once open, Buffer's sign-in page covers this row. Buffer emails the link
            // when it doesn't recognize the sign-in, which the private sheet makes common (#56).
            Text("Buffer may email you a link to confirm it's you. Open it, then come back to BufSnap to finish.")
                .font(.inter(.footnote))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// What happened to the last sign-in. Closing the page was the user's own choice, so only that isn't shown as an error.
private struct SignInNoticeLabel: View {
    let notice: AppModel.SignInNotice

    var body: some View {
        Text(message)
            .font(.inter(.subheadline, weight: notice == .cancelled ? .regular : .semibold))
            .foregroundStyle(notice == .cancelled ? Theme.muted : Theme.tomatoText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var message: LocalizedStringKey {
        switch notice {
        case .cancelled:
            "Sign-in cancelled. Your ideas stay on this iPhone."
        case .denied:
            "Buffer access wasn't allowed. Your ideas stay on this iPhone."
        case .unreachable:
            "Couldn't reach Buffer. Check your connection and try again."
        case .failed:
            "Buffer couldn't finish signing you in. Try again."
        case .sessionEnded:
            "Buffer ended your session. Authenticate again to send your ideas."
        case .signOutFailed:
            "Couldn't remove your saved sign-in, so the app may sign back in when it reopens."
        }
    }
}
