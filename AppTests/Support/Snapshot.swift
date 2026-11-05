import SnapshotTesting
import SwiftUI
import Testing
import UIKit

/// Asserts that `view`, laid out as a full screen, matches its reference PNG at
/// `AppTests/__Snapshots__/<test file>/<test name>.<name>.png`.
///
/// Every snapshot test goes through this helper, so they all share one configuration:
/// - the screen of the pinned `SIM_DEVICE` (iPhone 16, portrait), in light mode;
/// - an en_US locale and a Gregorian calendar in GMT, so dates render the same on every machine. The test host's own
///   language is pinned too, by the scheme's test arguments in `project.yml`, since text layout can follow it;
/// - a perceptual precision of 0.98, which absorbs antialiasing noise but not visible changes;
/// - record mode only when `SNAPSHOT_RECORD=1` (`just snapshots-record`). Otherwise a missing
///   reference fails the test instead of being recorded silently.
///
/// On a mismatch, the failure names the reference PNG and the PNG that was just rendered.
@MainActor
func assertScreenSnapshot(
    of view: some View,
    named name: String,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line,
    column: UInt = #column
) {
    let isRecording = ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] == "1"
    let pinnedView =
        view
        .environment(\.locale, ScreenSnapshot.locale)
        .environment(\.timeZone, ScreenSnapshot.timeZone)
        .environment(\.calendar, ScreenSnapshot.calendar)
    let failure = withSnapshotTesting(record: isRecording ? .all : .never, diffTool: .referenceAndActual) {
        verifySnapshot(
            of: pinnedView,
            as: .image(
                perceptualPrecision: ScreenSnapshot.perceptualPrecision,
                layout: .device(config: ScreenSnapshot.config),
                traits: ScreenSnapshot.traits
            ),
            named: name,
            fileID: fileID,
            file: filePath,
            testName: testName,
            line: line,
            column: column
        )
    }
    guard let failure else {
        return
    }
    // In record mode the library reports every write as a failure. Writing is the point of
    // `just snapshots-record`, so log it and keep the test green; any other message is a real failure.
    if isRecording && failure.hasPrefix(ScreenSnapshot.recordedMessagePrefix) {
        print(failure)
        return
    }
    Issue.record(
        SnapshotFailure(failure),
        sourceLocation: SourceLocation(
            fileID: String(describing: fileID),
            filePath: String(describing: filePath),
            line: Int(line),
            column: Int(column)
        )
    )
}

/// A snapshot failure whose message fits on one line. `just test` pipes through xcbeautify, which
/// keeps an issue's first line but drops the detail lines Swift Testing prints below it, and the
/// first line is where the PNG paths have to be.
private struct SnapshotFailure: Error, CustomStringConvertible {
    let description: String

    init(_ message: String) {
        description = message.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")
    }
}

/// The shared snapshot configuration. Change it here, never per test.
@MainActor
private enum ScreenSnapshot {
    static let perceptualPrecision: Float = 0.98

    /// How swift-snapshot-testing starts the message when record mode writes a snapshot.
    static let recordedMessagePrefix = "Record mode is on."

    /// Dates and number formats don't follow the Mac's or the simulator's settings.
    static let locale = Locale(identifier: "en_US")
    static let timeZone = TimeZone.gmt
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.timeZone = timeZone
        return calendar
    }()

    /// The pinned simulator's display, light mode.
    static let traits = UITraitCollection { traits in
        traits.userInterfaceIdiom = .phone
        traits.userInterfaceStyle = .light
        traits.displayScale = 3
        traits.horizontalSizeClass = .compact
        traits.verticalSizeClass = .regular
        traits.layoutDirection = .leftToRight
        traits.preferredContentSizeCategory = .large
    }

    /// iPhone 16 in portrait: 393 × 852 points, with the Dynamic Island and home indicator insets.
    static let config = ViewImageConfig(
        safeArea: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0),
        size: CGSize(width: 393, height: 852),
        traits: traits
    )
}

extension SnapshotTestingConfiguration.DiffTool {
    /// Names both PNGs by path, so whoever reads the failure (often Claude) can open them and compare.
    fileprivate static let referenceAndActual = Self { reference, actual in
        """
        Reference PNG: \(reference)
        Actual PNG: \(actual)
        Read both to see what changed. Only if the change is intended, run `just snapshots-record`.
        """
    }
}
