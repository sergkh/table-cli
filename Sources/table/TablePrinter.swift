
import Foundation

let newLine = "\n".data(using: .utf8)!

protocol TablePrinter {
  func writeHeader(header: Header)
  func writeRow(row: Row)
  func flush()
}

class CsvTablePrinter: TablePrinter {
  private let delimeter: String
  private let outHandle: FileHandle
  
  init(delimeter: String, outHandle: FileHandle) {
    self.delimeter = delimeter
    self.outHandle = outHandle
  }

  func writeHeader(header: Header) {
    self.outHandle.write(header.cols.map({ r in r.contains(delimeter) ? ("\"" + r + "\"") : r }).joined(separator: delimeter).data(using: .utf8)!)
    self.outHandle.write(newLine)
  }

  func writeRow(row: Row) {
    self.outHandle.write(row.components.map({ r in r.value.contains(delimeter) ? ("\"" + r.value + "\"") : r.value }).joined(separator: delimeter).data(using: .utf8)!)
    self.outHandle.write(newLine)
  }

  func flush() {}
}

class CustomFormatTablePrinter: TablePrinter {
  private let format: Format
  private let outHandle: FileHandle

  init(format: Format, outHandle: FileHandle) {
    self.format = format
    self.outHandle = outHandle
  }

 // no header needed
  func writeHeader(header: Header) {}

  func writeRow(row: Row) {
    self.outHandle.write(self.format.fillData(row: row))
    self.outHandle.write(newLine)
  }

  func flush() {}
}

class PrettyTablePrinter: TablePrinter {
  private let outHandle: FileHandle
  private var columnWidths: [Int] = []
  private var header: Header?
  private var cachedRows: [Row] = []
  
  init(outHandle: FileHandle) {
    self.outHandle = outHandle
  }

  func writeHeader(header: Header) {
    self.header = header
    self.adjustColumns(row: header.cols)
  }

  func writeRow(row: Row) {
    self.cachedRows.append(row)
    self.adjustColumns(row: row.components.map{ $0.value })
  }

  func flush() {    
    let topBorder = "╭" + self.columnWidths.map( { String(repeating: "─", count: $0 + 2)}).joined(separator: "┬") + "╮\n"
    self.outHandle.write(topBorder.data(using: .utf8)!)
    
    if let header = self.header {
      self.outHandle.write(formatRow(header.cols).data(using: .utf8)!)

      let headerBorder = "├" + self.columnWidths.map( { String(repeating: "─", count: $0 + 2)}).joined(separator: "┼") + "┤\n"
      self.outHandle.write(headerBorder.data(using: .utf8)!)
    }

    for row in self.cachedRows {
      self.outHandle.write(formatRow(row.components.map{ $0.value }).data(using: .utf8)!)
    }

    let bottomBorder = "╰" + self.columnWidths.map( { String(repeating: "─", count: $0 + 2)}).joined(separator: "┴") + "╯\n"
    self.outHandle.write(bottomBorder.data(using: .utf8)!)
  }

  private func adjustColumns(row: [String]) {
    if self.columnWidths.isEmpty {
      self.columnWidths = row.map { $0.count }
    } else {
      
      if (row.count != self.columnWidths.count) {
        fatalError("Row \(row) has irregular size if \(row.count) columns, while expected \(self.columnWidths.count). Table output is not possible, please use CSV format")
      }

      for (i, col) in row.enumerated() {
        self.columnWidths[i] = max(self.columnWidths[i], col.count)
      }
    }
  }

  private func formatRow(_ row: [String]) -> String {
    return row.enumerated().map { (idx, col) in
        let padding = String(repeating: " ", count: self.columnWidths[idx] - col.count)
        return "│ " + col + padding + " "
      }.joined(separator: "") + "│\n"
  }
}