import BufferSnapCore
import SwiftUI

extension Appearance {
    /// The color scheme the window prefers: `nil` for System, which leaves it to iOS.
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}
