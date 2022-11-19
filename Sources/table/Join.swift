import Foundation

class Join {
  let firstColumn: String
  let secondColumn: String
  let secondColIndex: Int
  let matchTable: ParsedTable

  var loaded: Bool = false
  var rowsCache: [String:Row] = [:]

  init(firstColumn: String, secondColumn: String, matchTable: ParsedTable) throws {
    self.firstColumn = firstColumn
    self.secondColumn = secondColumn
    self.matchTable = matchTable
    self.secondColIndex = try matchTable.header.index(ofColumn: secondColumn).orThrow(RuntimeError("Column \(secondColumn) is not found in table"))
  }

  func matching(row: Row) throws -> Row? {
    try rowsCache[row[firstColumn].orThrow(RuntimeError("Column \(firstColumn) is not found"))]
  }

  func load() throws -> Join {
    for r in matchTable {
      let colValue = r[secondColIndex]
      
      if rowsCache[colValue] != nil {
        throw RuntimeError("Column \(secondColumn) has duplicate value \(colValue)")
      }

      rowsCache[colValue] = r
    }

    return self
  }

  
  static func parse(_ file: String, joinOn: String?, firstTable: any Table) throws -> Join {
    try parse(try ParsedTable.parse(path: file, hasHeader: nil, headerOverride: nil, delimeter: nil), joinOn: joinOn, firstTable: firstTable)
  }

  static func parse(_ table: ParsedTable, joinOn: String?, firstTable: any Table) throws -> Join {
    let (first, second) = try joinOn.map { joinExpr in 
        let components = joinExpr.components(separatedBy: "=")
        if components.count != 2 {
          throw RuntimeError("Join expression should have format: table1_column=table2_column")
        }
        return (components[0], components[1])
     } ?? ("1", "2") // TODO:

    return try Join(
      firstColumn: first,
      secondColumn: second,
      matchTable: table
    ).load()
  } 
}