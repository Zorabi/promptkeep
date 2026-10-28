// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 dongx
import AppKit
let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let iconset = root.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
func rounded(_ rect: NSRect, _ radius: CGFloat, _ color: NSColor) {
    color.setFill(); NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}
func render(_ pixels: Int, _ target: URL) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: CGFloat(pixels)/1024, y: CGFloat(pixels)/1024)
    let base = NSBezierPath(roundedRect: NSRect(x: 72, y: 72, width: 880, height: 880), xRadius: 198, yRadius: 198)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.2); shadow.shadowBlurRadius = 26; shadow.shadowOffset = NSSize(width: 0, height: -12); shadow.set()
    NSColor(calibratedRed: 0.28, green: 0.35, blue: 0.74, alpha: 1).setFill(); base.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: NSColor(calibratedRed: 0.44, green: 0.52, blue: 0.91, alpha: 1), ending: NSColor(calibratedRed: 0.25, green: 0.31, blue: 0.69, alpha: 1))!.draw(in: base, angle: -70)
    // A saved prompt: paper, a command chevron, and a bookmark.
    rounded(NSRect(x: 245, y: 218, width: 534, height: 588), 67, .white.withAlphaComponent(0.13))
    rounded(NSRect(x: 215, y: 248, width: 534, height: 588), 67, NSColor(calibratedWhite: 0.99, alpha: 1))
    let accent = NSColor(calibratedRed: 0.31, green: 0.39, blue: 0.79, alpha: 1)
    let bookmark = NSBezierPath(); bookmark.move(to: NSPoint(x: 603, y: 836)); bookmark.line(to: NSPoint(x: 677, y: 836)); bookmark.line(to: NSPoint(x: 677, y: 680)); bookmark.line(to: NSPoint(x: 640, y: 707)); bookmark.line(to: NSPoint(x: 603, y: 680)); bookmark.close(); accent.setFill(); bookmark.fill()
    let chevron = NSBezierPath(); chevron.move(to: NSPoint(x: 320, y: 662)); chevron.line(to: NSPoint(x: 390, y: 603)); chevron.line(to: NSPoint(x: 320, y: 544)); chevron.lineWidth = 30; chevron.lineCapStyle = .round; chevron.lineJoinStyle = .round; accent.setStroke(); chevron.stroke()
    rounded(NSRect(x: 442, y: 543, width: 122, height: 29), 14.5, accent)
    rounded(NSRect(x: 314, y: 438, width: 332, height: 22), 11, NSColor(calibratedRed: 0.79, green: 0.82, blue: 0.93, alpha: 1))
    rounded(NSRect(x: 314, y: 374, width: 240, height: 22), 11, NSColor(calibratedRed: 0.86, green: 0.88, blue: 0.95, alpha: 1))
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: target)
}
for size in [16, 32, 128, 256, 512] {
    try render(size, iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(size*2, iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
try render(1024, root.appendingPathComponent("AppIcon.png"))
