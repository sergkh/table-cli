import Foundation

// Transforms each header or row.
// Currently supported transformations: 
// * Column projections
// * Adding new dynamic columns
class ColumnsMapper {
  let columns: [Int]?
  let additionalColumns: [(String, Format)]

  convenience init() {
    self.init(columns: nil, addColumns: [])
  }

  init(columns: [Int]?, addColumns: [(String, Format)]) {
    self.columns = columns
    self.additionalColumns = addColumns
  }

  func addColumn(name: String, valueProvider: Format) throws -> ColumnsMapper {
    let tuple = (name, valueProvider)
    return ColumnsMapper(
      columns: self.columns, 
      addColumns: self.additionalColumns + [tuple]
    )
  }

  func map(row: Row) -> Row {
    let newColumnsData = additionalColumns.map { (_, fmt) in
      shell(fmt.fill(rows: [row]))
    }

    if let columns {
      return Row(
        header: row.header, 
        index: row.index, 
        components: columns.map { row[$0] } + newColumnsData
      )
    } else if !newColumnsData.isEmpty {
      return Row(
        header: row.header, 
        index: row.index, 
        components: row.components + newColumnsData
      )
    } else {
      return row
    }
  }

  func map(header: Header) -> Header {    
    if let parsed = header as? ParsedHeader {
        let mappedColumns = columns?.map { parsed.cols[$0] } ?? parsed.cols
        return ParsedHeader(components: mappedColumns + additionalColumns.map { $0.0 })
    } else if let auto = header as? AutoHeader {
      if let columns {
        return ParsedHeader(components: columns.map { auto.name(index: $0) } + additionalColumns.map { $0.0 })
      } else {
        return auto
      }
    } else {
      return header
    }
  }

  static func parse(cols: String, header: Header) throws -> ColumnsMapper {
    let columnNames = cols.components(separatedBy: ",")

    let colIds = try columnNames.map { c throws in
      try header.index(ofColumn: c).orThrow(RuntimeError("Unknown column '\(c)'. Available columns: \(header.columnsStr())"))
    }

    return ColumnsMapper(columns: colIds, addColumns: [])
  }
}