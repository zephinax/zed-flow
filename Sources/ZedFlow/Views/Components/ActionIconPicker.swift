import SwiftUI

public struct ActionIconPicker: View {
    @Binding var selectedIcon: String
    @State private var showingPicker: Bool = false

    public static let availableIcons: [String] = [
        "bolt",
        "power",
        "play",
        "stop",
        "pause",
        "arrow.clockwise",
        "arrow.clockwise.circle",
        "checkmark",
        "xmark",
        "gearshape",
        "slider.horizontal.3",
        "chart.bar",
        "chart.line.uptrend.xyaxis",
        "network",
        "wifi",
        "globe",
        "terminal",
        "lock",
        "unlock",
        "trash",
        "magnifyingglass",
        "info.circle",
        "exclamationmark.triangle"
    ]

    public init(selectedIcon: Binding<String>) {
        self._selectedIcon = selectedIcon
    }

    private let columns = [
        GridItem(.adaptive(minimum: 32), spacing: 8)
    ]

    public var body: some View {
        Button {
            showingPicker.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: selectedIcon.isEmpty ? "bolt" : selectedIcon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.accentColor)
                    .frame(width: 18, height: 18)

                Text(selectedIcon.isEmpty ? "bolt" : selectedIcon)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingPicker, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Choose Icon")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Self.availableIcons, id: \.self) { icon in
                        Button {
                            selectedIcon = icon
                            showingPicker = false
                        } label: {
                            Image(systemName: icon)
                                .font(.system(size: 14))
                                .foregroundColor(selectedIcon == icon ? .accentColor : .primary)
                                .frame(width: 32, height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(selectedIcon == icon ? Color.accentColor.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(selectedIcon == icon ? Color.accentColor : Color.clear, lineWidth: 1.5)
                                )
                        }
                        .buttonStyle(.plain)
                        .help(icon)
                    }
                }
            }
            .padding(12)
            .frame(width: 260)
        }
    }
}
