import Foundation

class Row {
    let index: Int
    let components: [String]
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

    func compare(_ other: Row, column: String) throws -> ComparisonResult {
        let left = try self[column].orThrow(RuntimeError("Unknown column \(column)"))
        let right = try other[column].orThrow(RuntimeError("Unknown column \(column)"))
        return compare(left, right)
    }

    private func compare(_ v1: String, _ v2: String) -> ComparisonResult {
        if let v1Num = Int(v1), let v2Num = Int(v2) {
            return NSNumber(value: v1Num).compare(NSNumber(value: v2Num))
        } else {
            return v1.compare(v2)
        }    
    }
}