import Foundation

// Structure representing a format tree
protocol FormatExpr: CustomStringConvertible {
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
        return "Var(\(name))"
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
    let arguments: [any FormatExpr]
    
    static let internalFunctions = ["header", "values", "quoted_values", "uuid", "random", "randomChoice"]
    static let regex: NSRegularExpression = try! NSRegularExpression(pattern: "\\$\\{([%A-Za-z0-9_\\s]+)\\}")

    init(name: String, arguments: [any FormatExpr] = []) {
        self.name = name
        self.arguments = arguments
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

        if name == "random" {
            let from = arguments.count == 1 ? try Int(arguments[0].fill(row: row))! : 0
            let to = arguments.count == 2 ? try Int(arguments[1].fill(row: row))! : try Int(arguments[0].fill(row: row))!            
            return String(Int.random(in: from...to))
        }

        if name == "randomChoice" {
            if arguments.isEmpty {
                throw RuntimeError("randomChoice function requires at least one argument")
            }
            let choices = try arguments.map { try $0.fill(row: row) }
            return choices.randomElement() ?? ""
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
                throw RuntimeError("Unknown function in format: \(name). Supported functions: \(FunctionPart.internalFunctions.joined(separator: ", "))")
            }

            if (name == "random") {
                if arguments.count < 0 {
                    throw RuntimeError("Function \(name) accepts one or two arguments. It should be either random(to) or random(from, to)")
                }

                if arguments.count > 2 {
                    throw RuntimeError("Function \(name) accepts at most two arguments, got \(arguments.count). It should be either random(to) or random(from, to)")
                }
            }

            if (name == "randomChoice") {
                if arguments.isEmpty { throw RuntimeError("Function \(name) requires at least one argument") }
            }
        }
    }

    var description: String {
        return "Fun(name: \(name), arguments: \(arguments))"
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
    let original: String
    let format: any FormatExpr

    init(format: String) {
        self.original = format
        let (nodes, _) = Format.parse(original)

        self.format = FormatGroup(nodes)
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

    static func parse(_ input: String, from start: String.Index? = nil, until terminators: Set<Character> = []) -> ([any FormatExpr], String.Index) {
        var index = start ?? input.startIndex
        var nodes: [any FormatExpr] = []
        var buffer = ""

        while index < input.endIndex {
            let char = input[index]

            if terminators.contains(char) {
                if !buffer.isEmpty { nodes.append(TextPart(buffer)); buffer = "" }
                return (nodes, input.index(after: index))
            }

            if input[index...].hasPrefix("${") {
                if !buffer.isEmpty { nodes.append(TextPart(buffer)); buffer = "" }
                index = input.index(index, offsetBy: 2)
                let (name, newIndex) = readUntil(input, from: index, delimiter: "}")
                if let name = name {
                    nodes.append(VarPart(name))
                }
                index = newIndex

            } else if input[index...].hasPrefix("%{") {
                if !buffer.isEmpty { nodes.append(TextPart(buffer)); buffer = "" }
                index = input.index(index, offsetBy: 2)
                let (funcNode, newIndex) = parseFunction(input, from: index)
                nodes.append(funcNode)
                index = newIndex

            } else if input[index...].hasPrefix("#{") {
                if !buffer.isEmpty { nodes.append(TextPart(buffer)); buffer = "" }
                index = input.index(index, offsetBy: 2)
                let (inner, newIndex) = parse(input, from: index, until: ["}"])
                nodes.append(ExecPart(command: FormatGroup(inner)))
                index = newIndex

            } else {
                buffer.append(char)
                index = input.index(after: index)
            }
        }

        if !buffer.isEmpty {
            nodes.append(TextPart(buffer))
        }

        return (nodes, index)
    }

    private static func parseFunction(_ input: String, from start: String.Index) -> (any FormatExpr, String.Index) {
        var index = start
        var name = ""

        while index < input.endIndex, input[index].isLetter || input[index].isNumber || input[index] == "_" {
            name.append(input[index])
            index = input.index(after: index)
        }

        skipWhitespace(input, &index)

        var args: [any FormatExpr] = []

        if index < input.endIndex, input[index] == "(" {
            index = input.index(after: index)
            while index < input.endIndex && input[index] != "}" {
                skipWhitespace(input, &index)

                if input[index] == ")" {
                    index = input.index(after: index)
                    break
                }

                let (argNodes, newIndex) = parse(input, from: index, until: [",", ")"])
                if argNodes.count == 1 {
                    args.append(argNodes[0])
                } else {
                    args.append(FormatGroup(argNodes))
                }

                index = newIndex
                if index < input.endIndex, input[index] == "," {
                    index = input.index(after: index)
                }
            }
        }

        guard index < input.endIndex, input[index] == "}" else {
            fatalError("Expected closing } for function")
        }

        return (FunctionPart(name: name, arguments: args), input.index(after: index))
    }    

    private static func readUntil(_ input: String, from start: String.Index, delimiter: Character) -> (String?, String.Index) {
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

    private static func skipWhitespace(_ input: String, _ index: inout String.Index) {
        while index < input.endIndex, input[index].isWhitespace {
            index = input.index(after: index)
        }
    }
}