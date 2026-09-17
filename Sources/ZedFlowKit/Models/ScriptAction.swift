import Foundation

public struct ScriptAction: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var arguments: [String]
    public var systemImage: String

    public init(
        id: UUID = UUID(),
        name: String,
        arguments: [String],
        systemImage: String = "play"
    ) {
        self.id = id
        self.name = name
        self.arguments = arguments
        self.systemImage = systemImage
    }
}
