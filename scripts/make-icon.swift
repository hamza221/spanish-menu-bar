// Renders Packaging/AppIcon.icns (and website PNGs) following the macOS icon grid:
// 1024 canvas, 824 squircle body, soft drop shadow.
// Usage: swift scripts/make-icon.swift
import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("Packaging/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func render(size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let s = CGFloat(size) / 1024
    ctx.scaleBy(x: s, y: s)

    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let path = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

    // Shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.3).cgColor)
    ctx.addPath(path)
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // Body gradient (warm red → amber)
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    let colors = [NSColor(srgbRed: 1.00, green: 0.62, blue: 0.20, alpha: 1).cgColor,
                  NSColor(srgbRed: 0.90, green: 0.18, blue: 0.20, alpha: 1).cgColor] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    // Top sheen
    let sheen = [NSColor.white.withAlphaComponent(0.22).cgColor, NSColor.white.withAlphaComponent(0).cgColor] as CFArray
    ctx.drawLinearGradient(CGGradient(colorsSpace: nil, colors: sheen, locations: [0, 1])!,
                           start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 560), options: [])

    // Menu bar strip
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.25).cgColor)
    ctx.fill(CGRect(x: 100, y: 800, width: 824, height: 124))
    for (i, w) in [70, 110, 90].enumerated() {
        let x = 160 + CGFloat(i) * 150
        ctx.addPath(CGPath(roundedRect: CGRect(x: x, y: 850, width: CGFloat(w), height: 24), cornerWidth: 12, cornerHeight: 12, transform: nil))
    }
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.6).cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // Glyph
    let font = NSFont.systemFont(ofSize: 520, weight: .bold)
    let rounded = font.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 520) } ?? font
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.shadowOffset = NSSize(width: 0, height: -8)
    shadow.shadowBlurRadius = 16
    let attrs: [NSAttributedString.Key: Any] = [.font: rounded, .foregroundColor: NSColor.white, .shadow: shadow]
    let glyph = NSAttributedString(string: "ñ", attributes: attrs)
    let size = glyph.size()
    glyph.draw(at: CGPoint(x: 512 - size.width / 2, y: 410 - size.height / 2))

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try render(size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let website = root.appendingPathComponent("docs/assets")
try FileManager.default.createDirectory(at: website, withIntermediateDirectories: true)
try render(size: 512).write(to: website.appendingPathComponent("icon.png"))
try render(size: 64).write(to: website.appendingPathComponent("favicon.png"))
