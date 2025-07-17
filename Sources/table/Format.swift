import Foundation

// Structure representing a format tree
protocol FormatExpr: CustomStringConvertible, Equatable {
    func fill(row: Row) throws -> String 
    func validate(header: Header?) throws -> Void
}

struct VarPart: FormatExpr {
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
        return "Var(name: \(name))"
    }
}

struct TextPart: FormatExpr {
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

struct FunctionPart: FormatExpr {
    let name: String
    
    static let internalFunctions = ["header", "values", "quoted_values", "uuid"]

    init(fnName: String) {
        self.name = fnName
    }

    func fill(row: Row) throws -> String {
        if name == "header" {
            guard let header = row.header else {
                throw RuntimeError("Header is not defined")
            }
            return header.columnsStr()
        }

        if name == "values" {
            return row.components.map({ $0.value }).joined(separator: ",")
        }

        if name == "uuid" {
            return UUID().uuidString
        }

        if name == "quoted_values" {
            return row.components.enumerated().map { (index, cell) in
                let v = cell.value
                let type = row.header?.type(ofIndex: index) ?? .string
                
                if type == .boolean || type == .number || v.caseInsensitiveCompare("null") == .orderedSame {
                    return v
                } else {
                    return "'\(v)'"
                }
            }.joined(separator: ",")
        }

        throw RuntimeError("Unknown function: \(name). Supported functions: \(FunctionPart.internalFunctions.joined(separator: ", "))")
    }

    func validate(header: Header?) throws {
        if let h = header {
            if !FunctionPart.internalFunctions.contains(name) && h.index(ofColumn: name) == nil {
                throw RuntimeError("Unknown function in format: \(name). Supported columns: \(FunctionPart.internalFunctions.joined(separator: ", "))")
            }
        }
    }

    var description: String {
        return "Function(name: \(name))"
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
        return "Group(parts: \(parts))"
    }

    static func == (lhs: FormatGroup, rhs: FormatGroup) -> Bool {
        return lhs.parts.map { $0.description } == rhs.parts.map { $0.description }
    }
}

struct ExecPart: FormatExpr {
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

    static func == (lhs: ExecPart, rhs: ExecPart) -> Bool {
        return lhs.command.description == rhs.command.description
    }
}

class Format {
    static let regex: NSRegularExpression = try! NSRegularExpression(pattern: "\\$\\{([%A-Za-z0-9_\\s]+)\\}")
    
    let original: String
    let format: any FormatExpr

    init(format: String) {
        self.original = format
        self.format = Format.parse(original).0
    }

    func validated(header: Header?) throws -> Format {
        try format.validate(header: header)
        return self
    }

    func fill(row: Row) -> String {
        // we rely on the fact that `fill` is called only after validation
        try! format.fill(row: row)
    }

    func fillData(row: Row) -> Data {
        fill(row: row).data(using: .utf8)!
    }

    static func parse(_ input: String, from start: String.Index? = nil, until closing: Character? = nil) -> (any FormatExpr, String.Index) {
        var index = start ?? input.startIndex
        var nodes: [any FormatExpr] = []
        var buffer = ""

        while index < input.endIndex {
            // Handle closing delimiter if needed
            if let closing = closing, input[index] == closing {
                if !buffer.isEmpty {
                    nodes.append(TextPart(buffer))
                }
                return (FormatGroup(nodes), input.index(after: index))
            }

            if input[index...].hasPrefix("${") {
                if !buffer.isEmpty {
                    nodes.append(TextPart(buffer))
                    buffer = ""
                }
                index = input.index(index, offsetBy: 2)
                let (name, newIndex) = readUntil(input, delimiter: "}", from: index)
                if let name = name {
                    nodes.append(VarPart(name))
                }
                index = newIndex

            } else if input[index...].hasPrefix("%{") {
                if !buffer.isEmpty {
                    nodes.append(TextPart(buffer))
                    buffer = ""
                }
                index = input.index(index, offsetBy: 2)
                let (name, newIndex) = readUntil(input, delimiter: "}", from: index)
                if let name = name {
                    nodes.append(FunctionPart(fnName: name))
                }
                index = newIndex
            } else if input[index...].hasPrefix("#{") {
                if !buffer.isEmpty {
                    nodes.append(TextPart(buffer))
                    buffer = ""
                }
                index = input.index(index, offsetBy: 2)
                let (inner, newIndex) = parse(input, from: index, until: "}")
                nodes.append(ExecPart(command: inner))
                index = newIndex

            } else {
                buffer.append(input[index])
                index = input.index(after: index)
            }
        }

        if !buffer.isEmpty {
            nodes.append(TextPart(buffer))
        }

        return (FormatGroup(nodes), index)
    }

    private static func readUntil(_ input: String, delimiter: Character, from start: String.Index) -> (String?, String.Index) {
        var index = start
        var result = ""

        while index < input.endIndex {
            if input[index] == delimiter {
                return (result, input.index(after: index))
            }
            result.append(input[index])
            index = input.index(after: index)
        }

        return (nil, index)
    }
}