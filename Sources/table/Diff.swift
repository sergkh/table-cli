import Foundation

enum DiffMode: String {
    case left = "left"
    case right = "right"
    case both = "both"
    
    static func fromString(_ str: String) throws -> DiffMode {
        guard let mode = DiffMode(rawValue: str.lowercased()) else {
            throw RuntimeError("Invalid diff mode: \(str). Supported modes: left, right, both. Default is both.")
        }
        return mode
    }
}

class Diff {
    let firstColumn: String
    let secondColumn: String
    let secondColIndex: Int
    let matchTable: ParsedTable
    let mode: DiffMode
    
    var loaded: Bool = false
    var rowsCache: Set<String> = []
    // Store all rows from second table for right/both modes
    var secondTableRows: [Row] = []
    
    init(firstColumn: String, secondColumn: String, matchTable: ParsedTable, mode: DiffMode) throws {
        self.firstColumn = firstColumn
        self.secondColumn = secondColumn
        self.matchTable = matchTable
        self.mode = mode
        self.secondColIndex = try matchTable.header.index(ofColumn: secondColumn).orThrow(RuntimeError("Column \(secondColumn) is not found in second table"))
        
        debug("Diffing tables on columns \(firstColumn)=\(secondColumn) with mode: \(mode.rawValue)")
    }
    
    func exists(row: Row) -> Bool {
        guard let columnValue = row[firstColumn] else {
            return false
        }
        return rowsCache.contains(columnValue)
    }
    
    func load() throws -> Diff {
        while let r = try matchTable.next() {
            let colValue = r[secondColIndex]
            rowsCache.insert(colValue)
            // Store rows for right/both modes
            if mode == .right || mode == .both {
                secondTableRows.append(r)
            }
        }
        
        loaded = true
        debug("Loaded \(rowsCache.count) rows from second table for diff")
        
        return self
    }
    
    static func parse(_ file: String, diffOn: String?, noInHeader: Bool, firstTable: any Table, mode: String?) throws -> Diff {
        let matchTable = try ParsedTable.parse(path: file, hasHeader: !noInHeader, headerOverride: nil, delimeter: nil, userTypes: nil)
        return try parse(matchTable, diffOn: diffOn, firstTable: firstTable, mode: mode)
    }
    
    static func parse(_ matchTable: ParsedTable, diffOn: String?, firstTable: any Table, mode: String?) throws -> Diff {
        let (first, second) = try diffOn.map { diffExpr in
            let components = diffExpr.components(separatedBy: "=")
            
            if components.count != 2 {
                throw RuntimeError("Diff expression should have format: table1_column=table2_column")
            }
            
            let firstCol = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let secondCol = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Validate columns exist
            if firstTable.header.index(ofColumn: firstCol) == nil {
                throw RuntimeError("Column \(firstCol) is not found in first table")
            }
            
            if matchTable.header.index(ofColumn: secondCol) == nil {
                throw RuntimeError("Column \(secondCol) is not found in second table")
            }
            
            return (firstCol, secondCol)
        } ?? {
            let firstCol = firstTable.header[0]
            let secondCol = matchTable.header[0]
            return (firstCol, secondCol)
        }()
        
        let diffMode = try mode.map { try DiffMode.fromString($0) } ?? .both
        
        return try Diff(
            firstColumn: first,
            secondColumn: second,
            matchTable: matchTable,
            mode: diffMode
        ).load()
    }
}

