import Foundation

protocol Table: Sequence<Row>, IteratorProtocol<Row> {
    var header: Header { get }
    mutating func next() -> Row?
}

protocol InMemoryTable: Table {
    func rewind()
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
    static let sqlHeaderPattern = "^[\\+\\-]{1,}$"
    static let ownHeaderPattern = "^╭[\\┬─]{1,}╮$"
    static let technicalRowPattern = "^[\\+\\-╭┬╮├┼┤─╰┴╯]{1,}$"
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

        while ParsedTable.technicalRow(row) {
            row = reader.readLine()
        }

        return try! row.map { row in 
            let components = try ParsedTable.readRowComponents(row, type: conf.type, delimeter: conf.delimeter, trim: conf.trim)

            return Row(
                header: conf.header,
                index:line, 
                components: components
            ) 
        }
    } 

    static func empty() -> ParsedTable {
        return ParsedTable(reader: ArrayLineReader(lines: []), conf: TableConfig(header: Header.auto(size: 0)), prereadRows: [])
    }

    static func generated(rows: Int) -> ParsedTable {        
        return ParsedTable(reader: GeneratedLineReader(lines: rows), conf: TableConfig(header: Header.auto(size: 0)), prereadRows: [])
    }

    static func fromArray(_ data: [[String]], header: [String]? = nil) -> ParsedTable {
        let types = CellType.infer(rows: data)
        let parsedHeader = header.map { Header(components: $0, types: types) } ?? Header.auto(size: data.count)        
        return ParsedTable(reader: ArrayLineReader(components: data), conf: TableConfig(header: parsedHeader), prereadRows: [])
    }

    static func parse(path: String?, hasHeader: Bool?, headerOverride: Header?, delimeter: String?, userTypes: [CellType]?) throws -> ParsedTable {
        let file: FileHandle?
        
        if let path {
            file = try FileHandle(forReadingAtPath: path).orThrow(RuntimeError("File \(path) is not found"))
        } else {
            
            if (isatty(fileno(stdin)) != 0) {
                throw RuntimeError("No input file provided and standard input is not a terminal. Use --input to specify a file or --generate to generate rows.")
            }

            file = FileHandle.standardInput
        }    

        return try parse(reader: FileLineReader(fileHandle: file!), hasHeader: hasHeader, headerOverride: headerOverride, delimeter: delimeter, userTypes: userTypes)
    }

    static func parse(reader: LineReader, hasHeader: Bool?, headerOverride: Header? = nil, delimeter: String? = nil, userTypes: [CellType]? = nil) throws -> ParsedTable {       
        if let (conf, prereadRows) = try ParsedTable.detectFile(reader:reader, hasHeader:hasHeader, headerOverride: headerOverride, delimeter: delimeter, userTypes: userTypes) {
            return ParsedTable(reader: reader, conf: conf, prereadRows: prereadRows)
        } else {
            return ParsedTable.empty()
        }
    }

    // Detects file type
    // Returns header (if present), file type, column delimeter and list of pre-read rows
    // Pre-read rows necessary for standard input where we can't rewind file back
    // TODO: has header is not yet used
    static func detectFile(reader: LineReader, hasHeader: Bool?, headerOverride: Header?, delimeter: String?, userTypes: [CellType]?) throws -> (TableConfig, [String])? {
        if let row = reader.readLine() {
            if row.matches(ParsedTable.ownHeaderPattern) {
                debug("Detected tool own table format")
                let parsedHeader = try reader.readLine().map { 
                    try! Header(data: $0, delimeter: "│", trim: true, hasOuterBorders: true) 
                }.orThrow(RuntimeError("Failed to parse own table header"))

                let dataRows = [reader.readLine(), reader.readLine(), reader.readLine()].compactMap{$0}.filter { !ParsedTable.technicalRow($0) }
                let types = userTypes ?? CellType.infer(rows: dataRows.map { try! ParsedTable.readRowComponents($0, type: .cassandraSql, delimeter: "|", trim: true) })
                let header = (headerOverride ?? parsedHeader).withTypes(types)

                return (TableConfig(header: header, type: FileType.table, delimeter: "│", trim: true), dataRows)
            } else if row.matches(ParsedTable.sqlHeaderPattern) { // SQL table header used in MySQL/MariaDB like '+----+-------+'
                debug("Detected SQL like table format")

                let parsedHeader = try reader.readLine().map { 
                    try! Header(data: $0, delimeter: "|", trim: true, hasOuterBorders: true) 
                }.orThrow(RuntimeError("Failed to parse SQL like header"))

                let dataRows = [reader.readLine(), reader.readLine(), reader.readLine()].compactMap{$0}.filter { !ParsedTable.technicalRow($0) }
                let types = userTypes ?? CellType.infer(rows: dataRows.map { try! ParsedTable.readRowComponents($0, type: .sql, delimeter: "|", trim: true) })
                let header = (headerOverride ?? parsedHeader).withTypes(types)

                return (TableConfig(header: header, type: FileType.sql, delimeter: "|", trim: true), dataRows)
            } else if row.matches("^([A-Za-z_0-9\\s]+\\|\\s*)+[A-Za-z_0-9\\s]+$") { // Cassandra like header: name | name2 | name3
                debug("Detected Cassandra like table format")

                let dataRows = [reader.readLine(), reader.readLine(), reader.readLine()].compactMap{$0}.filter { !ParsedTable.technicalRow($0) }
                let types = userTypes ?? CellType.infer(rows: dataRows.map { try! ParsedTable.readRowComponents($0, type: .cassandraSql, delimeter: "|", trim: true) })

                let header =  try! (headerOverride ?? Header(data: row, delimeter: "|", trim: true, hasOuterBorders: false, types: types)).withTypes(types)
                return (TableConfig(header: header, type: FileType.cassandraSql, delimeter: "|", trim: true), dataRows)
            } else {
                debug("Detected CSV like table format")
                let delimeters = delimeter.map{ [$0] } ?? [",", ";", "\t", " ", "|"]

                // Pre-read up to 2 rows and apply delimeter to the header and rows.
                // We choose the delimeter that gives more than 1 column and number of columns match for all rows
                let dataRows = [reader.readLine(), reader.readLine()].compactMap{$0}

                for d in delimeters {
                    let colsCount = try Csv.parseLine(row, delimeter: d).count

                    if colsCount == 1 {
                        continue
                    }

                    debug("Found delimeter '\(d)'")

                    if try! dataRows.allSatisfy({ (try Csv.parseLine($0, delimeter: d).count) == colsCount}) {
                        let readHeader: Header = try! (hasHeader ?? true) ? Header(data: row, delimeter: d, trim: false, hasOuterBorders: false) : Header.auto(size: 1)
                        debug("Detected as CSV format with header separated by '\(d)' with \(colsCount) columns")
                        
                        let cachedRows = (hasHeader ?? true) ? dataRows : ([row] + dataRows)
                        let types = CellType.infer(rows: cachedRows.map { try! Csv.parseLine($0, delimeter: d) })                    
                        let header = (headerOverride ?? readHeader).withTypes(types)

                        return (TableConfig(header: header, type: FileType.csv, delimeter: d, trim: false), cachedRows)
                    } else {
                        debug("Columns count mismatch")
                    }
                }

                debug("Detected as headless file")
                // Treat as a single line file
                let header: Header = (hasHeader ?? true) ? try! Header(data: row, delimeter: delimeter ?? ",", trim: false, hasOuterBorders: false) : Header.auto(size: 1)
                return (TableConfig(header: headerOverride ?? header, type: FileType.csv, delimeter: delimeter ?? ",", trim: false), dataRows)          
            }
        } else {
            return nil // Empty file
        }
    }

    private static func readRowComponents(_ row: String, type: FileType, delimeter: String, trim: Bool) throws -> [String] {
        if type == .csv {
            return try! Csv.parseLine(row, delimeter: delimeter)
        } 
        
        var components = row.components(separatedBy: delimeter)

        if trim {
            components = components.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        }

        if FileType.hasOuterBorders(type: type) {
            components = components.dropFirst().dropLast()
        }

        return components
    }

        // matches rows that has to be skipped, usually horizontal delimeters
    private static func technicalRow(_ str: String?) -> Bool {
        return str?.matches(ParsedTable.technicalRowPattern) ?? false
    }
}