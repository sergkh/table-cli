import Foundation

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

  func next() throws -> Row? {
    let row = try table.next()
    if let row {
      let joinedRow = join.matching(row: row)
      let joinedColumns = joinedRow.map{ $0.components } ?? [Cell](repeating: Cell(value: ""), count: self.join.matchTable.header.size)

      return Row(
        header: header, 
        index: row.index, 
        cells: row.components + joinedColumns
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
      return self.table.header + Header(components: additionalColumns.map { $0.0 }, types: additionalColumns.map { _ in CellType.string })
    }
  }

  init(table: any Table, additionalColumns: [(String, Format)]) {
    self.table = table
    self.additionalColumns = additionalColumns
  }

  func next() throws -> Row? {
    let row = try table.next()

    if let row {
      let newColumnsData = additionalColumns.map { (_, fmt) in
        Cell(fn: { fmt.fill(row: row) })
      }

      return Row(
        header: header, 
        index: row.index, 
        cells: row.components + newColumnsData
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
    let types = visibleColumns.map { name in
      table.header.index(ofColumn: name).map {idx in table.header.types[idx]} ?? .string 
    }
    self.header = Header(components: visibleColumns, types: types)
  }

  func next() throws -> Row? {
    let row = try table.next()

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

/** Table view with filtered rows to allow only distinct values for certain columns */
class DistinctTableView: Table {
  var table: any Table
  let distinctColumns: [String]
  let header: Header

  private var distinctValues: Set<[String]> = []

  init(table: any Table, distinctColumns: [String]) {
    self.table = table
    self.distinctColumns = distinctColumns
    self.header = table.header
  }

  func next() throws -> Row? {
    var row = try table.next()

    while let curRow = row {
      let values = distinctColumns.map { col in curRow[col] ?? "" }
      
      if !distinctValues.contains(values) {
        distinctValues.insert(values)
        return curRow
      }

      row = try table.next()
    }
    
    return nil
  }
}

/** Table view that have randomized sample of the rows. */
class SampledTableView: Table {
  var table: any Table
  let percentage: Int
  let header: Header

  init(table: any Table, percentage: Int) {
    self.table = table
    self.percentage = percentage
    self.header = table.header
  }
  
  func next() throws -> Row? {    
    var row = try table.next()

    while let curRow = row {
      let useRow = sample()

      if useRow {
        return curRow
      }

      row = try table.next()
    }
    
    return nil
  }

  private func sample() -> Bool {
    return Int.random(in: 0...100) < percentage
  }
}

/** Table view fully loaded into memory */
class InMemoryTableView: InMemoryTable {
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

  func load() throws {
    if loaded {
      return
    }
    
    while let row = try table.next() {
      rows.append(row)
    }

    loaded = true
  }

  func sort(expr: Sort) throws -> any Table {
    try load()
    
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

  func rewind() {
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