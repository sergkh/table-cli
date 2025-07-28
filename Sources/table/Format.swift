import Foundation


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
                if !buffer.isEmpty { nodes.append(TextExpr(buffer)); buffer = "" }
                return (nodes, input.index(after: index))
            }

            if input[index...].hasPrefix("${") {
                if !buffer.isEmpty { nodes.append(TextExpr(buffer)); buffer = "" }
                index = input.index(index, offsetBy: 2)
                let (name, newIndex) = readUntil(input, from: index, delimiter: "}")
                if let name = name {
                    nodes.append(VarExpr(name))
                }
                index = newIndex

            } else if input[index...].hasPrefix("%{") {
                if !buffer.isEmpty { nodes.append(TextExpr(buffer)); buffer = "" }
                index = input.index(index, offsetBy: 2)
                let (funcNode, newIndex) = parseFunction(input, from: index)
                nodes.append(funcNode)
                index = newIndex

            } else if input[index...].hasPrefix("#{") {
                if !buffer.isEmpty { nodes.append(TextExpr(buffer)); buffer = "" }
                index = input.index(index, offsetBy: 2)
                let (inner, newIndex) = parse(input, from: index, until: ["}"])
                nodes.append(ExecExpr(command: FormatGroup(inner)))
                index = newIndex

            } else {
                buffer.append(char)
                index = input.index(after: index)
            }
        }

        if !buffer.isEmpty {
            nodes.append(TextExpr(buffer))
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

        return (FunctionExpr(name: name, arguments: args), input.index(after: index))
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