import Foundation

class Row {
    let index: Int
    var components: [String]
    let header: Header?

    convenience init(header: Header?, index: Int, data: String, delimeter: String, trim: Bool, hasOuterBorders: Bool) {
        var components = data.components(separatedBy: delimeter)
        
        if trim {
            components = components.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        }

        if hasOuterBorders {
            components = components.dropFirst().dropLast()
        }

        self.init(header: header, index: index, components: components)
    }

    init(header: Header?, index: Int, components: [String]) {
        self.header = header
        self.index = index
        self.components = components   
    }

    subscript(index: Int) -> String {
        components[index]
    }

    subscript(columnName: String) -> String? {
        if let index = header?.index(ofColumn: columnName) {
            return components[index]
        } else {
            return nil
        }
    }

    func asCsvData() -> Data { 
        components.joined(separator: ",").data(using: .utf8)! 
    }
}