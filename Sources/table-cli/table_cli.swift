import ArgumentParser
import Foundation

enum FileType: CaseIterable {
    case csv
    case sql
    case cassandraSql    
}

enum Errors: Error {
    case formatError(msg: String)
    case invalidFormat
    case notATable
    case fileNotFound(name: String)
}

class Format {
    static let regex = try! NSRegularExpression(pattern: "\\$\\{([A-Za-z0-9]+)\\}")
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
                    throw Errors.formatError(msg: "Unknown column in print format: \(v). Supported columns: \(h.data)")
                }
            }
        }

        return self
    }

    func fill(row: Row) -> String {
        var idx = 0
        var newStr = ""

        for v in vars {
            newStr += parts[idx] + row.colValue(columnName: v)!
            idx += 1
        }

        newStr += parts[idx]

        return newStr
    }

    func fillData(row: Row) -> Data {
        fill(row: row).data(using: .utf8)!
    }
}

class Filter {
    // TBD
}

class Header {
    let data: String
    let cols: [String]

    init(data: String, separator: String, trim: Bool) {
        self.data = data
        var components = data.components(separatedBy: separator)
        if (trim) {
            components = components.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        cols = components
    }

    func index(ofColumn: String) -> Int? {
        cols.firstIndex(of: ofColumn)
    }

    func asCsvData() -> Data { 
        cols.joined(separator: ",").data(using: .utf8)! 
    }
}

class Row {
    let index: Int
    let data: String
    var components: [String]
    let header: Header?

    init(header: Header?, index: Int, data: String, sep: String, trim: Bool) {
        self.header = header
        self.index = index
        self.data = data
        var components = data.components(separatedBy: sep)
        if (trim) {
            components = components.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        self.components = components
    }

    subscript(index: Int) -> String {
        components[index]
    }

    func asCsvData() -> Data { 
        components.joined(separator: ",").data(using: .utf8)! 
    }

    func colValue(columnName: String) -> String? {
        if let index = header?.index(ofColumn: columnName) {
            return components[index]
        } else {
            return nil
        }
    }
}

class LineReader {
    let fileHandle: FileHandle
    let bufferSize: Int = 1024
    var buffer: Data
    
    // TODO: use system wide delimeter
    static let newLine = "\n".data(using: .utf8)!

    init(fileHandle: FileHandle) {        
        self.fileHandle = fileHandle
        buffer = Data(capacity: bufferSize)
    }

    func readLine() -> String? {
        var rangeOfDelimiter = buffer.range(of: LineReader.newLine)
        
        while rangeOfDelimiter == nil {
            let chunk = fileHandle.readData(ofLength: bufferSize)
            
            if chunk.count == 0 {
                if buffer.count > 0 {
                    defer { buffer.count = 0 }                    
                    return String(data: buffer, encoding: .utf8)
                }
                
                return nil
            } else {
                buffer.append(chunk)
                rangeOfDelimiter = buffer.range(of: LineReader.newLine)
            }
        }
        
        let rangeOfLine = 0 ..< rangeOfDelimiter!.upperBound
        let line = String(data: buffer.subdata(in: rangeOfLine), encoding: .utf8)
        
        buffer.removeSubrange(rangeOfLine)
        
        return line?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func close() -> Void {
        fileHandle.closeFile()
    }
}

class Table: Sequence, IteratorProtocol {    
    static let sqlHeaderPattern = "^[\\+-]{1,}$"

    let reader: LineReader
    let header: Header?
    let delimeter: String
    let trim: Bool
    var type: FileType
    let prereadRows: [String]
    private var limit: Int?
    private var line: Int = -1

    private init(reader: LineReader, header: Header?, prereadRows: [String], type: FileType, delimeter: String, trim: Bool) {        
        self.reader = reader
        self.header = header
        self.prereadRows = prereadRows
        self.type = type
        self.delimeter = delimeter
        self.trim = trim
    }

    deinit {
        reader.close()
    }

    func limit(lines: Int) {
        self.limit = lines
    }

    func next() -> Row? {
        line += 1
        if (line >= limit ?? Int.max) {
            return nil
        }

        var row = reader.readLine()
        
        while row?.matches(Table.sqlHeaderPattern) ?? false {
            row = reader.readLine()
        }
        
        return row.map { row in Row(header: header, index:line, data:row, sep: delimeter, trim: trim) }
    }

    static func parse(path: String?, hasHeader: Bool?) throws -> Table {
        let file: FileHandle?
        
        if let path {
            file = try FileHandle(forReadingAtPath: path).orThrow(Errors.fileNotFound(name: path))
        } else {
            file = FileHandle.standardInput
        }    

        let reader = LineReader(fileHandle: file!)  // TODO: file check
        
        if let (header, type, delimeter, trim, rows) = Table.detectFile(reader:reader, hasHeader:hasHeader) {
            return Table(reader: reader, header: header, prereadRows: rows, type: type, delimeter: delimeter, trim: trim)
        } else {
            throw Errors.notATable
        }
    }

    // Detects file type
    // Returns header (if present), file type, column delimeter and list of pre-read rows
    // Pre-read rows necessary for standard input where we can't rewind file back
    static func detectFile(reader: LineReader, hasHeader: Bool?) -> (Header?, FileType, String, Bool, [String])? {
        if let row = reader.readLine() {            
            if row.matches(Table.sqlHeaderPattern) { // SQL table header used in MySQL/MariaDB like '+----+-------+'
                print("Detected SQL File")
                let header = reader.readLine().map { Header(data: $0, separator: "|", trim: true) }
                return (header, FileType.sql, "|", true, [])
            } else if row.matches("^([A-Za-z_0-9\\s]+\\|\\s*)*[A-Za-z_0-9\\s]+$") { // Cassandra like header: name | name2 | name3
                print("Detected Cassandra")
                let header = Header(data: row, separator: "|", trim: true)
                return (header, FileType.cassandraSql, "|", true, [])
            } else { 
                // TODO: detect CSV params
                print("Detected CSV")
                let header = Header(data: row, separator: ",", trim: false)
                return (header, FileType.csv, ",", false, [])
            }
        } else {
            return nil // Empty file
        }
    }
}

@main
struct MainApp: ParsableCommand {
    @Argument var inputFile: String?

    @Option(name: [.short, .customLong("output")], help: "Output file. Or stdout")
    var outputFile: String?
    
    @Flag(name: .customLong("skip-out-header"), help: "Do not print header in the output") 
    var skipOutHeader = false

    @Option(name: [.customLong("if"), .customLong("in-format")], help: "Output file. Or stdout")
    var inFormat: String?

    @Option(name: .customLong("limit"), help: "Process only up to specified number of lines")
    var limitLines: Int?

    @Option(name: [.customLong("print")], help: "Format output accorindg to format string. Use ${column name} to print column value. Example: Column1 value is ${column1}")
    var printFormat: String?

    // @Option(name: .shortAndLong, help: "Filter rows by value. Multiple filters can be set separated by comma. Example: country=UA or size>10")
    // var filter: String?

    @Option(name: .customLong("header"), help: "Override header. Columns should be specified separated by comma")
    var header: String?

    mutating func run() {
        do {
            let outHandle: FileHandle
            
            if let outFile = outputFile {
                outHandle = try FileHandle(forWritingAtPath: outFile).orThrow(Errors.fileNotFound(name: outFile))
            } else {
                outHandle = FileHandle.standardOutput
            }

            let table = try Table.parse(path: inputFile, hasHeader: nil)
            
            let newLine = "\n".data(using: .utf8)!

            var headerLines = 0

            if (!skipOutHeader) {
                if let header = table.header {
                    headerLines += 1 
                    outHandle.write(header.asCsvData())
                    outHandle.write(newLine)
                }            
            }

            if let limit = limitLines {
                table.limit(lines: limit - headerLines)
            }
        
            let formatOpt: Format?
            
            if let fmt = printFormat {
                formatOpt = try Format(format: fmt).validated(header: table.header)
            } else {
                formatOpt = nil
            }

            for row in table {
                if let rowFormat = formatOpt {
                    outHandle.write(rowFormat.fillData(row: row))
                } else {
                    outHandle.write(row.asCsvData())
                }
                
                outHandle.write(newLine)
            }
        } catch let error as Errors {
            print("Error: \(error)")
        } catch {
            print("Unknown error:")
        }
    }
}