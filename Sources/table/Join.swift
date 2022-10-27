import Foundation

class Join {
  let firstColumn: String
  let secondColumn: String
  let matchTable: Table
  let firstColIndex: Int
  let secondColIndex: Int

  var loaded: Bool = false
  var rowsCache: [String:Row] = [:]

  init(firstColumn: String, secondColumn: String, firstColIndex: Int, matchTable: Table) throws {
    self.firstColumn = firstColumn
    self.secondColumn = secondColumn
    self.matchTable = matchTable
    self.firstColIndex = firstColIndex
    self.secondColIndex = try matchTable.header.index(ofColumn: secondColumn).orThrow(RuntimeError("Column \(secondColumn) is not found in table"))
  }

  func matching(row: Row) -> Row? {
    rowsCache[row[firstColIndex]]
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

  
  static func parse(_ file: String, joinOn: String?, firstTable: Table) throws -> Join {
    try parse(try Table.parse(path: file, hasHeader: nil, headerOverride: nil, delimeter: nil), joinOn: joinOn, firstTable: firstTable)
  }

  static func parse(_ table: Table, joinOn: String?, firstTable: Table) throws -> Join {
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
      firstColIndex: try firstTable.header.index(ofColumn: first).orThrow(RuntimeError("Column \(first) is not found in table")),
      matchTable: table
    ).load()
  } 
}