// Generates the Atlas app icon at 1024×1024 PNG.
// Usage: swift Scripts/make-icon.swift <output.png>
import AppKit

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Resources/icon_1024.png"

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

guard let context = NSGraphicsContext.current?.cgContext else {
    FileHandle.standardError.write(Data("No graphics context\n".utf8))
    exit(1)
}

context.clear(CGRect(x: 0, y: 0, width: size, height: size))

let inset: CGFloat = 86
let body = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let shape = CGPath(roundedRect: body, cornerWidth: 196, cornerHeight: 196, transform: nil)

context.saveGState()
context.addPath(shape)
context.clip()

// Golden Gate palette: sunset gold → coral → ocean cyan.
let colors = [
    NSColor(red: 1.00, green: 0.80, blue: 0.46, alpha: 1).cgColor,
    NSColor(red: 1.00, green: 0.47, blue: 0.40, alpha: 1).cgColor,
    NSColor(red: 0.30, green: 0.70, blue: 1.00, alpha: 1).cgColor
] as CFArray

let gradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: colors,
    locations: [0, 0.52, 1]
)!

context.drawLinearGradient(
    gradient,
    start: CGPoint(x: body.minX, y: body.maxY),
    end: CGPoint(x: body.maxX, y: body.minY),
    options: []
)

// Specular sheen in the upper-left corner.
let sheenColors = [
    NSColor(white: 1, alpha: 0.42).cgColor,
    NSColor(white: 1, alpha: 0.0).cgColor
] as CFArray
let sheen = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: sheenColors,
    locations: [0, 1]
)!
context.drawRadialGradient(
    sheen,
    startCenter: CGPoint(x: body.minX + body.width * 0.24, y: body.maxY - body.height * 0.18),
    startRadius: 0,
    endCenter: CGPoint(x: body.minX + body.width * 0.24, y: body.maxY - body.height * 0.18),
    endRadius: body.width * 0.62,
    options: []
)

// Vignette at the bottom for depth.
let vignetteColors = [
    NSColor(white: 0, alpha: 0).cgColor,
    NSColor(white: 0, alpha: 0.16).cgColor
] as CFArray
let vignette = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: vignetteColors,
    locations: [0, 1]
)!
context.drawLinearGradient(
    vignette,
    start: CGPoint(x: body.midX, y: body.minY + body.height * 0.55),
    end: CGPoint(x: body.midX, y: body.minY),
    options: []
)

context.restoreGState()

// The sigma, with a soft inner shadow.
let sigma = "∑" as NSString
let font = NSFont.systemFont(ofSize: 560, weight: .semibold)
let shadow = NSShadow()
shadow.shadowColor = NSColor(white: 0, alpha: 0.28)
shadow.shadowBlurRadius = 26
shadow.shadowOffset = NSSize(width: 0, height: -14)

let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor(white: 1, alpha: 0.97),
    .shadow: shadow
]

let textSize = sigma.size(withAttributes: attributes)
sigma.draw(
    at: NSPoint(
        x: body.midX - textSize.width / 2,
        y: body.midY - textSize.height / 2 + 18
    ),
    withAttributes: attributes
)

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let representation = NSBitmapImageRep(data: tiff),
    let png = representation.representation(using: .png, properties: [:])
else {
    FileHandle.standardError.write(Data("Could not encode PNG\n".utf8))
    exit(1)
}

let url = URL(fileURLWithPath: outputPath)
try? FileManager.default.createDirectory(
    at: url.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try png.write(to: url)
print("Wrote \(url.path)")
