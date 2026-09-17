import SwiftUI
import ZedFlowKit

struct ScriptActionButton: View {
    let action: ScriptAction
    let isRunning: Bool
    let isCurrentActionRunning: Bool
    var size: ActionButtonSize = .compact
    let onExecute: () -> Void
    let onStop: () -> Void

    enum ActionButtonSize {
        case compact  // Used in ScriptRowView
        case regular  // Used in ScriptDetailView
    }

    @State private var isHovered: Bool = false

    var body: some View {
        Button {
            if isCurrentActionRunning {
                onStop()
            } else {
                onExecute()
            }
        } label: {
            HStack(spacing: size == .compact ? 4 : 6) {
                if isCurrentActionRunning {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.7)
                        .frame(width: 10, height: 10)
                } else {
                    Image(systemName: action.systemImage)
                        .font(.system(size: size == .compact ? 10 : 11, weight: .semibold))
                        .foregroundColor(iconColor)
                }

                Text(action.name)
                    .font(.system(size: size == .compact ? 11 : 12, weight: .medium))
                    .foregroundColor(isCurrentActionRunning ? .orange : .primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, size == .compact ? 8 : 10)
            .padding(.vertical, size == .compact ? 3.5 : 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(borderColor, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(isRunning && !isCurrentActionRunning)
        .onHover { hovering in
            isHovered = hovering
        }
        .help(isCurrentActionRunning ? "Stop \(action.name)" : "Run “\(action.name)” (\(action.arguments.joined(separator: " ")))")
    }

    private var iconColor: Color {
        let lower = action.name.lowercased()
        if lower.contains("on") || lower.contains("start") || lower.contains("enable") {
            return .green
        } else if lower.contains("off") || lower.contains("stop") || lower.contains("disable") {
            return .red.opacity(0.8)
        } else if lower.contains("status") || lower.contains("check") || lower.contains("info") {
            return .accentColor
        }
        return .secondary
    }

    private var backgroundColor: Color {
        if isCurrentActionRunning {
            return Color.orange.opacity(0.18)
        }
        if isHovered {
            return Color(nsColor: .controlAccentColor).opacity(0.12)
        }
        return Color(nsColor: .controlBackgroundColor).opacity(0.8)
    }

    private var borderColor: Color {
        if isCurrentActionRunning {
            return Color.orange.opacity(0.5)
        }
        if isHovered {
            return Color.accentColor.opacity(0.4)
        }
        return Color.primary.opacity(0.08)
    }
}
