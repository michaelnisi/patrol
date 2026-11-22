import Foundation
import Testing

@testable import Observations

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private final class StubProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
        let status = components?.queryItems?.first { $0.name == "status" }?.value.flatMap(Int.init)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status ?? 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private struct StubAdapter: SourceAdapter {
    let id: SourceID = "test.source"
    let stations: [Station] = []
    let status: Int

    let observation = Observation.wind(
        WindObservation(
            station: StationID(source: "test.source", key: "a"),
            date: Date(timeIntervalSince1970: 0),
            speed: 5,
            gust: nil,
            direction: nil
        )
    )

    func request() throws -> URLRequest {
        URLRequest(url: URL(string: "https://stub.invalid/?status=\(status)")!)
    }

    func observations(from data: Data, mimeType: String?) throws -> [Observation] {
        [observation]
    }
}

@Suite("SourceAdapter")
struct SourceAdapterTests {
    private var session: URLSession {
        let configuration = URLSessionConfiguration.ephemeral

        configuration.protocolClasses = [StubProtocol.self]

        return URLSession(configuration: configuration)
    }

    @Test("a successful response is handed to the adapter's parser")
    func parsesSuccess() async throws {
        let adapter = StubAdapter(status: 200)

        let observations = try await adapter.observations(using: session)

        #expect(observations == [adapter.observation])
    }

    @Test("a failing HTTP status is reported instead of being parsed")
    func reportsHTTPStatus() async {
        let adapter = StubAdapter(status: 503)

        await #expect(throws: SourceFault.httpStatus(503)) {
            try await adapter.observations(using: session)
        }
    }
}

@Suite("Observation")
struct ObservationTests {
    private let station = StationID(source: "test.source", key: "a")

    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("a wave observation survives a Codable round trip with absent measurements")
    func waveRoundTrip() throws {
        let observation = Observation.wave(
            WaveObservation(
                station: station,
                date: date,
                significantHeight: 2.5,
                maxHeight: nil,
                period: 8,
                direction: nil
            )
        )

        let decoded = try JSONDecoder().decode(
            Observation.self, from: JSONEncoder().encode(observation))

        #expect(decoded == observation)
    }

    @Test("a wind observation survives a Codable round trip with absent measurements")
    func windRoundTrip() throws {
        let observation = Observation.wind(
            WindObservation(station: station, date: date, speed: 6, gust: nil, direction: 270)
        )

        let decoded = try JSONDecoder().decode(
            Observation.self, from: JSONEncoder().encode(observation))

        #expect(decoded == observation)
    }

    @Test("an observation reports the station and date of what it wraps")
    func accessors() {
        let observation = Observation.wind(
            WindObservation(station: station, date: date, speed: nil, gust: nil, direction: nil)
        )

        #expect(observation.station == station)
        #expect(observation.date == date)
    }

    @Test("a station id renders as source and key")
    func stationDescription() {
        #expect(station.description == "test.source/a")
    }
}
