// =============================================================================
//  dsh-control-center · icon generator
//
//  Produces an ORIGINAL mark: a deep-water gradient with a sonar ping. No
//  DeepSeek brand asset is used or redistributed — their guidelines ask
//  third-party projects not to present official artwork as their own identity.
//
//  Geometry follows Apple's macOS icon grid: 1024x1024 canvas, an 824x824
//  rounded rectangle centred on it, corner radius 185.4.
//
//  Usage:  swift assets/generate-icon.swift <out.png> [content] [radius]
// =============================================================================

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
let outPath = args.count > 1 ? args[1] : "icon-1024.png"
let content = args.count > 2 ? Double(args[2])! : 824.0
let radius  = args.count > 3 ? Double(args[3])! : 185.4

let canvas = 1024
let space = CGColorSpaceCreateDeviceRGB()

guard let ctx = CGContext(data: nil, width: canvas, height: canvas,
                          bitsPerComponent: 8, bytesPerRow: 0, space: space,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    print("FAIL: no context"); exit(1)
}
ctx.clear(CGRect(x: 0, y: 0, width: canvas, height: canvas))
ctx.interpolationQuality = .high
ctx.setAllowsAntialiasing(true)

let rect = CGRect(x: (Double(canvas) - content) / 2.0,
                  y: (Double(canvas) - content) / 2.0,
                  width: content, height: content)

// Everything is drawn inside the squircle.
ctx.saveGState()
ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
ctx.clip()

// --- deep-water gradient -----------------------------------------------------
let top    = CGColor(red: 0.055, green: 0.145, blue: 0.255, alpha: 1)   // #0e253f
let bottom = CGColor(red: 0.012, green: 0.043, blue: 0.086, alpha: 1)   // #030b16
if let grad = CGGradient(colorsSpace: space, colors: [top, bottom] as CFArray, locations: [0, 1]) {
    ctx.drawLinearGradient(grad, start: CGPoint(x: rect.midX, y: rect.maxY),
                           end: CGPoint(x: rect.midX, y: rect.minY), options: [])
}

let cx = rect.midX
let cy = rect.midY
let accent = CGColor(red: 0.341, green: 0.843, blue: 1.0, alpha: 1)     // #57d7ff

// --- sonar rings -------------------------------------------------------------
// Three arcs of decreasing opacity. Bold enough to stay legible at 16px.
let rings: [(Double, Double)] = [(content * 0.185, 1.00),
                                 (content * 0.300, 0.52),
                                 (content * 0.415, 0.24)]
for (r, alpha) in rings {
    ctx.setStrokeColor(CGColor(red: 0.341, green: 0.843, blue: 1.0, alpha: alpha))
    ctx.setLineWidth(content * 0.032)
    ctx.setLineCap(.round)
    ctx.addArc(center: CGPoint(x: cx, y: cy), radius: r,
               startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.strokePath()
}

// --- core --------------------------------------------------------------------
// A terminal chevron ">" inside a filled core: control, at a glance.
let coreR = content * 0.105
ctx.setFillColor(accent)
ctx.addArc(center: CGPoint(x: cx, y: cy), radius: coreR, startAngle: 0, endAngle: .pi * 2, clockwise: false)
ctx.fillPath()

ctx.setStrokeColor(CGColor(red: 0.012, green: 0.043, blue: 0.086, alpha: 1))
ctx.setLineWidth(content * 0.030)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
let chev = CGMutablePath()
let w = coreR * 0.40, h = coreR * 0.46
chev.move(to: CGPoint(x: cx - w * 0.55, y: cy + h))
chev.addLine(to: CGPoint(x: cx + w * 0.75, y: cy))
chev.addLine(to: CGPoint(x: cx - w * 0.55, y: cy - h))
ctx.addPath(chev)
ctx.strokePath()

ctx.restoreGState()

guard let img = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: outPath) as CFURL,
                                                 UTType.png.identifier as CFString, 1, nil) else {
    print("FAIL: no image"); exit(1)
}
CGImageDestinationAddImage(dest, img, nil)
if !CGImageDestinationFinalize(dest) { print("FAIL: write"); exit(1) }
print("wrote \(outPath)  content=\(content) radius=\(radius)")
