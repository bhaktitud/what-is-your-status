import SwiftUI
import WhatsYourStatusCore

#if canImport(AppKit)
import AppKit

private func dynamicColor(
    lightRed: CGFloat, lightGreen: CGFloat, lightBlue: CGFloat, lightAlpha: CGFloat = 1.0,
    darkRed: CGFloat, darkGreen: CGFloat, darkBlue: CGFloat, darkAlpha: CGFloat = 1.0
) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if isDark {
            return NSColor(srgbRed: darkRed, green: darkGreen, blue: darkBlue, alpha: darkAlpha)
        } else {
            return NSColor(srgbRed: lightRed, green: lightGreen, blue: lightBlue, alpha: lightAlpha)
        }
    })
}
#else
private func dynamicColor(
    lightRed: CGFloat, lightGreen: CGFloat, lightBlue: CGFloat, lightAlpha: CGFloat = 1.0,
    darkRed: CGFloat, darkGreen: CGFloat, darkBlue: CGFloat, darkAlpha: CGFloat = 1.0
) -> Color {
    Color(red: Double(lightRed), green: Double(lightGreen), blue: Double(lightBlue), opacity: Double(lightAlpha))
}
#endif

enum AppTheme {
    // Surfaces
    static let canvas = dynamicColor(
        lightRed: 0xF8/255, lightGreen: 0xF9/255, lightBlue: 0xFA/255,
        darkRed: 0x11/255, darkGreen: 0x13/255, darkBlue: 0x18/255
    )
    static let paper = dynamicColor(
        lightRed: 1.0, lightGreen: 1.0, lightBlue: 1.0,
        darkRed: 0x1A/255, darkGreen: 0x1E/255, darkBlue: 0x26/255
    )
    static let surfaceMuted = dynamicColor(
        lightRed: 0xF1/255, lightGreen: 0xF5/255, lightBlue: 0xF9/255,
        darkRed: 0x24/255, darkGreen: 0x2A/255, darkBlue: 0x36/255
    )
    static let focusSurface = dynamicColor(
        lightRed: 0xF8/255, lightGreen: 0xFA/255, lightBlue: 0xFC/255,
        darkRed: 0x20/255, darkGreen: 0x26/255, darkBlue: 0x33/255
    )
    static let hoverSurface = dynamicColor(
        lightRed: 0xEA/255, lightGreen: 0xEE/255, lightBlue: 0xF4/255,
        darkRed: 0x2B/255, darkGreen: 0x32/255, darkBlue: 0x40/255
    )
    static let cardHoverSurface = dynamicColor(
        lightRed: 0xFB/255, lightGreen: 0xFD/255, lightBlue: 1.0,
        darkRed: 0x22/255, darkGreen: 0x27/255, darkBlue: 0x33/255
    )

    // Modern typography ink colors (Slate palette with verified WCAG AA contrast)
    static let ink = dynamicColor(
        lightRed: 0x0F/255, lightGreen: 0x17/255, lightBlue: 0x2A/255,
        darkRed: 0xF8/255, darkGreen: 0xFA/255, darkBlue: 0xFC/255
    )
    static let secondaryInk = dynamicColor(
        lightRed: 0x33/255, lightGreen: 0x41/255, lightBlue: 0x55/255,
        darkRed: 0xCB/255, darkGreen: 0xD5/255, darkBlue: 0xE1/255
    )
    static let muted = dynamicColor(
        lightRed: 0x64/255, lightGreen: 0x74/255, lightBlue: 0x8B/255,
        darkRed: 0x94/255, darkGreen: 0xA3/255, darkBlue: 0xB8/255
    )
    static let subtleMuted = dynamicColor(
        lightRed: 0x94/255, lightGreen: 0xA3/255, lightBlue: 0xB8/255,
        darkRed: 0x64/255, darkGreen: 0x74/255, darkBlue: 0x8B/255
    )

    // Structural borders
    static let line = dynamicColor(
        lightRed: 0xE2/255, lightGreen: 0xE8/255, lightBlue: 0xF0/255,
        darkRed: 0x2E/255, darkGreen: 0x38/255, darkBlue: 0x46/255
    )
    static let lineStrong = dynamicColor(
        lightRed: 0x71/255, lightGreen: 0x80/255, lightBlue: 0x96/255,
        darkRed: 0x4B/255, darkGreen: 0x55/255, darkBlue: 0x63/255
    )
    static let cardBorder = dynamicColor(
        lightRed: 0xE2/255, lightGreen: 0xE8/255, lightBlue: 0xF0/255,
        darkRed: 0x2E/255, darkGreen: 0x38/255, darkBlue: 0x46/255
    )

    // Primary deliberate accent: clean modern blue
    static let blue = dynamicColor(
        lightRed: 0x25/255, lightGreen: 0x63/255, lightBlue: 0xEB/255,
        darkRed: 0x3B/255, darkGreen: 0x82/255, darkBlue: 0xF6/255
    )
    static let blueDark = dynamicColor(
        lightRed: 0x1D/255, lightGreen: 0x4E/255, lightBlue: 0xD8/255,
        darkRed: 0x25/255, darkGreen: 0x63/255, darkBlue: 0xEB/255
    )
    static let blueSoft = dynamicColor(
        lightRed: 0xEF/255, lightGreen: 0xF6/255, lightBlue: 0xFF/255,
        darkRed: 0x1E/255, darkGreen: 0x3A/255, darkBlue: 0x8A/255, darkAlpha: 0.35
    )
    static let blueInk = dynamicColor(
        lightRed: 0x1E/255, lightGreen: 0x40/255, lightBlue: 0xAF/255,
        darkRed: 0x93/255, darkGreen: 0xC5/255, darkBlue: 0xFD/255
    )

    // Semantic status colors
    static let red = dynamicColor(
        lightRed: 0xBE/255, lightGreen: 0x12/255, lightBlue: 0x3C/255,
        darkRed: 0xFB/255, darkGreen: 0x71/255, darkBlue: 0x85/255
    )
    static let redSoft = dynamicColor(
        lightRed: 0xFF/255, lightGreen: 0xF1/255, lightBlue: 0xF2/255,
        darkRed: 0x88/255, darkGreen: 0x13/255, darkBlue: 0x37/255, darkAlpha: 0.35
    )
    static let dangerBorder = dynamicColor(
        lightRed: 0xFB/255, lightGreen: 0x71/255, lightBlue: 0x85/255,
        darkRed: 0xE1/255, darkGreen: 0x1D/255, darkBlue: 0x48/255
    )

    static let externalInk = dynamicColor(
        lightRed: 0x1D/255, lightGreen: 0x4E/255, lightBlue: 0xD8/255,
        darkRed: 0x93/255, darkGreen: 0xC5/255, darkBlue: 0xFD/255
    )
    static let amber = dynamicColor(
        lightRed: 0xB4/255, lightGreen: 0x53/255, lightBlue: 0x09/255,
        darkRed: 0xFB/255, darkGreen: 0xBF/255, darkBlue: 0x24/255
    )
    static let amberSoft = dynamicColor(
        lightRed: 0xFE/255, lightGreen: 0xF3/255, lightBlue: 0xC7/255,
        darkRed: 0x78/255, darkGreen: 0x35/255, darkBlue: 0x0F/255, darkAlpha: 0.35
    )

    static let slate = dynamicColor(
        lightRed: 0x47/255, lightGreen: 0x55/255, lightBlue: 0x69/255,
        darkRed: 0x94/255, darkGreen: 0xA3/255, darkBlue: 0xB8/255
    )
    static let slateSoft = dynamicColor(
        lightRed: 0xF1/255, lightGreen: 0xF5/255, lightBlue: 0xF9/255,
        darkRed: 0x33/255, darkGreen: 0x41/255, darkBlue: 0x55/255, darkAlpha: 0.4
    )

    static let green = dynamicColor(
        lightRed: 0x04/255, lightGreen: 0x78/255, lightBlue: 0x57/255,
        darkRed: 0x34/255, darkGreen: 0xD3/255, darkBlue: 0x99/255
    )
    static let greenSoft = dynamicColor(
        lightRed: 0xEC/255, lightGreen: 0xFD/255, lightBlue: 0xF5/255,
        darkRed: 0x06/255, darkGreen: 0x4E/255, darkBlue: 0x3B/255, darkAlpha: 0.35
    )


    // Radius design system
    static let radiusSmall: CGFloat = 8
    static let radiusCard: CGFloat = 12
    static let radiusPill: CGFloat = 20

    static func laneColors(for lane: TaskLane) -> (foreground: Color, background: Color) {
        switch lane {
        case .action:
            return (red, redSoft)
        case .external:
            return (externalInk, blueSoft)
        case .internal:
            return (amber, amberSoft)
        case .blocked:
            return (slate, slateSoft)
        case .done:
            return (green, greenSoft)
        }
    }
}

struct StatusBadge: View {
    let lane: TaskLane

    var body: some View {
        let colors = AppTheme.laneColors(for: lane)
        Text(lane.label)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(colors.foreground)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(colors.background)
            .clipShape(Capsule())
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 16)
            .frame(minHeight: 40)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                    .fill(configuration.isPressed || isHovered ? AppTheme.blueDark : AppTheme.blue)
            )
            .shadow(color: AppTheme.blue.opacity(0.18), radius: 4, y: 1.5)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

struct QuietButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(AppTheme.secondaryInk)
            .padding(.horizontal, 15)
            .frame(minHeight: 40)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                    .fill(configuration.isPressed || isHovered ? AppTheme.hoverSurface : AppTheme.paper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                    .stroke(AppTheme.lineStrong.opacity(0.6), lineWidth: 1)
            )
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

struct DangerButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(AppTheme.red)
            .padding(.horizontal, 15)
            .frame(minHeight: 40)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                    .fill(configuration.isPressed || isHovered ? AppTheme.redSoft : AppTheme.paper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                    .stroke(AppTheme.dangerBorder, lineWidth: 1)
            )
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

struct IconCloseButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(AppTheme.muted)
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(configuration.isPressed || isHovered ? AppTheme.surfaceMuted : Color.clear)
            )
            .onHover { hovering in
                isHovered = hovering
            }
    }
}
