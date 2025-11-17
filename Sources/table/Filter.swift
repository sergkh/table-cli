import Foundation

enum Operator: String, CaseIterable {
  case eq = "="
  case lt = "<"
  case ltEq = "<="
  case gt = ">"
  case gtEq = ">="
  case notEq = "!="
  case contains = "~="
  case startsWith = "^="
  case endsWith = "$="
}

class Filter {
  let column: Int
  let op: Operator
  let value: String
  let numberValue: Int?
  let invert: Bool

  init(column: Int, op: Operator, value: String, invert: Bool = false) {
    self.column = column
    self.op = op
    self.value = value
    self.numberValue = Int(value)
    self.invert = invert
  }

  static let regex = try! NSRegularExpression(pattern: "(!)?([A-Za-z_0-9]+)\\s?([><=!^~\\$]=?)\\s?(.*)", options: [])

  func apply(row: Row) -> Bool {
    let rowVal = row[column]
    var result: Bool = false 

    if (numberValue != nil) {
      let row = Int(rowVal)
      if (row != nil) {
        result = Filter.compare(v1: row!, v2: self.numberValue!, operation: self.op)
      } else {
        result = Filter.compare(v1: rowVal, v2: value, operation: op) 
      }
    } else {
      result = Filter.compare(v1: rowVal, v2: value, operation: op)
    }

    return invert ? !result : result
  }

  static func compare<T: Comparable>(v1: T, v2: T, operation: Operator) -> Bool {
    switch operation  {
      case .eq: return v1 == v2
      case .lt: return v1 < v2
      case .ltEq: return v1 <= v2
      case .gt: return v1 > v2
      case .gtEq: return  v1 >= v2
      case .notEq: return v1 != v2
      case .contains: return String(describing: v1).contains(String(describing: v2))
      case .startsWith: return String(describing: v1).starts(with: String(describing: v2))
      case .endsWith: return String(describing: v1).hasSuffix(String(describing: v2))
    }
  }

  static func compile(filter: String, header: Header) throws -> Filter {
    let range = NSRange(filter.startIndex..., in: filter)

    let matches = Filter.regex.matches(in: filter, range: range)
    
    if !matches.isEmpty {
      let groups = matches[0]

      let invert = groups.range(at: 1).location != NSNotFound

      let colName = String(filter[Range(groups.range(at: 2), in: filter)!]).trimmingCharacters(in: .whitespacesAndNewlines)

      let col = try header.index(ofColumn: colName).orThrow(RuntimeError("Filter: unknown column '\(colName)'. Available columns: \(header.columnsStr())"))

      let opStr = String(filter[Range(groups.range(at: 3), in: filter)!])

      let op = try Operator(rawValue: opStr).orThrow(RuntimeError("Filter: unsupported comparison operation '\(opStr)' should be one of =, !=, <, <=, >, >=, ^= (starts with), $= (ends with), ~= (contains)"))

      return Filter(
        column: col, 
        op: op, 
        value: String(filter[Range(groups.range(at: 4), in: filter)!]).trimmingCharacters(in: .whitespacesAndNewlines),
        invert: invert
      )
    } else {
      throw RuntimeError("Filter: Invalid filter format '\(filter)'. Should be <column_name><comparator><value>")
    }
  }


}