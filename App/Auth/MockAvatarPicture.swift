#if DEBUG
    import UIKit

    /// The mocked account's made-up profile picture, drawn here so screenshots never show a real person and the mocked
    /// app never asks the network for one: a sun over a hill, plainly not a photo.
    enum MockAvatarPicture {
        static let png: Data = {
            let size = CGSize(width: 120, height: 120)
            let image = UIGraphicsImageRenderer(size: size).image { context in
                UIColor(red: 0.53, green: 0.78, blue: 0.93, alpha: 1).setFill()
                context.fill(CGRect(origin: .zero, size: size))
                UIColor(red: 1, green: 0.8, blue: 0.25, alpha: 1).setFill()
                context.cgContext.fillEllipse(in: CGRect(x: 62, y: 18, width: 38, height: 38))
                UIColor(red: 0.35, green: 0.68, blue: 0.4, alpha: 1).setFill()
                context.cgContext.fillEllipse(in: CGRect(x: -40, y: 70, width: 200, height: 120))
            }
            return image.pngData() ?? Data()
        }()
    }
#endif
