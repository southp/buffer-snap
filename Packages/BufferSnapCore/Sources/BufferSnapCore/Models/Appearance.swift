import Foundation

/// How the app looks: following iOS, or always light or always dark. People choose it under the account menu's
/// Appearance, and it's kept on this iPhone, under `storageKey` in the app's standard `UserDefaults`
/// (`docs/decisions/144-appearance-setting.md`). It only changes the app: iOS draws Dictate an Idea, the widget and the
/// Live Activity with its own appearance.
///
/// The raw values are what's stored, so they never change.
public enum Appearance: String, CaseIterable, Hashable, Identifiable, Sendable {
    /// Follows iOS, as the app always did before there was a choice.
    case system
    case light
    case dark

    /// The `UserDefaults` key the choice is stored under.
    public static let storageKey = "appearance"

    /// The stored choice, or `.system` when nothing is stored or what's stored isn't a choice this version knows.
    public init(storedValue: String?) {
        self = storedValue.flatMap(Appearance.init(rawValue:)) ?? .system
    }

    public var id: Self {
        self
    }

    /// The choice's name, as the Appearance menu shows it.
    public var title: LocalizedStringResource {
        switch self {
        case .system:
            "System"
        case .light:
            "Light"
        case .dark:
            "Dark"
        }
    }

    /// The SF Symbol beside the choice's name.
    public var symbolName: String {
        switch self {
        case .system:
            "circle.lefthalf.filled"
        case .light:
            "sun.max"
        case .dark:
            "moon"
        }
    }
}
