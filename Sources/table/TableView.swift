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
        shell(fmt.fill(row: row))
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

/** Table view with filtered columns */
class ColumnsTableView: Table {
  var table: any Table
  let visibleColumns: [String]
  let header: Header

  init(table: any Table, visibleColumns: [String]) {
    self.table = table
    self.visibleColumns = visibleColumns
    self.header = Header(components: visibleColumns)
  }

  func next() -> Row? {
    let row = table.next()

    if let row { 
      return Row(
        header: self.header, 
        index: row.index, 
        components: visibleColumns.map { col in row[col] ?? ""}
      )
    } else {
      return nil
    }
  }
}

/** Table view fully loaded into memory */
class InMemoryTableView: Table {
  var table: any Table  
  var header: Header { 
    get {
      return self.table.header
    }
  }

  private var cursor: Int = 0
  private var rows: [Row] = []
  private var loaded = false

  init(table: any Table) {
    self.table = table
  }

  func load() {
    if loaded {
      return
    }
    
    while let row = table.next() {
      rows.append(row)
    }

    loaded = true
  }

  func sort(expr: Sort) throws -> any Table {
    load()
    
    try rows.sort { (row1, row2) in
      for (col, order) in expr.columns {
        let cmp = try row1.compare(row2, column: col)
        if cmp != .orderedSame {
          return order == .desc ? cmp == .orderedDescending : cmp == .orderedAscending
        }
      }
      return false
    }

    return self
  }

  func reset() {
    cursor = 0
  }

  func next() -> Row? {
    if cursor < rows.count {
      let row = rows[cursor]
      cursor += 1
      return row
    } else {
      return nil
    }
  }
}