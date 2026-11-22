import Foundation
import Observations

struct Table: Decodable {
    enum Cell: Decodable, Equatable {
        case null
        case string(String)
        case number(Double)

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()

            if container.decodeNil() {
                self = .null
            } else if let number = try? container.decode(Double.self) {
                self = .number(number)
            } else {
                self = .string(try container.decode(String.self))
            }
        }

        var number: Double? {
            guard case .number(let value) = self else {
                return nil
            }

            return value
        }

        var string: String? {
            guard case .string(let value) = self else {
                return nil
            }

            return value
        }
    }

    struct Row {
        let cells: [Cell]

        subscript(column: Int) -> Cell {
            get throws {
                guard cells.indices.contains(column) else {
                    throw SourceFault.decoding
                }

                return cells[column]
            }
        }
    }

    private struct Payload: Decodable {
        let table: Table
    }

    let columnNames: [String]
    let rows: [[Cell]]

    init(data: Data) throws {
        do {
            self = try JSONDecoder().decode(Payload.self, from: data).table
        } catch {
            throw SourceFault.decoding
        }
    }

    func column(_ name: String) throws -> Int {
        guard let index = columnNames.firstIndex(of: name) else {
            throw SourceFault.missingColumn(name)
        }

        return index
    }

    var allRows: [Row] {
        rows.map(Row.init)
    }
}
