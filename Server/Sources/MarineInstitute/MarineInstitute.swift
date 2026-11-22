import Foundation
import Observations

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct MarineInstitute: SourceAdapter {
    public static let sourceID: SourceID = "ink.codes.Patrol.source.marine-institute"

    public static let lookbackHours = 6

    public enum Buoy: CaseIterable, Equatable, Sendable {
        case m2
        case m3
        case m5
        case m6
    }

    public var id: SourceID {
        Self.sourceID
    }

    public var stations: [Station] {
        Buoy.allCases.map(\.station)
    }

    public init() {}
}

extension MarineInstitute.Buoy {
    public var key: String {
        switch self {
        case .m2:
            "M2"
        case .m3:
            "M3"
        case .m5:
            "M5"
        case .m6:
            "M6"
        }
    }

    public var station: Station {
        Station(
            id: StationID(source: MarineInstitute.sourceID, key: key),
            name: key,
            latitude: latitude,
            longitude: longitude
        )
    }

    public init?(key: String) {
        guard let match = Self.allCases.first(where: { $0.key == key }) else {
            return nil
        }

        self = match
    }

    private var latitude: Double {
        switch self {
        case .m2:
            53.4836
        case .m3:
            51.215956
        case .m5:
            51.690425
        case .m6:
            53.07482
        }
    }

    private var longitude: Double {
        switch self {
        case .m2:
            -5.4302
        case .m3:
            -10.548261
        case .m5:
            -6.704336
        case .m6:
            -15.88135
        }
    }
}

extension MarineInstitute {
    enum Column {
        static let station = "station_id"
        static let time = "time"
        static let waveHeight = "WaveHeight"
        static let maxHeight = "Hmax"
        static let wavePeriod = "WavePeriod"
        static let waveDirection = "MeanWaveDirection"
        static let windSpeed = "WindSpeed"
        static let windDirection = "WindDirection"
        static let gust = "Gust"

        static let requested = [
            station, time, waveHeight, maxHeight, wavePeriod, waveDirection, windSpeed,
            windDirection, gust,
        ]
    }

    static let metersPerSecondPerKnot = 1852.0 / 3600.0

    public func request() throws -> URLRequest {
        var components = URLComponents()

        components.scheme = "https"
        components.host = "erddap.marine.ie"
        components.path = "/erddap/tabledap/IWBNetwork.json"
        components.percentEncodedQuery = [
            Column.requested.joined(separator: ","),
            "time%3E=now-\(Self.lookbackHours)hours",
            "orderByMax(%22\(Column.station),\(Column.time)%22)",
        ].joined(separator: "&")

        guard let url = components.url else {
            throw SourceFault.decoding
        }

        return URLRequest(url: url)
    }
}

extension MarineInstitute {
    public func observations(from data: Data, mimeType: String?) throws -> [Observation] {
        if let mimeType, mimeType != "application/json" {
            throw SourceFault.unexpectedMediaType(mimeType)
        }

        let table = try Table(data: data)
        let columns = try Columns(table: table)

        return try table.allRows.flatMap { try observations(in: $0, columns: columns) }
    }

    private func observations(in row: Table.Row, columns: Columns) throws -> [Observation] {
        guard let key = try row[columns.station].string else {
            throw SourceFault.decoding
        }

        guard let buoy = Buoy(key: key) else {
            return []
        }

        guard let time = try row[columns.time].string,
            let date = try? Date(time, strategy: .iso8601)
        else {
            throw SourceFault.decoding
        }

        let station = buoy.station.id

        let wave = WaveObservation(
            station: station,
            date: date,
            significantHeight: try row[columns.waveHeight].measurement,
            maxHeight: try row[columns.maxHeight].measurement,
            period: try row[columns.wavePeriod].measurement,
            direction: try row[columns.waveDirection].measurement
        )

        let wind = WindObservation(
            station: station,
            date: date,
            speed: try row[columns.windSpeed].measurement.map(Self.metersPerSecond),
            gust: try row[columns.gust].measurement.map(Self.metersPerSecond),
            direction: try row[columns.windDirection].measurement
        )

        return [.wave(wave), .wind(wind)]
    }

    private static func metersPerSecond(knots: Double) -> Double {
        knots * metersPerSecondPerKnot
    }
}

extension MarineInstitute {
    struct Columns {
        let station: Int
        let time: Int
        let waveHeight: Int
        let maxHeight: Int
        let wavePeriod: Int
        let waveDirection: Int
        let windSpeed: Int
        let windDirection: Int
        let gust: Int

        init(table: Table) throws {
            station = try table.column(Column.station)
            time = try table.column(Column.time)
            waveHeight = try table.column(Column.waveHeight)
            maxHeight = try table.column(Column.maxHeight)
            wavePeriod = try table.column(Column.wavePeriod)
            waveDirection = try table.column(Column.waveDirection)
            windSpeed = try table.column(Column.windSpeed)
            windDirection = try table.column(Column.windDirection)
            gust = try table.column(Column.gust)
        }
    }
}
