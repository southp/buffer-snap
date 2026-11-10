import BufferSnapCore
import SwiftUI

/// Choosing how close together captures must be to become one idea.
///
/// Stateless: `BatchingSettingsScreen` feeds it from `BatchingSettingsModel`.
struct BatchingSettingsView: View {
    /// The current choice, in seconds.
    let window: TimeInterval
    /// What can be chosen, in seconds, in order.
    let options: [TimeInterval]
    /// Called when the user picks another one.
    let onChoose: (TimeInterval) -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        List {
            Section {
                ScreenTitle("Batching")
            }
            Section {
                // Rows rather than an inline Picker, whose rows can't take a card's background. The same choices,
                // each saying whether it's the one chosen.
                ForEach(Array(options.enumerated()), id: \.element) { index, option in
                    Button {
                        onChoose(option)
                    } label: {
                        HStack {
                            Text(label(for: option))
                                .font(.inter(.body))
                                .foregroundStyle(Theme.ink)
                            Spacer(minLength: 8)
                            Image(systemName: "checkmark")
                                .font(.inter(.body, weight: .bold))
                                .foregroundStyle(Theme.tomatoText)
                                .opacity(option == window ? 1 : 0)
                                .accessibilityHidden(true)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(option == window ? .isSelected : [])
                    .cardRow(CardPart(index: index, count: options.count))
                }
            } header: {
                Text("Combine captures made within")
                    .font(.inter(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.muted)
                    .paperInkSectionHeader()
            } footer: {
                Text(
                    """
                    Captures this close together become one idea in Buffer. It's sent once this much time has passed \
                    since the last one, or the next time you open the app if iOS doesn't wake it before then. Off \
                    sends each capture by itself right away.
                    """
                )
                .font(.inter(.footnote))
                .foregroundStyle(Theme.muted)
                .paperInkSectionHeader()
            }
        }
        .paperInkScreen(title: "Batching")
    }

    private func label(for option: TimeInterval) -> String {
        guard option > BatchWindow.off else {
            return String(localized: "Off")
        }
        return Duration.seconds(option).formatted(.units(allowed: [.minutes], width: .wide).locale(locale))
    }
}
