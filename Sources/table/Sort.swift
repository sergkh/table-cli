import Foundation

enum Order {
  case asc
  case desc
}

class Sort {
  let columns: [(String, Order)]

  init(_ str: String) {
    let cols = str.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    
    self.columns = cols.map({ 
      ($0.starts(with: "!") ? String($0.dropFirst()) : $0, $0.starts(with: "!") ? .desc : .asc)
    })
  }

  func validated(header: Header?) throws -> Sort {
    if let h = header {
            for (v, _) in columns {
                if h.index(ofColumn: v) == nil {
                    throw RuntimeError("Unknown column in sort expression: \(v). Supported columns: \(h.columnsStr())")
                }
            }
        }

        return self
  }
}