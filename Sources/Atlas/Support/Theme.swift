import SwiftUI

/// The handful of colours that make Atlas feel like Atlas.
enum Theme {
    static let accent = Color(red: 0.36, green: 0.80, blue: 0.99)
    static let gold = Color(red: 1.00, green: 0.72, blue: 0.36)
    static let coral = Color(red: 1.00, green: 0.48, blue: 0.45)
    static let violet = Color(red: 0.64, green: 0.52, blue: 1.00)
    static let mint = Color(red: 0.42, green: 0.92, blue: 0.76)
    static let ink = Color(red: 0.05, green: 0.07, blue: 0.12)

    static func cardShape(_ radius: CGFloat = 30) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    static func keyShape(_ radius: CGFloat = 17) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}

/// A "Golden Gate" aurora: warm sunset light over cold fog.
struct AuroraBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let isDark = colorScheme == .dark
            let diameter = max(size.width, size.height)

            ZStack {
                mesh(isDark: isDark)

                Circle()
                    .fill(Theme.gold.opacity(isDark ? 0.32 : 0.38))
                    .frame(width: diameter * 0.62, height: diameter * 0.62)
                    .blur(radius: 150)
                    .offset(x: -size.width * 0.18, y: -size.height * 0.18)

                Circle()
                    .fill(Theme.accent.opacity(isDark ? 0.30 : 0.32))
                    .frame(width: diameter * 0.70, height: diameter * 0.70)
                    .blur(radius: 170)
                    .offset(x: size.width * 0.20, y: size.height * 0.24)

                Circle()
                    .fill(Theme.violet.opacity(isDark ? 0.24 : 0.22))
                    .frame(width: diameter * 0.48, height: diameter * 0.48)
                    .blur(radius: 130)
                    .offset(x: size.width * 0.32, y: -size.height * 0.22)

                LinearGradient(
                    colors: [.clear, Theme.ink.opacity(isDark ? 0.45 : 0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func mesh(isDark: Bool) -> some View {
        let points: [SIMD2<Float>] = [
            [0, 0], [0.5, 0], [1, 0],
            [0, 0.5], [0.5, 0.5], [1, 0.5],
            [0, 1], [0.5, 1], [1, 1]
        ]

        let colors: [Color] = isDark
            ? [
                Color(red: 0.02, green: 0.03, blue: 0.07),
                Color(red: 0.06, green: 0.14, blue: 0.26),
                Color(red: 0.03, green: 0.05, blue: 0.11),
                Color(red: 0.10, green: 0.10, blue: 0.28),
                Color(red: 0.09, green: 0.24, blue: 0.37),
                Color(red: 0.19, green: 0.10, blue: 0.24),
                Color(red: 0.03, green: 0.05, blue: 0.10),
                Color(red: 0.08, green: 0.17, blue: 0.23),
                Color(red: 0.02, green: 0.03, blue: 0.06)
            ]
            : [
                Color(red: 0.97, green: 0.98, blue: 1.00),
                Color(red: 0.88, green: 0.94, blue: 1.00),
                Color(red: 0.99, green: 0.97, blue: 1.00),
                Color(red: 0.90, green: 0.96, blue: 1.00),
                Color(red: 1.00, green: 0.96, blue: 0.90),
                Color(red: 0.96, green: 0.93, blue: 1.00),
                Color(red: 0.98, green: 0.99, blue: 1.00),
                Color(red: 0.92, green: 0.99, blue: 0.97),
                Color(red: 0.99, green: 0.98, blue: 1.00)
            ]

        return MeshGradient(width: 3, height: 3, points: points, colors: colors)
    }
}
