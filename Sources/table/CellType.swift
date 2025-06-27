import Foundation

enum CellType {
  case string
  case number
  case date
  case boolean

  static func fromString(_ type: String) throws -> CellType {
    switch type.trimmingCharacters(in: .whitespaces).lowercased() {
      case "string": return .string
      case "number": return .number
      case "date": return .date
      case "boolean": return .boolean
      default: throw RuntimeError("Unsupported cell type \(type)")
    }
  }

  static func fromStringList(_ types: String) throws -> [CellType] {
    do {
      // long format "string, number, date, boolean"
      return try types.split(separator: ",") .map { try CellType.fromString(String($0.trimmingCharacters(in: .whitespaces))) }
    } catch {
      do {
        // short format "sndb" for string, number, date, boolean
        return try types.trimmingCharacters(in: .whitespaces).lowercased().map { c in
          switch c {
            case "s": return .string
            case "n": return .number
            case "d": return .date
            case "b": return .boolean
            default: throw RuntimeError("Unsupported cell type \(c)")
          }
        }
      } catch { 
        throw RuntimeError("Unsupported cell type \(types)") 
      }
    }
  }
  
  // Infers cell types from the first few rows of data
  static func infer(rows: [[String]]) -> [CellType] {
    let dateFormat = DateFormatter()
    dateFormat.dateFormat = "yyyy-MM-dd hh:mm:ss"

    // Infer cell types from the first row
    var types: [CellType] =  rows.first?.map { value in
      if value.isNumber {
        return .number
      } else if value.isDate {
        return .date
      } else if value.isBoolean {
        return .boolean
      } else {
        return .string
      }
    } ?? []

    // refine with the rest of the rows
    for row in rows.dropFirst() {
      for (idx, value) in row.enumerated() {
        let type = types[idx]
        if type == .number && !value.isNumber {
          types[idx] = .string
        } else if type == .date && !value.isDate {
          types[idx] = .string
        } else if type == .boolean && !value.isBoolean {
          types[idx] = .string
        }
      }
    }

    debug("Infered cell types: \(CellType.toString(types))")

    return types
  }

  static func toString(_ types: [CellType]) -> String {
    return types.map { type in
      switch type {
        case .string: return "string"
        case .number: return "number"
        case .date: return "date"
        case .boolean: return "boolean"
      }
    }.joined(separator: ", ")
  }
}