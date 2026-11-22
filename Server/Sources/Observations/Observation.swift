import Foundation

public struct WaveObservation: Hashable, Sendable, Codable {
    public let station: StationID
    public let date: Date
    public let significantHeight: Double?
    public let maxHeight: Double?
    public let period: Double?
    public let direction: Double?

    public init(
        station: StationID,
        date: Date,
        significantHeight: Double?,
        maxHeight: Double?,
        period: Double?,
        direction: Double?
    ) {
        self.station = station
        self.date = date
        self.significantHeight = significantHeight
        self.maxHeight = maxHeight
        self.period = period
        self.direction = direction
    }
}

public struct WindObservation: Hashable, Sendable, Codable {
    public let station: StationID
    public let date: Date
    public let speed: Double?
    public let gust: Double?
    public let direction: Double?

    public init(
        station: StationID,
        date: Date,
        speed: Double?,
        gust: Double?,
        direction: Double?
    ) {
        self.station = station
        self.date = date
        self.speed = speed
        self.gust = gust
        self.direction = direction
    }
}

public enum Observation: Hashable, Sendable, Codable {
    case wave(WaveObservation)
    case wind(WindObservation)
}

extension Observation {
    public var station: StationID {
        switch self {
        case .wave(let observation):
            observation.station
        case .wind(let observation):
            observation.station
        }
    }

    public var date: Date {
        switch self {
        case .wave(let observation):
            observation.date
        case .wind(let observation):
            observation.date
        }
    }
}
