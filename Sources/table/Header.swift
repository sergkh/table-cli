import Foundation

class Header {
    let cols: [String]
    let size: Int
    let types: [CellType]

    convenience init(data: String, delimeter: String, trim: Bool, hasOuterBorders: Bool, types: [CellType]? = nil) throws {
      var components = try Csv.parseLine(data, delimeter: delimeter)
      
      if trim {
          components = components.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      }
      
      if hasOuterBorders {
          components = components.dropFirst().dropLast()
      }
      
      self.init(components: components, types: types ?? Array(repeating: .string, count: components.count))
    }

    init(components: [String], types: [CellType]) {        
      cols = components
      size = components.count
      self.types = types
    }

    static func auto(size: Int) -> Header {
      let components = stride(from: 0, to: size, by: 1).map { idx in "col\(idx)" }
      return Header(components: components, types: Array(repeating: .string, count: size))
    }

    subscript(index: Int) -> String {
      cols[index]
    }

    func columnsStr() -> String {
      cols.joined(separator: ",")
    }

    func index(ofColumn: String) -> Int? {
        cols.firstIndex(of: ofColumn)
    }

    func type(ofColumn: String) -> CellType? {
      guard let index = index(ofColumn: ofColumn) else { return .string }
      return index < types.count ? types[index] : .string
    }

    func type(ofIndex: Int) -> CellType? {      
      return ofIndex < types.count ? types[ofIndex] : .string
    }

    func components() -> [String] {
      cols
    }

    func withTypes(_ types: [CellType]) -> Header {
      Header(components: cols, types: types)
    }
}

extension Header {
    static func +(h1: Header, h2: Header) -> Header {
      Header(components: h1.components() + h2.components(), types: h1.types + h2.types)
    }
}