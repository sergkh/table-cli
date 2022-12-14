import Foundation

protocol Header {
  func index(ofColumn: String) -> Int?
  func asCsvData() -> Data
  func columnsStr() -> String
}

class ParsedHeader: Header {
    let cols: [String]

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
}

// Used when file has no header, but we would like to address columns with col1, col2, etc.
class AutoHeader: Header {
    static var shared: AutoHeader = AutoHeader()

    func index(ofColumn: String) -> Int? {
      if ofColumn.starts(with: "col") {
        return Int(ofColumn[ofColumn.index(ofColumn.startIndex, offsetBy: 3)...])
      } else {
        return nil
      }
    }

    func name(index: Int) -> String {
      return "col\(index)"
    }

    func columnsStr() -> String {
      "col1,col2,col3,..."
    }

    func asCsvData() -> Data {
      "".data(using: .utf8)! 
    }
}