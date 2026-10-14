import Testing
import UIKit

@Suite("Home Screen mockup assets")
struct HomeScreenMockupAssetTests {
    private let assetNames = [
        "HomeScreenMockupCamera",
        "HomeScreenMockupHealth",
        "HomeScreenMockupMessages",
        "HomeScreenMockupNotes",
        "HomeScreenMockupPhone",
        "HomeScreenMockupPhotos",
        "HomeScreenMockupSafari",
        "HomeScreenMockupSettings",
        "HomeScreenMockupWidget",
    ]

    @Test("Visible asset bounds are centered in their canvases")
    func visibleBoundsAreCentered() throws {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)

            for assetName in assetNames {
                let image = try #require(UIImage(
                    named: assetName,
                    in: nil,
                    compatibleWith: traits
                ))
                let bounds = try #require(alphaBounds(of: image))
                let width = CGFloat(try #require(image.cgImage?.width))
                let height = CGFloat(try #require(image.cgImage?.height))
                let paddings = (
                    left: bounds.minX,
                    right: width - bounds.maxX,
                    top: bounds.minY,
                    bottom: height - bounds.maxY
                )

                #expect(
                    abs(paddings.left - paddings.right) <= 1,
                    "\(assetName) \(style) has asymmetric horizontal padding"
                )
                #expect(
                    abs(paddings.top - paddings.bottom) <= 1,
                    "\(assetName) \(style) has asymmetric vertical padding"
                )
            }
        }
    }

    private func alphaBounds(of image: UIImage) -> CGRect? {
        guard let source = image.cgImage else { return nil }

        let width = source.width
        let height = source.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1
        for y in 0..<height {
            for x in 0..<width where pixels[(y * width + x) * 4 + 3] > 0 {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX + 1,
            height: maxY - minY + 1
        )
    }
}
