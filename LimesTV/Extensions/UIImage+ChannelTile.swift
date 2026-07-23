//
//  UIImage+ChannelTile.swift
//  LimesTV
//
//  Renders channel logos onto a uniform rounded tile so lists and grids show
//  them at a consistent footprint regardless of each logo's shape. The tile
//  background adapts to the logo's brightness so light/white logos stay visible.
//  Shared by the CarPlay list and the phone channel grid.
//

import UIKit

extension UIImage {
    /// A uniform, rounded tile with the logo scaled to fit and centered. The
    /// background is white for dark/colored logos and dark for light/white ones,
    /// so a logo never disappears into its tile.
    nonisolated func channelTile(size: CGSize = CGSize(width: 88, height: 88)) -> UIImage {
        let isLightLogo = (averageLuminance ?? 0) > 0.6
        let tileColor: UIColor = isLightLogo ? UIColor(white: 0.13, alpha: 1) : .white

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            let rect = CGRect(origin: .zero, size: size)

            // Uniform rounded tile so every item has the same visual footprint.
            let tile = UIBezierPath(roundedRect: rect, cornerRadius: size.width * 0.2)
            tileColor.setFill()
            tile.fill()

            guard self.size.width > 0, self.size.height > 0 else { return }

            // Logo centered inside a constant inset (aspect-fit).
            let box = rect.insetBy(dx: size.width * 0.12, dy: size.height * 0.12)
            let scale = min(box.width / self.size.width, box.height / self.size.height)
            let scaled = CGSize(width: self.size.width * scale, height: self.size.height * scale)
            let origin = CGPoint(x: box.midX - scaled.width / 2, y: box.midY - scaled.height / 2)
            self.draw(in: CGRect(origin: origin, size: scaled))
        }
    }

    /// Average perceived brightness of the logo's opaque pixels (0 = dark,
    /// 1 = white), or `nil` if it can't be measured.
    nonisolated private var averageLuminance: CGFloat? {
        guard let cgImage else { return nil }

        let side = 16
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixels,
            width: side, height: side,
            bitsPerComponent: 8, bytesPerRow: side * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))

        var total: CGFloat = 0
        var count: CGFloat = 0
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = CGFloat(pixels[i + 3]) / 255
            guard alpha > 0.1 else { continue }
            // Un-premultiply to recover the true colour.
            let r = CGFloat(pixels[i]) / 255 / alpha
            let g = CGFloat(pixels[i + 1]) / 255 / alpha
            let b = CGFloat(pixels[i + 2]) / 255 / alpha
            total += 0.299 * r + 0.587 * g + 0.114 * b
            count += 1
        }
        guard count > 0 else { return nil }
        return total / count
    }
}
