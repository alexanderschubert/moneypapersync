import SwiftUI

struct SearchField: View {
    @Binding var text: String
    var prompt = "Suchen"
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.textMuted)
                .accessibilityHidden(true)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(AppFont.body)
                .foregroundStyle(AppColors.textPrimary)
                .focused($focused)
                .accessibilityLabel(prompt)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppColors.textMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Suche löschen")
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .frame(height: 32)
        .background {
            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                .fill(AppColors.glassFill)
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                        .strokeBorder(focused ? AppColors.accent : AppColors.glassBorder, lineWidth: focused ? 1.5 : 1)
                }
        }
        .appAnimation(AppMotion.hover, value: focused)
    }
}
