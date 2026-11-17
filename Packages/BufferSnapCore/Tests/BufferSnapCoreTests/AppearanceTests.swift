import BufferSnapCore
import Foundation
import Testing

/// The appearance choices the account menu offers, and how a stored one is read back.
struct AppearanceTests {
    /// System, Light and Dark, in the menu's order, each with its name and symbol.
    @Test func everyChoiceHasATitleAndASymbol() {
        #expect(Appearance.allCases == [.system, .light, .dark])
        #expect(Appearance.allCases.map { String(localized: $0.title) } == ["System", "Light", "Dark"])
        #expect(Appearance.allCases.map(\.symbolName) == ["circle.lefthalf.filled", "sun.max", "moon"])
    }

    /// The raw values and the key are what's stored on the iPhone, so changing one would forget everyone's choice.
    @Test func whatsStoredStaysTheSame() {
        #expect(Appearance.allCases.map(\.rawValue) == ["system", "light", "dark"])
        #expect(Appearance.storageKey == "appearance")
    }

    /// Each stored choice comes back as itself.
    @Test func aStoredChoiceIsReadBack() {
        for appearance in Appearance.allCases {
            #expect(Appearance(storedValue: appearance.rawValue) == appearance)
        }
    }

    /// Nothing stored, or a value this version doesn't know, follows iOS, as before there was a choice.
    @Test func anUnknownOrMissingValueFollowsTheSystem() {
        #expect(Appearance(storedValue: nil) == .system)
        #expect(Appearance(storedValue: "sepia") == .system)
        #expect(Appearance(storedValue: "") == .system)
        #expect(Appearance(storedValue: "Dark") == .system)
    }
}
