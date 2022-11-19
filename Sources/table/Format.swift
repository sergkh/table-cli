import Foundation

class Format {
    static let regex = try! NSRegularExpression(pattern: "\\$\\{([A-Za-z0-9_\\s]+)\\}")
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
                if h.index(ofColumn: v) == nil {
                    throw RuntimeError("Unknown column in print format: \(v). Supported columns: \(h.columnsStr())")
                }
            }
        }

        return self
    }

    func columnValue(rows: [Row], name: String) -> String {
        for r in rows {
            if let v = r[name] {
                return v
            }
        }
        return ""
    }

    // Format allows to specify initial column values as well as 
    // dynamically formed columns
    func fill(rows: [Row]) -> String {
        var idx = 0
        var newStr = ""

        for v in vars {
            newStr += parts[idx] + columnValue(rows: rows, name: v)
            idx += 1
        }

        newStr += parts[idx]

        return newStr
    }

    func fillData(rows: [Row]) -> Data {
        fill(rows: rows).data(using: .utf8)!
    }
}