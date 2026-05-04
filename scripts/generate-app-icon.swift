#!/usr/bin/env swift
// Generates the Open Feelings app icon as a 1024x1024 PNG using CoreGraphics +
// AppKit (macOS host). Run from the repo root:
//
//   swift scripts/generate-app-icon.swift
//
// Writes to OpenFeelings/Assets.xcassets/AppIcon.appiconset/Icon.png. Re-run
// after tuning colors / radii to regenerate. Commit the resulting PNG.

import AppKit
import CoreGraphics
import Foundation

let size = 1024
let center = CGFloat(size / 2)

// Warm-calm palette (matches Color.OF.* light tokens).
let bg = CGColor(red: 250/255, green: 246/255, blue: 240/255, alpha: 1)              // FAF6F0 parchment
let outer = CGColor(red: 0x93/255, green: 0xAA/255, blue: 0xBF/255, alpha: 1)        // 93AABF muted slate-blue
let middle = CGColor(red: 0xC4/255, green: 0x6A/255, blue: 0x55/255, alpha: 1)       // C46A55 terracotta
let inner = CGColor(red: 0xD9/255, green: 0xA4/255, blue: 0x3A/255, alpha: 1)        // D9A43A honey-amber
let centerFill = CGColor(red: 0x8E/255, green: 0x4F/255, blue: 0x2C/255, alpha: 1)   // 8E4F2C deeper accent

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
guard let ctx = CGContext(data: nil,
                          width: size,
                          height: size,
                          bitsPerComponent: 8,
                          bytesPerRow: 0,
                          space: cs,
                          bitmapInfo: bitmapInfo) else {
    fatalError("Could not create CGContext")
}

// Background
ctx.setFillColor(bg)
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

// Three concentric rings, generous padding from edges.
let lineWidth: CGFloat = 56
let ringSpecs: [(radius: CGFloat, color: CGColor)] = [
    (440, outer),
    (320, middle),
    (200, inner)
]
for spec in ringSpecs {
    ctx.setStrokeColor(spec.color)
    ctx.setLineWidth(lineWidth)
    ctx.strokeEllipse(in: CGRect(x: center - spec.radius,
                                  y: center - spec.radius,
                                  width: spec.radius * 2,
                                  height: spec.radius * 2))
}

// Center filled disc
let centerRadius: CGFloat = 80
ctx.setFillColor(centerFill)
ctx.fillEllipse(in: CGRect(x: center - centerRadius,
                            y: center - centerRadius,
                            width: centerRadius * 2,
                            height: centerRadius * 2))

guard let cgImage = ctx.makeImage() else {
    fatalError("Could not create CGImage")
}
let rep = NSBitmapImageRep(cgImage: cgImage)
guard let pngData = rep.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode PNG")
}

let cwd = FileManager.default.currentDirectoryPath
let outURL = URL(fileURLWithPath: cwd)
    .appendingPathComponent("OpenFeelings/Assets.xcassets/AppIcon.appiconset/Icon.png")

// Ensure parent directory exists.
try? FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(),
                                          withIntermediateDirectories: true)

try pngData.write(to: outURL)
print("Wrote \(outURL.path)")
