#!/usr/bin/env swift

import AppKit
import Foundation

let arguments = CommandLine.arguments
let outputDirectory = arguments.count > 1 ? arguments[1] : "Resources"
let root = URL(fileURLWithPath: outputDirectory, isDirectory: true)
let iconsetURL = root.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let icnsURL = root.appendingPathComponent("AppIcon.icns")

try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func renderIcon(pixels: Int) -> Data {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Unable to create bitmap")
    }
    rep.size = NSSize(width: pixels, height: pixels)

    NSGraphicsContext.saveGraphicsState()
    guard let graphicsContext = NSGraphicsContext(bitmapImageRep: rep) else {
        fatalError("Unable to create graphics context")
    }
    NSGraphicsContext.current = graphicsContext

    let context = graphicsContext.cgContext
    context.setShouldAntialias(true)
    context.interpolationQuality = .high

    let scale = CGFloat(pixels) / 1024
    context.scaleBy(x: scale, y: scale)

    let iconRect = CGRect(x: 96, y: 96, width: 832, height: 832)
    let iconPath = CGPath(
        roundedRect: iconRect,
        cornerWidth: 188,
        cornerHeight: 188,
        transform: nil
    )

    // Soft drop shadow, kept inside the 1024 canvas.
    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -18),
        blur: 42,
        color: NSColor.black.withAlphaComponent(0.32).cgColor
    )
    context.addPath(iconPath)
    context.setFillColor(NSColor.black.cgColor)
    context.fillPath()
    context.restoreGState()

    // Background gradient.
    context.saveGState()
    context.addPath(iconPath)
    context.clip()

    let gradientColors = [
        color(0x2F6BFF).cgColor,
        color(0x6C5CE7).cgColor,
        color(0xA34FEA).cgColor
    ] as CFArray
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: gradientColors,
        locations: [0, 0.55, 1]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 160, y: 940),
        end: CGPoint(x: 890, y: 80),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )

    // Top-left sheen.
    let sheenColors = [
        NSColor.white.withAlphaComponent(0.22).cgColor,
        NSColor.white.withAlphaComponent(0).cgColor
    ] as CFArray
    let sheen = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: sheenColors,
        locations: [0, 1]
    )!
    context.drawRadialGradient(
        sheen,
        startCenter: CGPoint(x: 260, y: 860),
        startRadius: 0,
        endCenter: CGPoint(x: 260, y: 860),
        endRadius: 560,
        options: []
    )

    // Bottom violet glow.
    let glowColors = [
        color(0xC08BFF, alpha: 0.30).cgColor,
        color(0xC08BFF, alpha: 0).cgColor
    ] as CFArray
    let glow = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: glowColors,
        locations: [0, 1]
    )!
    context.drawRadialGradient(
        glow,
        startCenter: CGPoint(x: 800, y: 190),
        startRadius: 0,
        endCenter: CGPoint(x: 800, y: 190),
        endRadius: 420,
        options: []
    )

    context.restoreGState()

    // Inner border.
    context.saveGState()
    context.addPath(iconPath)
    context.setStrokeColor(NSColor.white.withAlphaComponent(0.20).cgColor)
    context.setLineWidth(3)
    context.strokePath()
    context.restoreGState()

    // Heartbeat line.
    let points = [
        CGPoint(x: 208, y: 512),
        CGPoint(x: 326, y: 512),
        CGPoint(x: 390, y: 402),
        CGPoint(x: 472, y: 672),
        CGPoint(x: 558, y: 338),
        CGPoint(x: 628, y: 512),
        CGPoint(x: 816, y: 512)
    ]

    context.saveGState()
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setLineWidth(54)
    context.setStrokeColor(NSColor.white.withAlphaComponent(0.28).cgColor)
    context.setShadow(
        offset: .zero,
        blur: 26,
        color: NSColor.white.withAlphaComponent(0.35).cgColor
    )
    context.beginPath()
    context.move(to: points[0])
    for point in points.dropFirst() {
        context.addLine(to: point)
    }
    context.strokePath()

    context.setShadow(offset: .zero, blur: 0, color: nil)
    context.setStrokeColor(NSColor.white.cgColor)
    context.setLineWidth(40)
    context.beginPath()
    context.move(to: points[0])
    for point in points.dropFirst() {
        context.addLine(to: point)
    }
    context.strokePath()
    context.restoreGState()

    // Live dot on the pulse line.
    context.saveGState()
    let dotCenter = CGPoint(x: 816, y: 512)
    context.setFillColor(NSColor.white.cgColor)
    context.fillEllipse(in: CGRect(x: dotCenter.x - 40, y: dotCenter.y - 40, width: 80, height: 80))
    context.setFillColor(color(0x5CE1B0).cgColor)
    context.fillEllipse(in: CGRect(x: dotCenter.x - 27, y: dotCenter.y - 27, width: 54, height: 54))
    context.restoreGState()

    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("Unable to encode PNG")
    }
    return data
}

let variants: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in variants {
    let data = renderIcon(pixels: size)
    try data.write(to: iconsetURL.appendingPathComponent(name))
    print("icon: \(name) (\(size)x\(size))")
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsURL.path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else {
    fatalError("iconutil failed with status \(process.terminationStatus)")
}
try? FileManager.default.removeItem(at: iconsetURL)
print("wrote \(icnsURL.path)")
