import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol SourceAdapter: Sendable {
    var id: SourceID { get }
    var stations: [Station] { get }

    func request() throws -> URLRequest
    func observations(from data: Data, mimeType: String?) throws -> [Observation]
}

extension SourceAdapter {
    public func observations(using session: URLSession) async throws -> [Observation] {
        let (data, response) = try await session.data(for: try request())

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw SourceFault.httpStatus(http.statusCode)
        }

        return try observations(from: data, mimeType: response.mimeType)
    }
}
