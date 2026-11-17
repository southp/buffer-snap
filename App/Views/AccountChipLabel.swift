import BufferSnapCore
import SwiftUI
import UIKit

/// The toolbar chip's face: the signed-in account's profile picture in the chip's circle, or its initials while there's
/// no picture (before it's downloaded, if it couldn't be, or if the account has none), or the `person` glyph while
/// there's no name either. VoiceOver reads "Account" and the name, never the initials letter by letter.
struct AccountChipLabel: View {
    /// Who's signed in, or `nil` while nobody is or Buffer hasn't said.
    let account: BufferAccount?
    /// The account's picture as image bytes, or `nil` for initials. Bytes UIKit can't draw count as none.
    let avatarImage: Data?

    var body: some View {
        if let picture = avatarImage.flatMap(UIImage.init(data:)) {
            // Fills the chip's frame, and the chip's own outline is drawn again on top, so the picture sits inside the
            // same ink ring as the initials.
            Color.clear
                .overlay {
                    Image(uiImage: picture)
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFill()
                }
                .clipShape(Circle())
                .overlay {
                    Circle().strokeBorder(Theme.ink, lineWidth: Theme.borderWidth)
                }
                .accessibilityElement()
                .accessibilityLabel(accessibilityLabel)
        } else if let initials = account?.initials {
            Text(verbatim: initials)
                // Two wide letters, such as "MW", still fit the circle.
                .font(.inter(.subheadline, weight: .bold))
                .accessibilityLabel(accessibilityLabel)
        } else {
            Label("Account", systemImage: "person")
                .labelStyle(.iconOnly)
        }
    }

    private var accessibilityLabel: Text {
        if let name = account?.displayName {
            return Text("Account: \(name)")
        }
        return Text("Account")
    }
}
