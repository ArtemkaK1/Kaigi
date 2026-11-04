import SwiftUI

/// Equal-width native buttons with a single, interruptible selection indicator.
struct SlidingSegmentedControl<Value: Hashable>: View {
    let title: String
    let options: [Value]
    @Binding var selection: Value
    let label: (Value) -> String
    @FocusState private var focused: Value?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        HStack(spacing: AppSpacing.none) {
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                    focused = option
                } label: {
                    Text(label(option))
                        .appText(.body)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(selection == option ? AppColors.onAccent : AppColors.primary)
                .focusable(interactions: .edit)
                .focusEffectDisabled()
                .focused($focused, equals: option)
                .overlay {
                    if focused == option {
                        RoundedRectangle(cornerRadius: AppLayout.cornerRadius)
                            .strokeBorder(AppColors.accent, lineWidth: 2)
                            .allowsHitTesting(false)
                    }
                }
                .accessibilityAddTraits(selection == option ? .isSelected : [])
            }
        }
        .frame(width: AppLayout.segmentedControlWidth * AppTypography.scale(for: textSize), height: AppLayout.segmentedControlHeight * AppTypography.scale(for: textSize))
        .background(alignment: .leading) {
            GeometryReader { geometry in
                let segmentWidth = geometry.size.width / CGFloat(max(1, options.count))
                RoundedRectangle(cornerRadius: AppLayout.cornerRadius)
                    .fill(AppColors.accentFill)
                    .frame(width: segmentWidth)
                    .offset(x: CGFloat(options.firstIndex(of: selection) ?? 0) * segmentWidth)
                    .animation(reduceMotion ? nil : .spring(duration: 0.25, bounce: 0.1), value: selection)
            }
            .allowsHitTesting(false)
        }
        .background(AppColors.control, in: RoundedRectangle(cornerRadius: AppLayout.cornerRadius))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .onKeyPress(.leftArrow) {
            moveSelection(by: -1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            moveSelection(by: 1)
            return .handled
        }
        .onKeyPress(.space) {
            guard let focused else { return .ignored }
            selection = focused
            return .handled
        }
    }

    private func moveSelection(by step: Int) {
        guard let index = options.firstIndex(of: selection) else { return }
        selection = options[min(options.count - 1, max(0, index + step))]
        focused = selection
    }
}
