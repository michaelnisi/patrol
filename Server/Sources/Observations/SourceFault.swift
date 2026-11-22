public enum SourceFault: Error, Equatable, Sendable {
    case unexpectedMediaType(String?)
    case httpStatus(Int)
    case decoding
    case missingColumn(String)
}
