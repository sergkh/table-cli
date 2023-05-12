import Foundation

protocol Table: Sequence<Row>, IteratorProtocol<Row> {
    var header: Header { get }
    mutating func next() -> Row? // TODO: remove me
}

struct TableConfig {
    let header: Header
    let headerPresent: Bool
    let type: FileType
    let delimeter: String
    let trim: Bool

    init(header: Header, headerPresent: Bool = true, type: FileType = .csv, delimeter: String = ",", trim: Bool = false) {
        self.header = header
        self.headerPresent = headerPresent
        self.type = type
        self.delimeter = delimeter
        self.trim = trim
    }
}

class ParsedTable: Table {    
    static let sqlHeaderPattern = "^[\\+-]{1,}$"
    var prereadRows: [String]
    let reader: LineReader
    let conf: TableConfig
    let header: Header

    private var line: Int = -1

    private init(reader: LineReader, conf: TableConfig, prereadRows: [String]) {
        self.reader = reader
        self.conf = conf
        self.prereadRows = prereadRows
        self.header = conf.header
    }

    deinit {
        reader.close()
    }    

    func nextLine() -> String? {
        if (prereadRows.isEmpty) {
            return reader.readLine()
        } else {
            return prereadRows.removeFirst()
        }        
    }

    func next() -> Row? {
        line += 1

        var row = nextLine()
        
        while row?.matches(ParsedTable.sqlHeaderPattern) ?? false {
            row = reader.readLine()
        }
        
        return row.map { row in 
            Row(
                header: conf.header,
                index:line, 
                data:row, 
                delimeter: conf.delimeter, 
                trim: conf.trim, 
                hasOuterBorders: conf.type == .sql) 
        }
    }

    static func empty() -> ParsedTable {
        ParsedTable(reader: ArrayLineReader([]), conf: TableConfig(header: Header.auto(size: 0)), prereadRows: [])
    }

    static func parse(path: String?, hasHeader: Bool?, headerOverride: Header?, delimeter: String?) throws -> ParsedTable {
        let file: FileHandle?
        
        if let path {
            file = try FileHandle(forReadingAtPath: path).orThrow(RuntimeError("File \(path) is not found"))
        } else {
            file = FileHandle.standardInput
        }    

        return try parse(reader: FileLineReader(fileHandle: file!), hasHeader: hasHeader, headerOverride: headerOverride, delimeter: delimeter)
    }

    static func parse(reader: LineReader, hasHeader: Bool?, headerOverride: Header?, delimeter: String?) throws -> ParsedTable {       
        if let (conf, prereadRows) = try ParsedTable.detectFile(reader:reader, hasHeader:hasHeader, headerOverride: headerOverride, delimeter: delimeter) {
            return ParsedTable(reader: reader, conf: conf, prereadRows: prereadRows)
        } else {
            return ParsedTable.empty()
        }
    }

    // Detects file type
    // Returns header (if present), file type, column delimeter and list of pre-read rows
    // Pre-read rows necessary for standard input where we can't rewind file back
    // TODO: has header is not yet used
    static func detectFile(reader: LineReader, hasHeader: Bool?, headerOverride: Header?, delimeter: String?) throws -> (TableConfig, [String])? {
        if let row = reader.readLine() {
            if row.matches(ParsedTable.sqlHeaderPattern) { // SQL table header used in MySQL/MariaDB like '+----+-------+'
                let parsedHeader = try reader.readLine().map { 
                    Header(data: $0, delimeter: "|", trim: true, hasOuterBorders: true) 
                }.orThrow(RuntimeError("Failed to parse SQL like header"))

                return (TableConfig(header: headerOverride ?? parsedHeader, type: FileType.sql, delimeter: "|", trim: true), [])
            } else if row.matches("^([A-Za-z_0-9\\s]+\\|\\s*)+[A-Za-z_0-9\\s]+$") { // Cassandra like header: name | name2 | name3
                let header = Header(data: row, delimeter: "|", trim: true, hasOuterBorders: false)
                return (TableConfig(header: headerOverride ?? header, type: FileType.cassandraSql, delimeter: "|", trim: true), [])
            } else { 
                let delimeters = delimeter.map{ [$0] } ?? [",", ";", "\t", " ", "|"]

                // Pre-read up to 2 rows and apply delimeter to the header and rows.
                // We choose the delimeter that gives more than 1 column and number of columns match for all rows
                let dataRows = [reader.readLine(), reader.readLine()].compactMap{$0}

                for d in delimeters {
                    let colsCount = row.components(separatedBy: d).count

                    if colsCount == 1 {
                        continue
                    }
            
                    let match = dataRows.allSatisfy { row in row.components(separatedBy: d).count == colsCount}

                    if match {
                        let header: Header = (hasHeader ?? true) ? Header(data: row, delimeter: d, trim: false, hasOuterBorders: false) : Header.auto(size: 1) // TODO: ???
                        let cachedRows = (hasHeader ?? true) ? dataRows : ([row] + dataRows)
                        return (TableConfig(header: headerOverride ?? header, type: FileType.csv, delimeter: d, trim: false), cachedRows)
                    }
                }

                // Treat as a single line file
                let header: Header = (hasHeader ?? true) ? Header(data: row, delimeter: delimeter ?? ",", trim: false, hasOuterBorders: false) : Header.auto(size: 1)
                return (TableConfig(header: headerOverride ?? header, type: FileType.csv, delimeter: delimeter ?? ",", trim: false), dataRows)          
            }
        } else {
            return nil // Empty file
        }
    }
}