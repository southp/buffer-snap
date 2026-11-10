import Foundation
import Testing
import UIKit

/// The Paper & Ink fonts reach every bundle that draws them, with their licenses. A font that's missing doesn't fail
/// anything else: SwiftUI quietly falls back to the system font.
@MainActor
struct ThemeTests {
    private static let fonts = ["Inter.ttf", "Caveat.ttf"]
    private static let licenses = ["Inter-OFL.txt", "Caveat-OFL.txt"]

    /// The test host is the app, so its process has registered the app's fonts.
    @Test(arguments: ["Inter", "Caveat"])
    func theAppRegistersTheFont(family: String) {
        #expect(!UIFont.fontNames(forFamilyName: family).isEmpty)
    }

    @Test func theAppBundlesTheFontsAndTheirLicenses() throws {
        try expectFontsAndLicenses(in: Bundle.main)
    }

    /// The widget extension is a process of its own, so it needs its own copy, listed in its own Info.plist.
    @Test func theWidgetBundlesTheFontsAndTheirLicenses() throws {
        let url = try #require(Bundle.main.builtInPlugInsURL?.appendingPathComponent("BufferSnapWidget.appex"))
        let widget = try #require(Bundle(url: url))
        try expectFontsAndLicenses(in: widget)
    }

    private func expectFontsAndLicenses(in bundle: Bundle) throws {
        let listed = try #require(bundle.object(forInfoDictionaryKey: "UIAppFonts") as? [String])
        #expect(Set(listed) == Set(Self.fonts))
        for file in Self.fonts + Self.licenses {
            #expect(bundle.url(forResource: file, withExtension: nil) != nil, "\(file) is missing")
        }
    }
}
