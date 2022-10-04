import Foundation

struct TableConfig {
    let header: Header?
    let type: FileType
    let delimeter: String
    let trim: Bool
}

class Table: Sequence, IteratorProtocol {    
    static let sqlHeaderPattern = "^[\\+-]{1,}$"
    var prereadRows: [String]
    let reader: LineReader
    let conf: TableConfig
    var header: Header? {
        get { conf.header }
    }
    
    private var limit = Int.max
    private var line: Int = -1

    private init(reader: LineReader, conf: TableConfig, prereadRows: [String]) {
        self.reader = reader
        self.conf = conf
        self.prereadRows = prereadRows
    }

    deinit {
        reader.close()
    }

    func offset(lines: Int) {
        for _ in 1...lines {
            let _ = nextLine()
        }
    }

    func limit(lines: Int) {
        self.limit = lines
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

        if (line >= limit) {
            return nil        
        }

        var row = nextLine()
        
        while row?.matches(Table.sqlHeaderPattern) ?? false {
            row = reader.readLine()
        }
        
        return row.map { row in 
            Row(
                header: conf.header ?? AutoHeader.shared,
                index:line, 
                data:row, 
                delimeter: conf.delimeter, 
                trim: conf.trim, 
                hasOuterBorders: conf.type == .sql) 
        }
    }

    static func parse(path: String?, hasHeader: Bool?, headerOverride: Header?, delimeter: String?) throws -> Table {
        let file: FileHandle?
        
        if let path {
            file = try FileHandle(forReadingAtPath: path).orThrow(RuntimeError("File \(path) is not found"))
        } else {
            file = FileHandle.standardInput
        }    

        let reader = LineReader(fileHandle: file!)
        
        if let (conf, prereadRows) = Table.detectFile(reader:reader, hasHeader:hasHeader, headerOverride: headerOverride, delimeter: delimeter) {
            return Table(reader: reader, conf: conf, prereadRows: prereadRows)
        } else {
            throw RuntimeError("Table type detection failed. Try specifying delimeter")
        }
    }

    // Detects file type
    // Returns header (if present), file type, column delimeter and list of pre-read rows
    // Pre-read rows necessary for standard input where we can't rewind file back
    // TODO: has header is not yet used
    static func detectFile(reader: LineReader, hasHeader: Bool?, headerOverride: Header?, delimeter: String?) -> (TableConfig, [String])? {
        if let row = reader.readLine() {            
            if row.matches(Table.sqlHeaderPattern) { // SQL table header used in MySQL/MariaDB like '+----+-------+'
                let header = reader.readLine().map { ParsedHeader(data: $0, delimeter: "|", trim: true, hasOuterBorders: true) }
                return (TableConfig(header: headerOverride ?? header, type: FileType.sql, delimeter: "|", trim: true), [])
            } else if row.matches("^([A-Za-z_0-9\\s]+\\|\\s*)+[A-Za-z_0-9\\s]+$") { // Cassandra like header: name | name2 | name3
                let header = ParsedHeader(data: row, delimeter: "|", trim: true, hasOuterBorders: false)
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
                        let header = (hasHeader ?? true) ? ParsedHeader(data: row, delimeter: d, trim: false, hasOuterBorders: false) : nil
                        let cachedRows = (hasHeader ?? true) ? dataRows : ([row] + dataRows)
                        return (TableConfig(header: headerOverride ?? header, type: FileType.csv, delimeter: d, trim: false), cachedRows)
                    }
                }

                // Treat as a single line file
                let header = ParsedHeader(data: row, delimeter: delimeter ?? ",", trim: false, hasOuterBorders: false)
                return (TableConfig(header: headerOverride ?? header, type: FileType.csv, delimeter: delimeter ?? ",", trim: false), dataRows)          
            }
        } else {
            return nil // Empty file
        }
    }
}