import Foundation

// Structure representing a format tree
protocol FormatExpr: CustomStringConvertible {
    func fill(row: Row) throws -> String 
    func validate(header: Header?) throws -> Void
}

protocol InternalFunction: CustomStringConvertible {
  var name: String { get }
  func validate(header: Header?, arguments: [any FormatExpr]) throws
  func apply(row: Row, arguments: [any FormatExpr]) throws -> String
}

struct VarExpr: FormatExpr {
    let name: String

    init(_ name: String) {
        self.name = name
    }

    func fill(row: Row) -> String {        
        return row[name] ?? ""
    }

    func validate(header: Header?) throws {
        if let h = header {
            if h.index(ofColumn: name) == nil {
                throw RuntimeError("Unknown column in format: \(name). Supported columns: \(h.columnsStr())")
            }        
        }
    }

    var description: String {
        return "Var(\(name))"
    }
}

struct TextExpr: FormatExpr {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    func fill(row: Row) -> String {
        return text
    }

    func validate(header: Header?) throws {}

    var description: String {
        return "Text(\(text))"
    }
}

struct FunctionExpr: FormatExpr {
    let name: String
    let arguments: [any FormatExpr]    
    static let regex: NSRegularExpression = try! NSRegularExpression(pattern: "\\$\\{([%A-Za-z0-9_\\s]+)\\}")

    init(name: String, arguments: [any FormatExpr] = []) {
        self.name = name
        self.arguments = arguments
    }

    func fill(row: Row) throws -> String {
        if let funcDef = Functions.find(name: name) {
            return try funcDef.apply(row: row, arguments: arguments)
        } else {
            throw RuntimeError("Unknown function in format: \(name). Supported functions: \(Functions.names.joined(separator: ", "))")
        }
    }

    func validate(header: Header?) throws {
        if let funcDef = Functions.find(name: name) {
            try funcDef.validate(header: header, arguments: arguments)
        } else {
            throw RuntimeError("Unknown function in format: \(name). Supported functions: \(Functions.names.joined(separator: ", "))")
        }
    }

    var description: String {
        return "Fun(name: \(name), arguments: \(arguments))"
    }
}

struct ExecExpr: FormatExpr {
    let command: any FormatExpr

    init(command: any FormatExpr) {
        self.command = command
    }

    func fill(row: Row) throws -> String {
        return try shell(String(describing: command.fill(row: row)))
    }

    func validate(header: Header?) throws {
        try command.validate(header: header)
    }

    var description: String {
        return "Exec(command: \(command))"
    }
}

struct FormatGroup: FormatExpr {
    let parts: [any FormatExpr]

    init(_ parts: [any FormatExpr]) {
        self.parts = parts
    }

    func fill(row: Row) throws -> String {
        var result = ""
        for part in parts {
            result += try part.fill(row: row)
        }
        return result
    }

    func validate(header: Header?) throws {
        for part in parts {
            try part.validate(header: header)
        }
    }

    var description: String {
        return "Group(\(parts))"
    }
}

class Functions {

  nonisolated(unsafe) static let all: [any InternalFunction] = [
    HeaderPrint(),
    Values(),
    Uuid(),
    Random(),
    RandomChoice(),
    Prefix(),
    Array(),
    Distinct()
  ]

  static func find(name: String) -> (any InternalFunction)? {
    return all.first { $0.name == name }
  }

  static var names: [String] { all.map { $0.name } }

  class HeaderPrint: InternalFunction {
    var name: String { "header" }

    func validate(header: Header?, arguments: [any FormatExpr]) throws {
      if arguments.count > 0 { throw RuntimeError("header function does not accept any arguments, got \(arguments.count): \(arguments)") }
      if header == nil { throw RuntimeError("Header is not defined") }
    }

    func apply(row: Row, arguments: [any FormatExpr]) throws -> String {        
        return row.header!.columnsStr()
    }

    var description: String { 
      return "header() – returns the header columns as a comma-separated string"
    }
  }

  class Values: InternalFunction {
    var name: String { "values" }

    func validate(header: Header?, arguments: [any FormatExpr]) throws {
        if arguments.count > 0 { 
            if !(try arguments[0].fill(row: Row.empty(header: header)).isBoolean) || arguments.count > 1 {
                throw RuntimeError("Internal function 'values' only accepts a single boolean argument: `values(true)` to return values as a quoted comma-separated string, or `values(false)` to return an unquoted comma-separated string. Got \(arguments.count): \(arguments)")
            }            
        }
    }

    func apply(row: Row, arguments: [any FormatExpr]) throws -> String {
        let quoted = arguments.count > 0 ? (try! arguments[0].fill(row: row)).boolValue : false
        
        if quoted {
            return row.components.enumerated().map { (index, cell) in
                let v = cell.value
                let type = row.header?.type(ofIndex: index) ?? .string
                
                if type == .boolean || type == .number || v.caseInsensitiveCompare("null") == .orderedSame {
                    return v
                } else {
                    return "'\(v.replacingOccurrences(of: "'", with: "''"))'"
                }
            }.joined(separator: ",")
        } else {
            return row.components.map { $0.value }.joined(separator: ",")
        }
    }

    var description: String {
        return "values(quote) – returns the row values as a comma-separated string. Arguments: optional boolean argument if true quotes the values depending on their type"
    }
  }

  class Uuid: InternalFunction {
    var name: String { "uuid" }

    func validate(header: Header?, arguments: [any FormatExpr]) throws {
        if !arguments.isEmpty {
            throw RuntimeError("uuid function does not accept any arguments, got \(arguments.count): \(arguments)")
        }
    }

    func apply(row: Row, arguments: [any FormatExpr]) throws -> String {
        return UUID().uuidString
    }

    var description: String {
        return "uuid() – returns a random UUID string"
    }
  }

  class Random: InternalFunction {
    var name: String { "random" }

    func validate(header: Header?, arguments: [any FormatExpr]) throws {
        if arguments.count < 0 {
            throw RuntimeError("Function \(name) accepts one or two arguments. It should be either random(to) or random(from, to)")
        }

        if arguments.count > 2 {
            throw RuntimeError("Function \(name) accepts at most two arguments, got \(arguments.count). It should be either random(to) or random(from, to)")
        }
    }

    func apply(row: Row, arguments: [any FormatExpr]) throws -> String {
        let from = arguments.count > 0 ? try Int(arguments[0].fill(row: row))! : 0
        let to = arguments.count == 2 ? try Int(arguments[1].fill(row: row))! : try Int(arguments[0].fill(row: row))!
        return String(Int.random(in: from...to))
    }

    var description: String {
        return "random(start, end) – returns a random integer. Arguments: one or two integers, either random(to) which generates random numbers from 0 or random(from, to) which generates random numbers in a given range"
    }
  }

  class RandomChoice: InternalFunction {
    var name: String { "randomChoice" }

    func validate(header: Header?, arguments: [any FormatExpr]) throws {
        if arguments.isEmpty {
            throw RuntimeError("Function \(name) requires at least one argument")
        }
    }

    func apply(row: Row, arguments: [any FormatExpr]) throws -> String {
        let choices = try arguments.map { try $0.fill(row: row) }
        return choices.randomElement() ?? ""
    }

    var description: String {
        return "randomChoice(arg1,arg2,...) – returns a random element from the provided arguments. Requires a comma-separated list of arguments to choose from"
    }
  }

  class Prefix: InternalFunction {
    var name: String { "prefix" }

    func validate(header: Header?, arguments: [any FormatExpr]) throws {
        guard arguments.count == 3 else {
            throw RuntimeError("prefix function requires 3 arguments: a string to prefix, a prefix itself and a numeric length, got \(arguments.count): \(arguments)")
        }

        guard let _: Int = try Int(arguments[2].fill(row: Row.empty(header: header))) else {
            throw RuntimeError("prefix function requires a numeric length argument")
        }
    }

    func apply(row: Row, arguments: [any FormatExpr]) throws -> String {
        let str = try! arguments[0].fill(row: row)
        let pref = try! arguments[1].fill(row: row)
        let len = try! Int(arguments[2].fill(row: row))!

        return len-str.count > 0 ? String(repeating: pref, count: len-str.count) + str : str
    }

    var description: String {
        return "prefix(str, prefix, num) – returns a string prefixed with a given prefix to a given length. Requires three arguments: the string to prefix, the prefix and the length. Example prefix(hello, ,10) returns '     hello"
    }
  }

  class Array: InternalFunction {
    var name: String { "array" }

    func validate(header: Header?, arguments: [any FormatExpr]) throws {
        if arguments.isEmpty {
            throw RuntimeError("Function \(name) requires at least one argument")
        }
    }

    func apply(row: Row, arguments: [any FormatExpr]) throws -> String {
        let arguments = try arguments.map { try $0.fill(row: row) }
        let elements = arguments.count > 1 ? arguments : arguments[0].split(separator: Character(",")).map { String($0).trimmingCharacters(in: .whitespaces) }

        let quoted = !elements.allSatisfy { $0.isNumber || $0.isBoolean || $0.caseInsensitiveCompare("null") == .orderedSame }

        return "[" + elements.map { quoted ? "'\($0)'" : $0 }.joined(separator: ", ") + "]"
    }

    var description: String {
        return "array(str) – returns a Cassandra representation of an array with the provided elements. Requires a comma-separated list of arguments or at least a single argument that will be split by commas"
    }
  }

  class Distinct: InternalFunction {
    var name: String { "distinct" }

    func validate(header: Header?, arguments: [any FormatExpr]) throws {
        if arguments.count != 1 {
            throw RuntimeError("Function \(name) requires exactly one argument")
        }
    }

    func apply(row: Row, arguments: [any FormatExpr]) throws -> String {
        let arguments = try arguments.map { try $0.fill(row: row) }
        let elements = arguments.count > 1 ? arguments : arguments[0].split(separator: Character(",")).map { String($0).trimmingCharacters(in: .whitespaces) }  

        return Set(elements).joined(separator: ",")
    }

    var description: String {
        return "distinct(str) – returns a distinct element from a comma separated list of elements. Requires a single argument that will be split by commas"
    }
  }
}