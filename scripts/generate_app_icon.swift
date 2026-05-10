#!/usr/bin/env swift
//
// Generates the AppIcon variants (light, dark, tinted) at 1024×1024 from
// the 5-core emotion palette. Source of truth for the icon — re-run this
// script to regenerate after any palette change. Outputs straight into
// OpenFeelings/Assets.xcassets/AppIcon.appiconset/.
//
// Usage:
//   swift scripts/generate_app_icon.swift
//
import AppKit
import CoreGraphics
import Foundation

// MARK: - Palette (must match OpenFeelings/Models/EmotionTaxonomy.swift)

private extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        self.init(srgbRed: r, green: g, blue: b, alpha: alpha)
    }
}

let happy     = NSColor(hex: 0xF4D03F)
let sad       = NSColor(hex: 0x3498DB)
let angry     = NSColor(hex: 0xEC7063)
let fearful   = NSColor(hex: 0xAF7AC5)
let disgusted = NSColor(hex: 0x58D68D)

let lightBg = NSColor(hex: 0xFAF6F0)
let darkBg  = NSColor(hex: 0x1B1A18)

// Order: start at top, go clockwise = visually pleasant warm→cool sweep.
let coreColors: [NSColor] = [happy, angry, fearful, sad, disgusted]

// MARK: - Geometry

let canvas: CGFloat = 1024
let center = CGPoint(x: canvas / 2, y: canvas / 2)
// Inset so the iOS squircle mask doesn't clip the petals.
let outerRadius: CGFloat = canvas * 0.42
let innerRadius: CGFloat = canvas * 0.14
let segmentDegrees: CGFloat = 360.0 / 5.0
let gapDegrees: CGFloat = 4.0

// MARK: - Drawing

enum Variant {
    case light
    case dark
    case tinted   // White silhouette on transparent — iOS tints these.
}

func renderIcon(variant: Variant, to url: URL) {
    let size = Int(canvas)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 32
    ) else {
        FileHandle.standardError.write("Failed to allocate bitmap\n".data(using: .utf8)!)
        exit(1)
    }

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    let gc = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.current = gc
    let ctx = gc.cgContext

    // Background
    let canvasRect = CGRect(x: 0, y: 0, width: canvas, height: canvas)
    switch variant {
    case .light:
        ctx.setFillColor(lightBg.cgColor)
        ctx.fill(canvasRect)
    case .dark:
        ctx.setFillColor(darkBg.cgColor)
        ctx.fill(canvasRect)
    case .tinted:
        ctx.clear(canvasRect)   // transparent for tint masking
    }

    // Petals
    for (i, color) in coreColors.enumerated() {
        // Start the first petal at 12 o'clock, sweep clockwise.
        // In y-up CoreGraphics, +90° = up; we sweep negative for clockwise.
        let centerAngleDeg = 90.0 - (CGFloat(i) * segmentDegrees) - (segmentDegrees / 2.0)
        let halfWedge = (segmentDegrees - gapDegrees) / 2.0
        let startDeg = centerAngleDeg - halfWedge
        let endDeg = centerAngleDeg + halfWedge
        let startRad = startDeg * .pi / 180
        let endRad = endDeg * .pi / 180

        let path = CGMutablePath()
        path.move(to: CGPoint(x: center.x + cos(startRad) * innerRadius,
                              y: center.y + sin(startRad) * innerRadius))
        path.addLine(to: CGPoint(x: center.x + cos(startRad) * outerRadius,
                                 y: center.y + sin(startRad) * outerRadius))
        path.addArc(center: center,
                    radius: outerRadius,
                    startAngle: startRad,
                    endAngle: endRad,
                    clockwise: false)
        path.addLine(to: CGPoint(x: center.x + cos(endRad) * innerRadius,
                                 y: center.y + sin(endRad) * innerRadius))
        path.addArc(center: center,
                    radius: innerRadius,
                    startAngle: endRad,
                    endAngle: startRad,
                    clockwise: true)
        path.closeSubpath()

        let fill: NSColor
        switch variant {
        case .light, .dark:
            fill = color
        case .tinted:
            fill = NSColor.white
        }
        ctx.setFillColor(fill.cgColor)
        ctx.addPath(path)
        ctx.fillPath()
    }

    // Center disc — soft brown grounding dot in light/dark, white in tinted.
    let centerDot = CGRect(
        x: center.x - innerRadius * 0.55,
        y: center.y - innerRadius * 0.55,
        width: innerRadius * 1.1,
        height: innerRadius * 1.1
    )
    let centerColor: NSColor
    switch variant {
    case .light:  centerColor = NSColor(hex: 0x8E4F2C)
    case .dark:   centerColor = NSColor(hex: 0xE8B998)
    case .tinted: centerColor = .white
    }
    ctx.setFillColor(centerColor.cgColor)
    ctx.fillEllipse(in: centerDot)

    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write("Failed to encode PNG\n".data(using: .utf8)!)
        exit(1)
    }
    try! pngData.write(to: url)
    print("Wrote \(url.path)")
}

// MARK: - Output

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
let repoRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let assetDir = repoRoot
    .appendingPathComponent("OpenFeelings")
    .appendingPathComponent("Assets.xcassets")
    .appendingPathComponent("AppIcon.appiconset")

renderIcon(variant: .light,  to: assetDir.appendingPathComponent("Icon.png"))
renderIcon(variant: .dark,   to: assetDir.appendingPathComponent("Icon-Dark.png"))
renderIcon(variant: .tinted, to: assetDir.appendingPathComponent("Icon-Tinted.png"))
