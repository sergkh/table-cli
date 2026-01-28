enum FileType: CaseIterable {
  case csv
  case table // own table format
  case sql
  case cassandraSql
  case generated

  static func hasOuterBorders(type: FileType) -> Bool {
    switch type {
      case .table:
        return true
      case .sql:
        return true
      default:
        return false
    }
  }

  static func outFormat(strFormat: String?) throws -> FileType {
    if let strFormat = strFormat {
      if strFormat == "csv" {
        return .csv
      } else if strFormat == "table" {
        return .table
      } else {
        throw RuntimeError("Unknown output format \(strFormat)")
      }
    } else {
      return .table
    }
  }
}