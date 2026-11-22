import Foundation

enum Fixture {
    private static let columns =
        #""columnNames": ["station_id", "time", "WaveHeight", "Hmax", "WavePeriod", "MeanWaveDirection", "WindSpeed", "WindDirection", "Gust"]"#

    static let live = Data(
        """
        {
          "table": {
            \(columns),
            "rows": [
              ["M2", "2026-11-22T08:00:00Z", 2.461, 3.906, 5.508, 68, 25.843, 93, 31.877],
              ["M3", "2026-11-22T08:00:00Z", 5.156, 9.063, 7.617, 274, 29.373, 290, 41.896],
              ["M4", "2026-03-29T04:00:00Z", 1.2, 2.1, 6.0, 250, 12.0, 240, 18.0],
              ["M6", "2026-11-22T08:00:00Z", 4.102, 5.938, 6.914, null, 25.502, 288, null]
            ]
          }
        }
        """.utf8)

    static let withoutGust = Data(
        """
        {
          "table": {
            "columnNames": ["station_id", "time", "WaveHeight", "Hmax", "WavePeriod", "MeanWaveDirection", "WindSpeed", "WindDirection"],
            "rows": [
              ["M2", "2026-11-22T08:00:00Z", 2.461, 3.906, 5.508, 68, 25.843, 93]
            ]
          }
        }
        """.utf8)

    static let unreadableTime = Data(
        """
        {
          "table": {
            \(columns),
            "rows": [
              ["M2", "yesterday", 2.461, 3.906, 5.508, 68, 25.843, 93, 31.877]
            ]
          }
        }
        """.utf8)

    static let measurementAsString = Data(
        """
        {
          "table": {
            \(columns),
            "rows": [
              ["M2", "2026-11-22T08:00:00Z", "2.461", 3.906, 5.508, 68, 25.843, 93, 31.877]
            ]
          }
        }
        """.utf8)

    static let empty = Data(
        """
        {
          "table": {
            \(columns),
            "rows": []
          }
        }
        """.utf8)
}
