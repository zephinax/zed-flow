import Foundation

public enum IPCError: Error, LocalizedError, Sendable {
    case appNotRunning
    case socketPathTooLong
    case bindFailed(errno: Int32)
    case connectFailed(underlying: String)
    case encodingFailed
    case decodingFailed
    case timeout
    case serverError(String)

    public var errorDescription: String? {
        switch self {
        case .appNotRunning:
            return "ZedFlow is not running. Please launch ZedFlow.app first."
        case .socketPathTooLong:
            return "IPC socket path exceeds maximum length for Unix domain sockets."
        case .bindFailed(let code):
            return "Failed to bind IPC socket (errno: \(code))."
        case .connectFailed(let msg):
            return "Failed to connect to ZedFlow: \(msg)"
        case .encodingFailed:
            return "Failed to encode IPC message."
        case .decodingFailed:
            return "Failed to decode response from ZedFlow."
        case .timeout:
            return "Operation timed out waiting for ZedFlow response."
        case .serverError(let msg):
            return msg
        }
    }
}
