public struct SourceID: RawRepresentable, Hashable, Sendable, Codable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }
}

public struct StationID: Hashable, Sendable, Codable {
    public let source: SourceID
    public let key: String

    public init(source: SourceID, key: String) {
        self.source = source
        self.key = key
    }
}

extension StationID: CustomStringConvertible {
    public var description: String {
        "\(source.rawValue)/\(key)"
    }
}
