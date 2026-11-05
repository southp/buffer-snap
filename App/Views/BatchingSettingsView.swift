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
        Form {
            Section {
                Picker("Combine captures", selection: Binding(get: { window }, set: onChoose)) {
                    ForEach(options, id: \.self) { option in
                        Text(label(for: option)).tag(option)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Combine captures made within")
                    .textCase(nil)
            } footer: {
                Text(
                    """
                    Captures this close together become one idea in Buffer. It's sent once this much time has passed \
                    since the last one, or the next time you open the app if iOS doesn't wake it before then. Off \
                    sends each capture by itself right away.
                    """
                )
            }
        }
        .navigationTitle("Batching")
    }

    private func label(for option: TimeInterval) -> String {
        guard option > BatchWindow.off else {
            return String(localized: "Off")
        }
        return Duration.seconds(option).formatted(.units(allowed: [.minutes], width: .wide).locale(locale))
    }
}
