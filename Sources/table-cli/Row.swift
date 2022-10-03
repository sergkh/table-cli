import Foundation

class Row {
    let index: Int
    let data: String
    var components: [String]
    let header: Header?

    init(header: Header?, index: Int, data: String, delimeter: String, trim: Bool, hasOuterBorders: Bool) {
        self.header = header
        self.index = index
        self.data = data
        var components = data.components(separatedBy: delimeter)
        
        if trim {
            components = components.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        }

        if hasOuterBorders {
            components = components.dropFirst().dropLast()
        }

        self.components = components
    }

    subscript(index: Int) -> String {
        components[index]
    }

    func asCsvData() -> Data { 
        components.joined(separator: ",").data(using: .utf8)! 
    }

    func colValue(columnName: String) -> String? {
        if let index = header?.index(ofColumn: columnName) {
            return components[index]
        } else {
            return nil
        }
    }
}