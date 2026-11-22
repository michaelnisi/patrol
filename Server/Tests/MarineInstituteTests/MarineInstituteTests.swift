import Foundation
import Observations
import Testing

@testable import MarineInstitute

@Suite("MarineInstitute")
struct MarineInstituteTests {
    private let adapter = MarineInstitute()

    private let json = "application/json"

    private func station(_ key: String) -> StationID {
        StationID(source: MarineInstitute.sourceID, key: key)
    }

    private func waves(in observations: [Observation]) -> [WaveObservation] {
        observations.compactMap {
            guard case .wave(let wave) = $0 else {
                return nil
            }

            return wave
        }
    }

    private func winds(in observations: [Observation]) -> [WindObservation] {
        observations.compactMap {
            guard case .wind(let wind) = $0 else {
                return nil
            }

            return wind
        }
    }

    @Test("vends the four live buoys under stable keys")
    func vendsBuoys() {
        #expect(adapter.stations.map(\.id.key) == ["M2", "M3", "M5", "M6"])
        #expect(Set(adapter.stations.map(\.id.source)) == [adapter.id])
    }

    @Test("one request covers every buoy instead of one request per place")
    func oneBatchRequest() throws {
        let url = try #require(try adapter.request().url?.absoluteString)

        #expect(!url.contains("station_id="))
        #expect(url.hasPrefix("https://erddap.marine.ie/erddap/tabledap/IWBNetwork.json?"))
    }

    @Test("the query is percent-encoded exactly once")
    func encodesOnce() throws {
        let url = try #require(try adapter.request().url?.absoluteString)

        #expect(url.contains("time%3E=now-6hours"))
        #expect(url.contains("orderByMax(%22station_id,time%22)"))
        #expect(!url.contains("%25"))
    }

    @Test("maps wave readings per buoy, direction stays degrees from true north")
    func mapsWaves() throws {
        let observations = try adapter.observations(from: Fixture.live, mimeType: json)
        let m2 = try #require(waves(in: observations).first { $0.station == station("M2") })

        #expect(m2.date == (try Date("2026-11-22T08:00:00Z", strategy: .iso8601)))
        #expect(m2.significantHeight == 2.461)
        #expect(m2.maxHeight == 3.906)
        #expect(m2.period == 5.508)
        #expect(m2.direction == 68)
    }

    @Test("maps wind readings per buoy, direction stays degrees from true north")
    func mapsWinds() throws {
        let observations = try adapter.observations(from: Fixture.live, mimeType: json)
        let m3 = try #require(winds(in: observations).first { $0.station == station("M3") })

        #expect(m3.direction == 290)
    }

    @Test("converts wind speed and gust from knots to metres per second")
    func convertsKnots() throws {
        let observations = try adapter.observations(from: Fixture.live, mimeType: json)
        let m2 = try #require(winds(in: observations).first { $0.station == station("M2") })

        #expect(abs(try #require(m2.speed) - 13.295) < 0.001)
        #expect(abs(try #require(m2.gust) - 16.399) < 0.001)
    }

    @Test("every buoy that reported yields one wave and one wind observation")
    func pairsPerBuoy() throws {
        let observations = try adapter.observations(from: Fixture.live, mimeType: json)

        #expect(waves(in: observations).map(\.station.key) == ["M2", "M3", "M6"])
        #expect(winds(in: observations).map(\.station.key) == ["M2", "M3", "M6"])
    }

    @Test("ignores a station that is not one of the live buoys")
    func ignoresStationsOutsideTheEnum() throws {
        let observations = try adapter.observations(from: Fixture.live, mimeType: json)

        #expect(!observations.contains { $0.station == station("M4") })
    }

    @Test("a missing measurement stays nil instead of becoming zero")
    func nullsStayNil() throws {
        let observations = try adapter.observations(from: Fixture.live, mimeType: json)
        let m6Wave = try #require(waves(in: observations).first { $0.station == station("M6") })
        let m6Wind = try #require(winds(in: observations).first { $0.station == station("M6") })

        #expect(m6Wave.direction == nil)
        #expect(m6Wave.significantHeight == 4.102)
        #expect(m6Wind.gust == nil)
        #expect(m6Wind.speed != nil)
    }

    @Test("a renamed column fails loudly instead of reading as a missing measurement")
    func missingColumnThrows() {
        #expect(throws: SourceFault.missingColumn("Gust")) {
            try adapter.observations(from: Fixture.withoutGust, mimeType: json)
        }
    }

    @Test("rejects a response that is not JSON")
    func wrongMediaType() {
        #expect(throws: SourceFault.unexpectedMediaType("text/html")) {
            try adapter.observations(from: Fixture.live, mimeType: "text/html")
        }
    }

    @Test("rejects a body that is not an ERDDAP table")
    func garbage() {
        #expect(throws: SourceFault.decoding) {
            try adapter.observations(from: Data("<html></html>".utf8), mimeType: json)
        }
    }

    @Test("rejects a row whose time cannot be read")
    func unreadableTime() {
        #expect(throws: SourceFault.decoding) {
            try adapter.observations(from: Fixture.unreadableTime, mimeType: json)
        }
    }

    @Test("a measurement delivered as a string fails loudly instead of reading as missing")
    func measurementAsString() {
        #expect(throws: SourceFault.decoding) {
            try adapter.observations(from: Fixture.measurementAsString, mimeType: json)
        }
    }

    @Test("an empty table yields no observations")
    func emptyTable() throws {
        #expect(try adapter.observations(from: Fixture.empty, mimeType: json).isEmpty)
    }
}
