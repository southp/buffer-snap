import BufferSnapCore
import SwiftUI

/// How to put Dictate an Idea somewhere one press dictates: a picker of the places (`DictationPlacement`), then that
/// place's numbered steps, each with a still sketch. iOS has no API that adds it for an app, so this shows how
/// (`docs/decisions/98-show-how-to-add-the-control.md`).
///
/// Stateless: `AddDictationGuideScreen` holds which place is picked.
struct AddDictationGuideView: View {
    /// The place whose steps show.
    let placement: DictationPlacement
    /// Called when the user picks another place.
    let onChoose: (DictationPlacement) -> Void
    /// Called when the user is done.
    let onDone: () -> Void

    var body: some View {
        List {
            Section {
                ScreenTitle("Add Dictate an Idea")
                Text("Put it where one press starts dictating, without opening BufSnap.")
                    .font(.inter(.body))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .plainRow(top: 2, bottom: 12)
                PlacementPicker(selection: placement, onChoose: onChoose)
                    .plainRow(top: 0, bottom: 4, horizontal: Theme.cardMargin)
            }
            Section {
                let steps = placement.steps
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    GuideStepRow(number: index + 1, step: step)
                        .cardRow(CardPart(index: index, count: steps.count))
                }
            } header: {
                if let requirement = placement.requirement {
                    Pill(text: Text(requirement), fill: Theme.sun)
                        .paperInkSectionHeader()
                }
            }
        }
        .paperInkScreen(title: "Add Dictate an Idea")
        .toolbar {
            ChipToolbarItem(placement: .topBarTrailing) {
                Button("Done", action: onDone)
                    .buttonStyle(.paperInkChip)
            }
        }
    }
}

/// The guide's container: holds which place is picked, starting with Control Center, and closes the sheet.
struct AddDictationGuideScreen: View {
    @State private var placement = DictationPlacement.allCases[0]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            AddDictationGuideView(
                placement: placement,
                onChoose: { placement = $0 },
                onDone: { dismiss() }
            )
        }
        .tint(Theme.ink)
    }
}

/// The places, side by side, the picked one in Sun. VoiceOver gets a segmented picker of them instead.
private struct PlacementPicker: View {
    let selection: DictationPlacement
    let onChoose: (DictationPlacement) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(DictationPlacement.allCases) { placement in
                segment(placement)
            }
        }
        .padding(4)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            OutlinedShape(
                shape: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous),
                shadow: Theme.chipShadow
            )
        }
        // Past this, the names would break inside words. VoiceOver reads the picker below, at any size.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityRepresentation {
            Picker("Where to Add It", selection: Binding(get: { selection }, set: onChoose)) {
                ForEach(DictationPlacement.allCases) { placement in
                    Text(placement.title)
                        .tag(placement)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private func segment(_ placement: DictationPlacement) -> some View {
        let isSelected = placement == selection
        return Button {
            onChoose(placement)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbolName(placement))
                    .font(.inter(.body, weight: .semibold))
                Text(placement.title)
                    .font(.inter(.caption, weight: .bold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(isSelected ? Theme.onColor : Theme.ink)
            .padding(.vertical, 8)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if isSelected {
                    OutlinedShape(
                        shape: RoundedRectangle(cornerRadius: Theme.cornerRadius - 4, style: .continuous),
                        fill: Theme.sun,
                        lineWidth: Theme.pillBorderWidth
                    )
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func symbolName(_ placement: DictationPlacement) -> String {
        switch placement {
        case .controlCenter:
            "switch.2"
        case .lockScreen:
            "lock"
        case .actionButton:
            "button.horizontal.top.press"
        case .homeScreen:
            "apps.iphone"
        }
    }
}

/// One step: its sketch, with its number on the corner, and what to do. VoiceOver reads the number and the text.
private struct GuideStepRow: View {
    let number: Int
    let step: DictationPlacementStep

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack(alignment: .topLeading) {
                DictationStepSketch(sketch: step.sketch)
                    .padding([.top, .leading], 8)
                Badge(diameter: 26) {
                    Text(number, format: .number)
                        .font(.inter(.footnote, weight: .heavy))
                }
            }
            Text(step.text)
                .font(.inter(.body))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// A row of the guide drawn straight on the paper, lined up with the title.
    fileprivate func plainRow(top: CGFloat, bottom: CGFloat, horizontal: CGFloat = Theme.cardMargin + 4) -> some View {
        self
            .listRowInsets(EdgeInsets(top: top, leading: horizontal, bottom: bottom, trailing: horizontal))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
