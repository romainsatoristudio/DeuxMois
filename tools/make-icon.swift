// Génère l'icône de l'app dans toutes les tailles macOS.
// Usage : swift tools/make-icon.swift App/Assets.xcassets/AppIcon.appiconset
import AppKit
import SwiftUI

/// Deux feuilles de calendrier : le mois suivant derrière, le mois en cours devant.
struct IconView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.42, green: 0.62, blue: 1.0), Color(red: 0.19, green: 0.31, blue: 0.86)],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.3), radius: 14, y: 10)

            Sheet(header: Color(red: 0.55, green: 0.6, blue: 0.7), current: false)
                .rotationEffect(.degrees(9))
                .offset(x: 62, y: -44)

            Sheet(header: Color(red: 0.96, green: 0.26, blue: 0.24), current: true)
                .rotationEffect(.degrees(-4))
                .offset(x: -40, y: 36)
        }
        .frame(width: 1024, height: 1024)
    }
}

struct Sheet: View {
    var header: Color
    var current: Bool

    private let columns = 5, rows = 4
    private let dot: CGFloat = 46, gap: CGFloat = 22

    var body: some View {
        VStack(spacing: 0) {
            header.frame(height: 118)
            VStack(spacing: gap) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(0..<columns, id: \.self) { column in
                            cell(row: row, column: column)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 470, height: 500)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 64, style: .continuous))
        .compositingGroup()
        .shadow(color: .black.opacity(0.25), radius: 18, y: 12)
    }

    @ViewBuilder
    private func cell(row: Int, column: Int) -> some View {
        let gray = Color(white: 0.84)
        if current && row == 2 && column == 2 {
            // Aujourd'hui
            Circle().fill(Color(red: 0.96, green: 0.26, blue: 0.24)).frame(width: dot * 1.45, height: dot * 1.45)
                .frame(width: dot, height: dot)
        } else if current && row == 1 && column == 3 {
            // Jour férié
            Circle().strokeBorder(Color(white: 0.55), lineWidth: 7).frame(width: dot * 1.25, height: dot * 1.25)
                .frame(width: dot, height: dot)
        } else if current && row == 3 && column == 1 {
            // Événement du calendrier familial
            ZStack {
                Circle().fill(gray)
                Circle().fill(Color(red: 1.0, green: 0.78, blue: 0.1)).frame(width: 22, height: 22).offset(y: 40)
            }
            .frame(width: dot, height: dot)
        } else {
            Circle().fill(column >= 3 && !current ? Color(white: 0.9) : gray).frame(width: dot, height: dot)
        }
    }
}

/// Retire le bloc EXIF qu'AppKit ajoute aux PNG : l'image publiée ne garde que ses pixels.
func withoutMetadata(_ png: Data) -> Data {
    var result = png.prefix(8)
    var offset = 8
    while offset + 8 <= png.count {
        let length = png[offset..<offset + 4].reduce(0) { $0 << 8 | Int($1) }
        let type = String(decoding: png[offset + 4..<offset + 8], as: UTF8.self)
        let end = offset + 12 + length
        if type != "eXIf" { result += png[offset..<end] }
        offset = end
    }
    return Data(result)
}

let output = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

let sizes: [(points: Int, scale: Int)] = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
var images: [[String: String]] = []

MainActor.assumeIsolated {
    for (points, scale) in sizes {
        let pixels = CGFloat(points * scale)
        let renderer = ImageRenderer(content: IconView())
        renderer.scale = pixels / 1024
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        let png = NSBitmapImageRep(cgImage: renderer.cgImage!).representation(using: .png, properties: [:])!
        try! withoutMetadata(png).write(to: output.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
    }
}

let contents: [String: Any] = ["images": images, "info": ["version": 1, "author": "xcode"]]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: output.appendingPathComponent("Contents.json"))
