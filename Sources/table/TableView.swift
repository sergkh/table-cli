import Foundation

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
      let joinedColumns = joinedRow.map{ $0.components } ?? [String](repeating: "", count: self.join.matchTable.header.size)

      return Row(
        header: header, 
        index: row.index, 
        components: row.components + joinedColumns
      )
    } else {
      return nil
    }
  }
}

/** Table view with additional dynamic columns */
class NewColumnsTableView: Table {
  var table: any Table
  let additionalColumns: [(String, Format)]

  var header: Header { 
    get {
      return self.table.header + Header(components: additionalColumns.map { $0.0 })
    }
  }

  init(table: any Table, additionalColumns: [(String, Format)]) {
    self.table = table
    self.additionalColumns = additionalColumns
  }

  func next() -> Row? {
    let row = table.next()

    if let row {
      let newColumnsData = additionalColumns.map { (_, fmt) in
        shell(fmt.fill(rows: [row]))
      }
      
      return Row(
        header: header, 
        index: row.index, 
        components: row.components + newColumnsData
      )
    } else {
      return nil
    }
  }
}