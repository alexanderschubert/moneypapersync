import SwiftUI

struct FilterOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    var count: Int?

    var id: Value { value }
}

/// Horizontale Filter-Chips (horizontal scrollbar bei wenig Platz).
struct FilterBar<Value: Hashable>: View {
    let options: [FilterOption<Value>]
    @Binding var selection: Value

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(options) { option in
                    chip(option)
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 1)
        }
    }

    private func chip(_ option: FilterOption<Value>) -> some View {
        let selected = option.value == selection
        return Button {
            selection = option.value
        } label: {
            HStack(spacing: 6) {
                Text(option.title)
                if let count = option.count {
                    Text("\(count)")
                        .font(AppFont.captionMedium.monospacedDigit())
                        .foregroundStyle(selected ? AppColors.accentLight : AppColors.textMuted)
                }
            }
            .font(AppFont.secondary.weight(selected ? .semibold : .regular))
            .foregroundStyle(selected ? AppColors.textPrimary : AppColors.textSecondary)
            .padding(.horizontal, AppSpacing.md)
            .frame(height: 28)
            .background {
                Capsule()
                    .fill(selected ? AppColors.accent.opacity(0.20) : AppColors.glassFill)
                    .overlay {
                        Capsule().strokeBorder(selected ? AppColors.accent.opacity(0.5) : AppColors.glassBorder, lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .appAnimation(AppMotion.hover, value: selected)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
