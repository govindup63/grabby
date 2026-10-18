import AppKit
// Renders assets/app-icon.svg into an .iconset and assets/menubar-template.svg into 1x/2x template PNGs.
let fm = FileManager.default
let root = URL(fileURLWithPath: CommandLine.arguments[1])
func render(_ svg: URL, size: Int, to out: URL) {
    guard let image = NSImage(contentsOf: svg) else { fatalError("cannot load \(svg.path)") }
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size), from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: out)
}
let iconset = root.appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconset)
try! fm.createDirectory(at: iconset, withIntermediateDirectories: true)
let svg = root.appendingPathComponent("app-icon.svg")
for base in [16, 32, 128, 256, 512] {
    render(svg, size: base, to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    render(svg, size: base * 2, to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let mb = root.appendingPathComponent("menubar-template.svg")
let res = URL(fileURLWithPath: CommandLine.arguments[2])
render(mb, size: 18, to: res.appendingPathComponent("MenuBarTemplate.png"))
render(mb, size: 36, to: res.appendingPathComponent("MenuBarTemplate@2x.png"))
print("rendered")
