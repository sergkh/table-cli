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
    let joinedRow = join?.matching(row: row)

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
      let mappedColumns = columns?.map { header.cols[$0] } ?? header.cols
      return Header(components: mappedColumns + additionalColumns.map { $0.0 })
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

/** Joining table view */
class JoinTableView: Table {
  var table: any Table
  let join: Join

  var header: Header { 
    get {
      return self.table.header + self.join.matchTable.header
    }
  }

  init(table: any Table, join: Join) {
    self.table = table
    self.join = join
  }

  func next() -> Row? {
    let row = table.next()
    if let row {
      let joinedRow = join.matching(row: row)
      let joinedColumns = joinedRow.map{ $0.components } ?? []

      return Row(
        header: row.header, 
        index: row.index, 
        components: row.components + joinedColumns
      )
    } else {
      return nil
    }
  }

}