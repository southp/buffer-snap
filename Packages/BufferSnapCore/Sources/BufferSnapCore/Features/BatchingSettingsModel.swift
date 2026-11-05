import Foundation
import Observation

/// The setting for how long a batch waits, and changing it.
@Observable
@MainActor
public final class BatchingSettingsModel {
    public private(set) var window: TimeInterval

    private let setting: any BatchWindowSetting
    private let submissions: SubmissionQueue

    public init(setting: any BatchWindowSetting, submissions: SubmissionQueue) {
        self.setting = setting
        self.submissions = submissions
        window = setting.window
    }

    /// Changes the setting. It applies at once to whatever is still open:
    /// `docs/decisions/45-changing-the-window.md`.
    public func choose(_ window: TimeInterval) async {
        setting.setWindow(window)
        self.window = setting.window
        await submissions.replan()
    }
}
