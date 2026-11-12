import SwiftUI
import Testing
import UIKit

@testable import BufferSnap

/// Caveat's letters reach past the text's frame, and the title has to draw them whole (#97). A snapshot alone didn't
/// catch the clipping, because the clipped rendering was the reference image.
@MainActor
struct ScreenTitleTests {
    /// The last "s" of "Captures" draws past the text's trailing edge instead of being cut off there.
    @Test(arguments: [DynamicTypeSize.large, .xxxLarge])
    func theTitleDrawsItsLastLetterWhole(size: DynamicTypeSize) throws {
        let title = ScreenTitle("Captures").dynamicTypeSize(size)
        let textWidth = try #require(render(title)).width
        // The same title with room on its right: any ink there is the overhang.
        let padded = try #require(render(title.padding(.trailing, 40)))
        #expect(padded.hasInk(inColumns: textWidth..<padded.width))
    }

    /// Renders `view` at its ideal size the way the screen draws it: as the layers of a hosting controller, where a
    /// `Text` clips at its frame. `ImageRenderer` doesn't clip, so it would pass without the fix.
    private func render(_ view: some View) -> CGImage? {
        let controller = UIHostingController(rootView: view.environment(\.colorScheme, .light))
        controller.view.backgroundColor = .clear
        let size = controller.sizeThatFits(in: UIView.layoutFittingExpandedSize)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.frame = window.bounds
        controller.view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            controller.view.layer.render(in: context.cgContext)
        }
        window.isHidden = true
        return image.cgImage
    }
}

extension CGImage {
    /// A quarter of full alpha: solid enough to be part of a letter, not just its antialiased edge.
    fileprivate static let inkAlpha: UInt8 = 64

    /// Whether any pixel in `columns` is drawn more than faintly. The threshold keeps a stray antialiasing pixel from
    /// counting as a letter.
    fileprivate func hasInk(inColumns columns: Range<Int>) -> Bool {
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard
                let context = CGContext(
                    data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else {
                return false
            }
            context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else {
            return false
        }
        for row in 0..<height {
            for pixelColumn in columns where pixels[row * bytesPerRow + pixelColumn * 4 + 3] > Self.inkAlpha {
                return true
            }
        }
        return false
    }
}
