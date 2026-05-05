#!/usr/bin/env swift
//
// generate-og.swift — produce static/og-image.png at 1200×630.
//
// Mirrors the warm-calm palette and the icon strokes from
// scripts/generate-app-icon.swift in the iOS app. Run from web/ or repo
// root; output path is resolved relative to this script.
//
// Usage:  swift web/scripts/generate-og.swift

import AppKit
import CoreGraphics
import CoreText
import Foundation

let width = 1200
let height = 630

let bg     = CGColor(red: 250/255, green: 246/255, blue: 240/255, alpha: 1) // #FAF6F0
let text   = CGColor(red:  43/255, green:  37/255, blue:  32/255, alpha: 1) // #2B2520
let muted  = CGColor(red: 107/255, green:  98/255, blue:  89/255, alpha: 1) // #6B6259
let accent = CGColor(red: 142/255, green:  79/255, blue:  44/255, alpha: 1) // #8E4F2C

let ringStrokes: [(radius: CGFloat, stroke: CGColor)] = [
    (200, CGColor(red: 0x93/255, green: 0xAA/255, blue: 0xBF/255, alpha: 1)),
    (150, CGColor(red: 0xC4/255, green: 0x6A/255, blue: 0x55/255, alpha: 1)),
    (100, CGColor(red: 0xD9/255, green: 0xA4/255, blue: 0x3A/255, alpha: 1))
]

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
guard let ctx = CGContext(
    data: nil, width: width, height: height,
    bitsPerComponent: 8, bytesPerRow: 0, space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Could not create CGContext")
}

ctx.setFillColor(bg)
ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

// Icon block — left side, vertically centered.
let iconCenterX: CGFloat = 280
let iconCenterY: CGFloat = CGFloat(height) / 2

ctx.setLineWidth(28)
for ring in ringStrokes {
    ctx.setStrokeColor(ring.stroke)
    ctx.strokeEllipse(in: CGRect(
        x: iconCenterX - ring.radius,
        y: iconCenterY - ring.radius,
        width: ring.radius * 2,
        height: ring.radius * 2
    ))
}
ctx.setFillColor(accent)
ctx.fillEllipse(in: CGRect(
    x: iconCenterX - 40, y: iconCenterY - 40, width: 80, height: 80
))

// Text block — right side.
func drawText(_ string: String, at point: CGPoint, font: NSFont, color: CGColor) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(cgColor: color) ?? .black
    ]
    let attributed = NSAttributedString(string: string, attributes: attrs)
    let line = CTLineCreateWithAttributedString(attributed)
    ctx.textPosition = point
    CTLineDraw(line, ctx)
}

let titleFont = NSFont(name: "Georgia", size: 92) ?? NSFont.systemFont(ofSize: 92)
let taglineFont = NSFont(name: "Helvetica Neue", size: 34)
    ?? NSFont.systemFont(ofSize: 34, weight: .regular)

// Core Text draws with origin at baseline; Y axis is bottom-up because we
// did NOT flip the context. Compute baselines manually.
let titleBaseline: CGFloat = 380
drawText("Open Feelings", at: CGPoint(x: 530, y: titleBaseline), font: titleFont, color: text)
drawText(
    "A calm, private feelings tracker for iPhone.",
    at: CGPoint(x: 530, y: titleBaseline - 70),
    font: taglineFont,
    color: muted
)

guard let cgImage = ctx.makeImage() else { fatalError("makeImage failed") }
let rep = NSBitmapImageRep(cgImage: cgImage)
guard let pngData = rep.representation(using: .png, properties: [:]) else {
    fatalError("PNG encoding failed")
}

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0])
    .deletingLastPathComponent()
let outURL = scriptURL
    .deletingLastPathComponent()
    .appendingPathComponent("static/og-image.png")
try pngData.write(to: outURL)
print("Wrote \(outURL.path) (\(pngData.count) bytes)")
