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
            SpikeViewFinder(session: session)
        }
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

        /// Writes to both the session folder and, to learn whether it's reachable, the App Group log.
        func note(_ event: String, detail: String) {
            let line = SpikeLog.line(event, surface: "camera-extension", detail: detail)
            let url = folder.appendingPathComponent("log.txt")
            let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            try? (existing + line).write(to: url, atomically: true, encoding: .utf8)
            SpikeLog.append("direct-from-extension: " + line)
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
