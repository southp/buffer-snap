import SwiftUI

extension View {
    /// A Paper & Ink screen: paper behind the list, ink controls, and the title drawn by `ScreenTitle` in the list
    /// rather than by the navigation bar, which can't set it in Caveat and still grow it with Dynamic Type. The title
    /// stays set, for the back button and VoiceOver.
    func paperInkScreen(title: LocalizedStringKey) -> some View {
        self
            .listStyle(.grouped)
            .listSectionSpacing(14)
            .environment(\.defaultMinListHeaderHeight, 0)
            // A grouped list leaves room above its first section, which would push the title away from the toolbar.
            .contentMargins(.top, 0, for: .scrollContent)
            .paperBackground()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(removing: .title)
            .toolbarBackground(Theme.paper, for: .navigationBar)
    }
}

/// A screen's title, in Caveat, as the first row of its list.
struct ScreenTitle: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caveat(.largeTitle))
            .foregroundStyle(Theme.ink)
            .accessibilityAddTraits(.isHeader)
            .listRowInsets(EdgeInsets(top: 0, leading: Theme.cardMargin + 4, bottom: 0, trailing: Theme.cardMargin))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

/// A toolbar item drawn as a Paper & Ink chip. From iOS 26, the system puts its own glass behind toolbar items, which
/// would sit around the chip's outline, so this turns it off.
struct ChipToolbarItem<Content: View>: ToolbarContent {
    let placement: ToolbarItemPlacement
    @ViewBuilder let content: () -> Content

    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: placement, content: content)
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: placement, content: content)
        }
    }
}

extension View {
    /// What's above a section of a Paper & Ink list, lined up with the cards' content.
    func paperInkSectionHeader() -> some View {
        self
            .textCase(nil)
            .listRowInsets(
                EdgeInsets(
                    top: 6, leading: Theme.cardMargin + 6, bottom: 8, trailing: Theme.cardMargin + 6
                )
            )
    }
}
