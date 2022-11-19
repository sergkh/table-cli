import Foundation

// Transforms each header or row.
// Currently supported transformations: 
// * Column projections
// * Adding new dynamic columns
class ColumnsMapper {
  let columns: [Int]?
  let additionalColumns: [(String, Format)]
  let join: Join?

  init(columns: [Int]? = nil, addColumns: [(String, Format)] = [], join: Join? = nil) {
    self.columns = columns
    self.additionalColumns = addColumns
    self.join = join
  }

  func addColumn(name: String, valueProvider: Format) throws -> ColumnsMapper {
    let tuple = (name, valueProvider)
    return ColumnsMapper(
      columns: self.columns, 
      addColumns: self.additionalColumns + [tuple],
      join: self.join
    )
  }

  func join(_ join: Join) -> ColumnsMapper {
    return ColumnsMapper(
      columns: self.columns, 
      addColumns: self.additionalColumns,
      join: join
    )
  }

  func map(row: Row) throws -> Row {
    let joinedRow = try join?.matching(row: row)

    let newColumnsData = additionalColumns.map { (_, fmt) in
      shell(fmt.fill(rows: [row].with(joinedRow)))
    }

    let mappedColumns = columns?.map{ row[$0] } ?? row.components 

    let joinedColumns = joinedRow.map{ $0.components } ?? []    

    return Row(
      header: row.header, 
      index: row.index, 
      components: mappedColumns + joinedColumns + newColumnsData
    )
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

    return ColumnsMapper(columns: colIds)
  }
}

// Transforms each header or row.
// Currently supported transformations: 
// * Column projections
// * Adding new dynamic columns
class TableView: Table {
  let table: any Table
  let header: Header

  init(table: any Table) {
    self.table = table
    self.header = table.header
  }

  func next() -> Row? {
    nil
  }

}