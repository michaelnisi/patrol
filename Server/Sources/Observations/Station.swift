public struct Station: Hashable, Sendable, Codable, Identifiable {
    public let id: StationID
    public let name: String
    public let latitude: Double
    public let longitude: Double

    public init(id: StationID, name: String, latitude: Double, longitude: Double) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }
}
