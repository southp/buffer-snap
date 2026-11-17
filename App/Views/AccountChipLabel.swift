import BufferSnapCore
import SwiftUI

/// The toolbar chip's face: the signed-in account's initials, or the `person` glyph while there's no name to take them
/// from. VoiceOver reads "Account" and the name, never the initials letter by letter.
struct AccountChipLabel: View {
    /// Who's signed in, or `nil` while nobody is or Buffer hasn't said.
    let account: BufferAccount?

    var body: some View {
        if let initials = account?.initials, let name = account?.displayName {
            Text(verbatim: initials)
                // Two wide letters, such as "MW", still fit the circle.
                .font(.inter(.subheadline, weight: .bold))
                .accessibilityLabel(Text("Account: \(name)"))
        } else {
            Label("Account", systemImage: "person")
                .labelStyle(.iconOnly)
        }
    }
}
