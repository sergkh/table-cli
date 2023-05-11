import Foundation

class Header {
    let cols: [String]
    let size: Int 

    convenience init(data: String, delimeter: String, trim: Bool, hasOuterBorders: Bool) {
      var components = data.components(separatedBy: delimeter)
      
      if trim {
          components = components.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      }
      
      if hasOuterBorders {
          components = components.dropFirst().dropLast()
      }
      
      self.init(components: components)
    }

    init(components: [String]) {        
      cols = components
      size = components.count
    }

    static func auto(size: Int) -> Header {
      Header(components: stride(from: 0, to: size, by: 1).map { idx in "col\(idx)" })
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

    func asCsvData() -> Data { 
        cols.joined(separator: ",").data(using: .utf8)! 
    }

    func components() -> [String] {
      cols
    }
}

extension Header {
    static func +(h1: Header, h2: Header) -> Header {
      Header(components: h1.components() + h2.components())
    }
}