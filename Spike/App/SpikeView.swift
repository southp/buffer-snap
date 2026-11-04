import AVFoundation
import AppIntents
import LockedCameraCapture
import SwiftUI
import UIKit

/// Throwaway (#10): prepares the test run and shows what it recorded.
struct SpikeView: View {
    @State private var log = ""
    @State private var status = ""
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            List {
                Section("Step 1") {
                    Button("Prepare (allow both prompts)") {
                        Task {
                            await prepare()
                        }
                    }
                    Text(status).font(.footnote)
                }
                Section("Step 3") {
                    Button("Copy results") {
                        UIPasteboard.general.string = log
                    }
                    Button("Clear results", role: .destructive) {
                        SpikeLog.clear()
                        refresh()
                    }
                }
                Section("Results (\(log.split(separator: "\n").count))") {
                    Text(log.isEmpty ? "Nothing yet" : log)
                        .font(.system(size: 10, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            .navigationTitle("Locked spike")
        }
        .onAppear {
            refresh()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                refresh()
            }
        }
    }

    private func prepare() async {
        SpikeLog.writeProbe()
        let microphone = await AVAudioApplication.requestRecordPermission()
        let camera = await AVCaptureDevice.requestAccess(for: .video)
        SpikeLog.write("prepared", surface: "app", detail: "mic=\(microphone) camera=\(camera)")
        refresh()
    }

    private func refresh() {
        SpikeLog.writeProbe()
        importCameraSessions()
        log = SpikeLog.read()
        status = "Lock probe: \(SpikeLog.lockState())"
    }

    /// Lists what the lock screen camera left behind, once per session.
    private func importCameraSessions() {
        let defaults = UserDefaults.standard
        var seen = Set(defaults.stringArray(forKey: "spike.seen") ?? [])
        for url in LockedCameraCaptureManager.shared.sessionContentURLs where !seen.contains(url.path) {
            seen.insert(url.path)
            let names = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
            var details = "files=\(names)"
            for name in names where name != "log.txt" {
                let path = url.appendingPathComponent(name).path
                let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int) ?? -1
                details += " \(name)=\(size)b"
            }
            SpikeLog.write("camera-imported", surface: "app", detail: details)
            if let text = try? String(contentsOf: url.appendingPathComponent("log.txt"), encoding: .utf8) {
                SpikeLog.append(text)
            }
        }
        defaults.set(Array(seen), forKey: "spike.seen")
    }
}

struct SpikeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SpikeTextIntent(),
            phrases: ["Snap an idea in \(.applicationName)"],
            shortTitle: "Spike text",
            systemImageName: "text.bubble"
        )
    }
}
