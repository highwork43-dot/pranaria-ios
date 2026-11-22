import SwiftUI
import UIKit

extension Color {
    /// Инициализация из hex-строки вида "#RRGGBB" (цвета программ взяты из оригинала).
    init(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        var number: UInt64 = 0
        Scanner(string: value).scanHexInt64(&number)
        let r = Double((number >> 16) & 0xFF) / 255.0
        let g = Double((number >> 8) & 0xFF) / 255.0
        let b = Double(number & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

/// Иконка программы или достижения: PNG из Content/Images (pr1…pr24, ach1…ach33).
struct ProgramIcon: View {
    let name: String
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let image = Bundle.main.image(named: name) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "wind")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Фон программы: PNG из Content/Images (prog01…prog24).
struct ProgramBackground: View {
    let name: String

    var body: some View {
        Group {
            if let image = Bundle.main.image(named: name) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [.purple.opacity(0.4), .blue.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .clipped()
    }
}

extension Bundle {
    /// Ищет PNG в корне бандла и в подкаталоге «Images» (на случай folder reference).
    func image(named name: String) -> UIImage? {
        if let image = UIImage(named: name, in: self, compatibleWith: nil) {
            return image
        }
        if let url = url(forResource: name, withExtension: "png", subdirectory: "Images"),
           let image = UIImage(contentsOfFile: url.path) {
            return image
        }
        return nil
    }
}
