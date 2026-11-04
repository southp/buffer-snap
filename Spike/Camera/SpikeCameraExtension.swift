import AVFoundation
import ExtensionKit
import Foundation
import LockedCameraCapture
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Throwaway (#10): the lock screen camera. It can only write inside its session folder, which the app reads later.
@main
struct SpikeCameraExtension: LockedCameraCaptureExtension {
    var body: some LockedCameraCaptureExtensionScene {
        LockedCameraCaptureUIScene { session in
            SpikeCaptureScreen(session: session)
        }
    }
}

/// Round 3: does the extension's own UI allow a keyboard and a microphone on a locked phone, over a live camera?
struct SpikeCaptureScreen: View {
    let session: LockedCameraCaptureSession

    @State private var text = ""
    @State private var status = "Tap the box and type"
    @State private var recorder: AVAudioRecorder?

    var body: some View {
        ZStack(alignment: .top) {
            SpikeViewFinder(session: session).ignoresSafeArea()
            VStack(spacing: 8) {
                TextField("Type an idea", text: $text)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Save text") {
                        saveText()
                    }
                    Button("Record 5s") {
                        record()
                    }
                }
                .buttonStyle(.borderedProminent)
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.white)
            }
            .padding()
            .padding(.top, 60)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
            SpikeSessionLog.note(in: session.sessionContentURL, "ext-keyboard-shown")
        }
    }

    private func saveText() {
        let url = session.sessionContentURL.appendingPathComponent("idea.txt")
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            SpikeSessionLog.note(in: session.sessionContentURL, "ext-text-saved", detail: "chars=\(text.count)")
            status = "Saved \(text.count) characters"
        } catch {
            SpikeSessionLog.note(in: session.sessionContentURL, "ext-text-error", detail: "\(error)")
            status = "Save failed"
        }
    }

    private func record() {
        let url = session.sessionContentURL.appendingPathComponent("audio.m4a")
        do {
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers])
            try audio.setActive(true)
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            let started = recorder.record()
            self.recorder = recorder
            SpikeSessionLog.note(in: session.sessionContentURL, "ext-record-start", detail: "record()=\(started)")
            status = started ? "Recording 5 seconds" : "Recording didn't start"
            Task {
                try? await Task.sleep(for: .seconds(5))
                finishRecording(at: url)
            }
        } catch {
            SpikeSessionLog.note(in: session.sessionContentURL, "ext-record-error", detail: "\(error)")
            status = "Recording failed"
        }
    }

    private func finishRecording(at url: URL) {
        let seconds = recorder?.currentTime ?? -1
        recorder?.stop()
        recorder = nil
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? -1
        let detail = "recorded=\(Int(seconds))s bytes=\(size)"
        SpikeSessionLog.note(in: session.sessionContentURL, "ext-record-done", detail: detail)
        status = "Recorded \(Int(seconds)) seconds"
    }
}

/// The extension can't reach the App Group, so its log lives in the session folder, which the app imports later.
enum SpikeSessionLog {
    @MainActor
    static func note(in folder: URL, _ event: String, detail: String = "") {
        let line = SpikeLog.line(event, surface: "camera-extension", detail: detail)
        let url = folder.appendingPathComponent("log.txt")
        let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        try? (existing + line).write(to: url, atomically: true, encoding: .utf8)
    }
}

struct SpikeViewFinder: UIViewControllerRepresentable {
    let session: LockedCameraCaptureSession

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        context.coordinator.note("camera-opened", detail: "group=\(SpikeLog.directory != nil)")
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = [UTType.image.identifier]
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let folder: URL

        init(session: LockedCameraCaptureSession) {
            folder = session.sessionContentURL
        }

        func note(_ event: String, detail: String) {
            SpikeSessionLog.note(in: folder, event, detail: detail)
        }

        nonisolated func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let data = (info[.originalImage] as? UIImage)?.jpegData(compressionQuality: 0.5)
            MainActor.assumeIsolated {
                let name = "photo-\(Int(Date.now.timeIntervalSince1970)).jpg"
                do {
                    try data?.write(to: folder.appendingPathComponent(name))
                    note("camera-saved", detail: "\(name) bytes=\(data?.count ?? -1)")
                } catch {
                    note("camera-save-error", detail: "\(error)")
                }
            }
        }
    }
}
