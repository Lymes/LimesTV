import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Renders a 1024x1024 lime image.
//   arg1: output path
//   arg2 (optional): "slice" -> transparent background, edge-to-edge circle
//                    otherwise -> app icon with green background

let size = 1024.0
let cx = size / 2
let cy = size / 2

let mode = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "icon"
let isSlice = (mode == "slice")

// Outer radius of the whole slice.
let R = isSlice ? 502.0 : 360.0

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil,
    width: Int(size),
    height: Int(size),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Could not create context")
}

func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(colorSpace: colorSpace, components: [r, g, b, a])!
}

func point(_ radius: Double, _ angle: Double) -> CGPoint {
    CGPoint(x: cx + radius * cos(angle), y: cy + radius * sin(angle))
}

func disc(_ radius: Double, _ color: CGColor) {
    ctx.setFillColor(color)
    ctx.addArc(center: CGPoint(x: cx, y: cy), radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.fillPath()
}

// MARK: - Background (icon only)
if !isSlice {
    let bgColors = [rgb(0.72, 0.90, 0.30), rgb(0.42, 0.72, 0.22)] as CFArray
    let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0, 1])!
    ctx.drawLinearGradient(bgGradient,
                           start: CGPoint(x: 0, y: size),
                           end: CGPoint(x: 0, y: 0),
                           options: [])
}

// MARK: - Lime slice (radii proportional to R)
disc(R,          rgb(0.24, 0.47, 0.13)) // dark-green rind
disc(R * 0.950,  rgb(0.49, 0.70, 0.22)) // mid rind
disc(R * 0.894,  rgb(0.95, 0.98, 0.87)) // white pith
disc(R * 0.867,  rgb(0.90, 0.96, 0.78)) // flesh membrane base

// Juicy segments (wedges with white membrane gaps)
let segments = 9
let gap = 3.5 * .pi / 180
let rInner = R * 0.094
let rOuter = R * 0.822

for i in 0..<segments {
    let a0 = Double(i) / Double(segments) * .pi * 2 + gap
    let a1 = Double(i + 1) / Double(segments) * .pi * 2 - gap

    let path = CGMutablePath()
    path.move(to: point(rInner, a0))
    path.addLine(to: point(rOuter, a0))
    path.addArc(center: CGPoint(x: cx, y: cy), radius: rOuter, startAngle: a0, endAngle: a1, clockwise: false)
    path.addLine(to: point(rInner, a1))
    path.addArc(center: CGPoint(x: cx, y: cy), radius: rInner, startAngle: a1, endAngle: a0, clockwise: true)
    path.closeSubpath()

    ctx.addPath(path)
    ctx.setFillColor(rgb(0.75, 0.90, 0.42))
    ctx.fillPath()
}

// MARK: - Glossy highlight (top-left), clipped to the slice
ctx.saveGState()
ctx.addArc(center: CGPoint(x: cx, y: cy), radius: R, startAngle: 0, endAngle: .pi * 2, clockwise: false)
ctx.clip()
let glossColors = [rgb(1, 1, 1, 0.35), rgb(1, 1, 1, 0)] as CFArray
let glossGradient = CGGradient(colorsSpace: colorSpace, colors: glossColors, locations: [0, 1])!
let gOff = R * 0.39
ctx.drawRadialGradient(glossGradient,
                       startCenter: CGPoint(x: cx - gOff, y: cy + gOff), startRadius: 0,
                       endCenter: CGPoint(x: cx - gOff, y: cy + gOff), endRadius: R * 0.94,
                       options: [])
ctx.restoreGState()

// MARK: - Write PNG
let image = ctx.makeImage()!
let outURL = URL(fileURLWithPath: CommandLine.arguments[1])
let dest = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
if CGImageDestinationFinalize(dest) {
    print("Wrote \(outURL.path) [mode: \(mode)]")
} else {
    fatalError("Failed to write PNG")
}
