import Foundation

class Format {
    static let regex = try! NSRegularExpression(pattern: "\\$\\{([%A-Za-z0-9_\\s]+)\\}")
    static let internalVars = ["%header", "%values", "%quoted_values", "%uuid"]
    let format: String
    let matches: [NSTextCheckingResult]
    let parts: [String]
    let vars: [String]

    init(format: String) {
        self.format = format
        let range = NSRange(format.startIndex..., in: format)
        matches = Format.regex.matches(in: format, range: range)

        var variables: [String] = []
        var strParts: [String] = []
        
        var lastIndex = format.startIndex

        // Break matches into 2 arrays text parts and variable names
        for match in matches {        
            let range = lastIndex..<format.index(format.startIndex, offsetBy: match.range.lowerBound)
            variables.append(String(format[Range(match.range(at: 1), in: format)!]))
            strParts.append(String(format[range]))
            lastIndex = format.index(format.startIndex, offsetBy: match.range.upperBound)
        }

        strParts.append(String(format[lastIndex...]))

        parts = strParts
        vars = variables
    }

    func validated(header: Header?) throws -> Format {
        if let h = header {
            for v in vars {
                if h.index(ofColumn: v) == nil && !Format.internalVars.contains(v) {
                    throw RuntimeError("Unknown column in print format: \(v). Supported columns: \(h.columnsStr())")
                }
            }
        }

        return self
    }

    // Format allows to specify initial column values as well as dynamically formed columns
    func fill(row: Row) -> String {
        var idx = 0
        var newStr = ""

        for v in vars {
            newStr += parts[idx] + columnValue(row: row, name: v)
            idx += 1
        }

        newStr += parts[idx]

        return newStr
    }

    func fillData(row: Row) -> Data {
        fill(row: row).data(using: .utf8)!
    }

    func columnValue(row: Row, name: String) -> String {
        if let v = resolveInternalVariable(row, name) {
            return v
        }

        if let v = row[name] {
            return v
        }

        return ""
    }

    func resolveInternalVariable(_ row: Row, _ name: String) -> String? {
        if name == "%header" {
            return row.header?.columnsStr()
        }

        if name == "%values" {
            return row.components.map({ $0.value }).joined(separator: ",")
        }

        if name == "%uuid" {
            return UUID().uuidString
        }

        if name == "%quoted_values" {
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

        return nil
    }
}