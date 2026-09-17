import Foundation
import Darwin

public struct IPCClient: Sendable {
    public let socketPath: String

    public init(socketPath: String = IPCProtocol.defaultSocketPath) {
        self.socketPath = socketPath
    }

    public func send(request: IPCRequest) async throws -> IPCResponse {
        // Fast-fail if socket file doesn't exist
        guard FileManager.default.fileExists(atPath: socketPath) else {
            throw IPCError.appNotRunning
        }

        let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw IPCError.connectFailed(underlying: "Failed to allocate socket (errno: \(errno))")
        }
        defer { Darwin.close(fd) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        let pathBytes = socketPath.utf8CString
        guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
            throw IPCError.socketPathTooLong
        }

        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            let raw = UnsafeMutableRawPointer(ptr)
            pathBytes.withUnsafeBufferPointer { buf in
                raw.copyMemory(from: buf.baseAddress!, byteCount: buf.count)
            }
        }

        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                Darwin.connect(fd, sa, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard connectResult == 0 else {
            let err = errno
            if err == ECONNREFUSED || err == ENOENT {
                throw IPCError.appNotRunning
            }
            throw IPCError.connectFailed(underlying: "Connect failed with errno \(err)")
        }

        // Encode request
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard var requestData = try? encoder.encode(request) else {
            throw IPCError.encodingFailed
        }
        requestData.append(UInt8(ascii: "\n"))

        // Write request to socket
        let writeResult = requestData.withUnsafeBytes { rawBuffer in
            Darwin.write(fd, rawBuffer.baseAddress, rawBuffer.count)
        }
        guard writeResult > 0 else {
            throw IPCError.connectFailed(underlying: "Failed to write request to socket.")
        }

        // Read response
        var buffer = [UInt8](repeating: 0, count: 16384)
        var responseData = Data()

        while true {
            let bytesRead = Darwin.read(fd, &buffer, buffer.count)
            if bytesRead <= 0 { break }
            responseData.append(buffer, count: bytesRead)
            if responseData.contains(UInt8(ascii: "\n")) { break }
        }

        guard !responseData.isEmpty else {
            throw IPCError.decodingFailed
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(IPCResponse.self, from: responseData)
        } catch {
            throw IPCError.decodingFailed
        }
    }
}
