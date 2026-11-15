#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

// Produce an opaque 1024×1024 PNG required by App Store Connect.
// Uses only macOS system libraries; no third-party packages or remote artwork.
let destination = CommandLine.arguments.dropFirst().first
    ?? "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

let side = 1024
// CoreGraphics RGBX bitmap draws reliably on Apple Silicon and stores no alpha.
guard let bitmapContext = CGContext(
    data: nil,
    width: side,
    height: side,
    bitsPerComponent: 8,
    bytesPerRow: side * 4,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {
    fatalError("Cannot create an opaque CoreGraphics bitmap")
}
let context = NSGraphicsContext(cgContext: bitmapContext, flipped: false)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
let canvas = NSRect(x: 0, y: 0, width: side, height: side)
NSColor(srgbRed: 0.10, green: 0.23, blue: 0.48, alpha: 1).setFill()
canvas.fill()

let inset: CGFloat = 140
let spacing: CGFloat = 22
let keySide = (CGFloat(side) - inset * 2 - spacing * 2) / 3
let glyphs = ["ㄅ", "ㄆ", "ㄇ", "ㄉ", "ㄊ", "ㄋ", "ㄍ", "ㄎ", "ㄏ"]
for row in 0..<3 {
    for column in 0..<3 {
        let x = inset + CGFloat(column) * (keySide + spacing)
        let y = inset + CGFloat(2 - row) * (keySide + spacing)
        let rect = NSRect(x: x, y: y, width: keySide, height: keySide)
        NSColor(srgbRed: 0.96, green: 0.97, blue: 1.0, alpha: 1).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 38, yRadius: 38).fill()
        let glyph = glyphs[row * 3 + column] as NSString
        let font = NSFont.systemFont(ofSize: 112, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(srgbRed: 0.11, green: 0.26, blue: 0.53, alpha: 1)
        ]
        let size = glyph.size(withAttributes: attrs)
        glyph.draw(at: NSPoint(x: rect.midX - size.width / 2,
                               y: rect.midY - size.height / 2 + 5),
                   withAttributes: attrs)
    }
}
NSGraphicsContext.restoreGraphicsState()

let url = URL(fileURLWithPath: destination)
try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                        withIntermediateDirectories: true)
guard let image = bitmapContext.makeImage(),
      let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
    fatalError("Failed to encode opaque icon PNG")
}
try png.write(to: url)
print("Generated opaque 1024×1024 App icon: \(destination)")
