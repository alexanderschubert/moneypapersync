import SwiftUI

// PrimaryButton.swift / SecondaryButton.swift (gemeinsame Datei, da identische Mechanik)

struct AppButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, destructive }

    let kind: Kind
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.bodyMedium)
            .foregroundStyle(foreground)
            .padding(.horizontal, AppSpacing.lg)
            .frame(minHeight: 30)
            .background {
                RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                    .fill(background(pressed: configuration.isPressed))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                            .strokeBorder(border, lineWidth: 1)
                    }
            }
            .opacity(isEnabled ? 1 : 0.45)
            .onHover { hovering = $0 }
            .appAnimation(AppMotion.hover, value: hovering)
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.small))
    }

    private var foreground: Color {
        switch kind {
        case .primary: .white
        case .secondary: AppColors.textPrimary
        case .destructive: AppColors.error
        }
    }

    private func background(pressed: Bool) -> Color {
        switch kind {
        case .primary:
            return pressed ? AppColors.accentDark : (hovering ? AppColors.accentLight : AppColors.accent)
        case .secondary:
            return pressed ? AppColors.glassFillHover : (hovering ? AppColors.glassFillHover : AppColors.glassFill)
        case .destructive:
            return AppColors.error.opacity(pressed ? 0.25 : (hovering ? 0.18 : 0.10))
        }
    }

    private var border: Color {
        switch kind {
        case .primary: .clear
        case .secondary: AppColors.glassBorder
        case .destructive: AppColors.error.opacity(0.3)
        }
    }
}

struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView().controlSize(.small).scaleEffect(0.7)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
        }
        .buttonStyle(AppButtonStyle(kind: .primary))
        .disabled(isLoading)
    }
}

struct SecondaryButton: View {
    let title: String
    var systemImage: String?
    var isDestructive = false
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView().controlSize(.small).scaleEffect(0.7)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
        }
        .buttonStyle(AppButtonStyle(kind: isDestructive ? .destructive : .secondary))
        .disabled(isLoading)
    }
}
