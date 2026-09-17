import SwiftUI
import AppKit
import ZedFlowKit

struct LogConsoleView: View {
    let execution: ScriptExecution?
    let isRunning: Bool

    @State private var autoScroll: Bool = true
    @State private var copied: Bool = false

    private var outputChunks: [LogChunk] {
        if let chunks = execution?.outputChunks, !chunks.isEmpty {
            return chunks
        }
        // Fallback if execution only has raw stdout/stderr strings
        var fallback: [LogChunk] = []
        if let stdout = execution?.stdout, !stdout.isEmpty {
            fallback.append(LogChunk(stream: .stdout, text: stdout))
        }
        if let stderr = execution?.stderr, !stderr.isEmpty {
            fallback.append(LogChunk(stream: .stderr, text: stderr))
        }
        return fallback
    }

    private var fullOutputText: String {
        guard let exec = execution else { return "" }
        if !exec.outputChunks.isEmpty {
            return exec.outputChunks.map(\.text).joined()
        }
        var text = ""
        if !exec.stdout.isEmpty { text += exec.stdout }
        if !exec.stderr.isEmpty {
            if !text.isEmpty && !text.hasSuffix("\n") { text += "\n" }
            text += exec.stderr
        }
        return text
    }

    var body: some View {
        VStack(spacing: 0) {
            // Console Toolbar
            HStack(spacing: 8) {
                Text("Console Output")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()

                // Copy Output Button
                Button {
                    copyOutput()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10))
                        Text(copied ? "Copied" : "Copy")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                }
                .buttonStyle(.plain)
                .disabled(fullOutputText.isEmpty)
                .help("Copy full output to clipboard")

                // Auto-Scroll Toggle Button
                Button {
                    autoScroll.toggle()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: autoScroll ? "arrow.down.to.line.compact" : "pause.circle")
                            .font(.system(size: 10))
                        Text(autoScroll ? "Auto-scroll" : "Paused")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(autoScroll ? .accentColor : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                }
                .buttonStyle(.plain)
                .help(autoScroll ? "Auto-scroll enabled (click to pause)" : "Auto-scroll paused (click to resume)")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

            Divider()

            // Console Log Viewer
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 1) {
                        if outputChunks.isEmpty {
                            VStack(spacing: 6) {
                                if isRunning {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Waiting for output…")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("No output recorded")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            ForEach(Array(outputChunks.enumerated()), id: \.element.id) { index, chunk in
                                HStack(alignment: .top, spacing: 6) {
                                    // Subtle indicator for stderr
                                    if chunk.stream == .stderr {
                                        Text("ERR")
                                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                            .foregroundColor(.red)
                                            .padding(.horizontal, 3)
                                            .padding(.vertical, 1)
                                            .background(
                                                RoundedRectangle(cornerRadius: 2)
                                                    .fill(Color.red.opacity(0.15))
                                            )
                                    }

                                    Text(chunk.text)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(chunk.stream == .stderr ? Color(nsColor: .systemRed) : .primary)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }

                            // Bottom scroll anchor
                            Color.clear
                                .frame(height: 1)
                                .id("console_bottom_anchor")
                        }
                    }
                    .padding(10)
                }
                .background(Color(nsColor: .textBackgroundColor).opacity(0.7))
                .onChange(of: outputChunks.count) { _, _ in
                    if autoScroll {
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo("console_bottom_anchor", anchor: .bottom)
                        }
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }

    private func copyOutput() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(fullOutputText, forType: .string)

        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copied = false
        }
    }
}
