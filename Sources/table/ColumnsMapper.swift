import Foundation

class ColumnsMapper {
  let columns: [Int]

  init(columns: [Int]) {
    self.columns = columns
  }

  func map(row: Row) -> Row {    
    return Row(
      header: row.header, 
      index: row.index, 
      components: columns.map { row[$0] }
    )
  }

  static func parse(cols: String, header: Header) throws -> ColumnsMapper {
    let columnNames = cols.components(separatedBy: ",")

    let colIds = try columnNames.map { c throws in
      try header.index(ofColumn: c).orThrow(RuntimeError("Unknown column '\(c)'. Available columns: \(header.columnsStr())"))
    }

    return ColumnsMapper(columns: colIds)
  }
}