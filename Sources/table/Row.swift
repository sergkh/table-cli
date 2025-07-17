import Foundation

class Row {
    let index: Int
    let components: [Cell]
    let header: Header?

    var dictionary: [String: Cell] {
        var dict = [String: Cell]()
        
        if let header = header {
            for (index, name) in header.components().enumerated() {                
                dict[name] = components[index]
            }
        } else {
            for (index, cell) in components.enumerated() {
                dict[index.description] = cell
            }
        }
        
        return dict
    }

    convenience init(header: Header, index: Int, components: [String]) {
        let components = zip(components, header.types).map { Cell(value: $0.0, type: $0.1) }
        self.init(header: header, index: index, cells: components)
    }

    init(header: Header, index: Int, cells: [Cell]) {
        self.header = header
        self.index = index
        self.components = cells
    }

    subscript(index: Int) -> String {
        components[index].value
    }

    subscript(columnName: String) -> String? {
        if let index = header?.index(ofColumn: columnName) {
            return components[index].value
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