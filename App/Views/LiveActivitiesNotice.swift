import SwiftUI

extension View {
    /// Says why a press of Dictate an Idea didn't listen, and offers the setting that fixes it.
    func liveActivitiesNotice(isPresented: Binding<Bool>) -> some View {
        modifier(LiveActivitiesNotice(isPresented: isPresented))
    }
}

private struct LiveActivitiesNotice: ViewModifier {
    @Binding var isPresented: Bool
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content.alert("Turn On Live Activities", isPresented: $isPresented) {
            Button("Open Settings") {
                if let settings = URL(string: UIApplication.openSettingsURLString) {
                    openURL(settings)
                }
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text(
                """
                BufSnap shows what it hears and a Stop button in a Live Activity, so it can't listen while \
                they're off.
                """
            )
        }
    }
}
