import SwiftUI
import ZedFlowKit

struct StatusIndicatorView: View {
    let status: ExecutionStatus?

    var body: some View {
        Group {
            switch status {
            case .running:
                ProgressView()
                    .controlSize(.mini)
                    .frame(width: 10, height: 10)
                    .help("Running")
            case .success:
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .help("Success")
            case .failed:
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .help("Failed")
            case .stopped:
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
                    .help("Stopped")
            case .none:
                Circle()
                    .fill(Color.secondary.opacity(0.35))
                    .frame(width: 8, height: 8)
                    .help("Idle")
            }
        }
        .frame(width: 12, height: 12)
    }
}
