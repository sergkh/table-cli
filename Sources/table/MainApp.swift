import ArgumentParser
import Foundation

struct Global {
    static var debug: Bool = false
}

func buildPrinter(formatOpt: Format?, outFileFmt: FileType, outputFile: String?) throws -> TablePrinter {    
    let outHandle: FileHandle

    if let outFile = outputFile {
        if (!FileManager.default.createFile(atPath: outFile, contents: nil, attributes: nil)) {
            throw RuntimeError("Unable to create output file \(outFile)")
        }
        outHandle = try FileHandle(forWritingAtPath: outFile).orThrow(RuntimeError("Output file \(outFile) is not found"))
    } else {
        outHandle = FileHandle.standardOutput
    }
    
    if let formatOpt {
        return CustomFormatTablePrinter(format: formatOpt, outHandle: outHandle)
    }

    if (outFileFmt == .table) {
        return PrettyTablePrinter(outHandle: outHandle)
    } else if (outFileFmt == .csv) {
        return CsvTablePrinter(delimeter: ",", outHandle: outHandle)
    } else {
        throw RuntimeError("Unsupported output format \(outFileFmt)")
    }
}

@main
struct MainApp: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "table",
        abstract: "A utility for transforming CSV files of SQL output.",
        discussion: """
            Examples:

              Print CSV data in the specified format:
              table in.csv --print "${name} ${last_name}: ${email}"

              Filter rows and display only specified columns:
              table in.csv --filter 'available>5' --columns 'item,available'
            """,
        version: appVersion     
    )

    @Argument var inputFile: String?

    @Option(name: [.short, .customLong("output")], help: "Output file. Or stdout by default.")
    var outputFile: String?

    @Option(name: .customLong("delimeter"), help: "CSV file delimeter. If not set the tool will try to detect delimeter automatically.")
    var delimeter: String?
    
    @Flag(name: .customLong("no-in-header"), help: "Input file does not have a header. Header can be set externally using --header option or will be automatically named as col1,col2 etc.")
    var noInHeader = false

    @Flag(name: .customLong("no-out-header"), help: "Do not print header in the output.") 
    var skipOutHeader = false

    @Flag(help: "Prints debug output") 
    var debug = false

    @Option(name: .customLong("header"), help: "Override header. Columns should be specified separated by comma.")
    var header: String?

    @Option(name: .customLong("columns"), help: "Speficies a comma separated list of columns to show in the output. Not compatible with --print.")
    var columns: String?    

    @Option(name: .customLong("skip"), help: "Skip a specified number of initial lines.")
    var skipLines: Int?

    @Option(name: .customLong("limit"), help: "Process only up to specified number of lines.")
    var limitLines: Int?

    @Option(name: [.customLong("print")], help: "Format output accorindg to format string. Use ${column name} to print column value. Example: Column1 value is ${column1}.")
    var printFormat: String?

    @Option(name: [.customLong("as")], help: "Prints output in the specified format. Supported formats: table (default) or csv.")
    var asFormat: String? 

    // TODO: Support complex or multiple filters?
    @Option(name: .shortAndLong, help: "Filter rows by a single value criteria. Example: country=UA or size>10. Supported comparison operations: '=' - equal,'!=' - not equal, < - smaller, <= - smaller or equal, > - bigger, >= - bigger or equal, '^=' - starts with, '$=' - ends with, '~=' - contains")
    var filter: String?

    // TODO: Support adding more than one column?
    @Option(name: .customLong("add"), help: "Adds a new column from a shell command output allowing to substitute other column values into it. Example: --add 'curl http://email-db.com/${email}'.")
    var addColumns: [String] = []

    @Option(name: .customLong("join"), help: "Speficies a second file path to join with the current one. Joining column is the first one for both tables or can be specified by the --on option.")
    var joinFile: String?

    @Option(name: .customLong("on"), help: "Speficies column names to join on. Requires --join option. Syntax {table1 column}={table 2 column}. Example: --on city_id=id")
    var joinCriteria: String?

    @Option(name: .customLong("sort"), help: "Sorts output by the specified columns. Example: --sort column1,column2. Use '!' prefix to sort in descending order.")
    var sortColumns: String?

    mutating func run() throws {
                
        if debug {
            Global.debug = true
            print("Debug enabled")
        }
        
        let headerOverride = header.map { Header(data: $0, delimeter: ",", trim: false, hasOuterBorders: false) }
        
        var table: any Table = try ParsedTable.parse(path: inputFile, hasHeader: !noInHeader, headerOverride: headerOverride, delimeter: delimeter)
        
        let filter = try filter.map { try Filter.compile(filter: $0, header: table.header) }

        if !addColumns.isEmpty {
            // TODO: add support of Dynamic Row values and move validation right before rendering
            let columns = try addColumns.enumerated().map { (index, element) in ("newColumn\(index + 1)", try Format(format: element).validated(header: table.header)) }
            table = NewColumnsTableView(table: table, additionalColumns: columns)
        }

        if let joinFile {
            table = JoinTableView(table: table, join: try Join.parse(joinFile, joinOn: joinCriteria, firstTable: table))
        }

        let formatOpt = try printFormat.map { try Format(format: $0).validated(header: table.header) }

        if let sortColumns {
            let expression = try Sort(sortColumns).validated(header: table.header)
            if (Global.debug) { 
                print("Sorting by columns: \(expression.columns.map { (name, order) in "\(name) \(order)" }.joined(separator: ","))") 
            }
            table = try InMemoryTableView(table: table).sort(expr: expression)
        }

        if let columns {
            let columns = columns.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            if (Global.debug) { print("Showing columns: \(columns.joined(separator: ","))") }
            try columns.forEach { if table.header.index(ofColumn: $0) == nil { throw RuntimeError("Column \($0) is not found in the table") } }
            table = ColumnsTableView(table: table, visibleColumns: columns)
        }

        let printer = try buildPrinter(formatOpt: formatOpt, outFileFmt: try FileType.outFormat(strFormat: asFormat), outputFile: outputFile)

        // when print format is set, header is not relevant anymore
        if !skipOutHeader {
            printer.writeHeader(header: table.header)
        }

        var skip = skipLines ?? 0
        var limit = limitLines ?? Int.max
        
        while let row = table.next() {
            if let filter {
                if !filter.apply(row: row) { continue }
            }

            if (skip > 0) {
                skip -= 1
                continue
            }
            
            if (limit == 0) { 
                break 
            }

            printer.writeRow(row: row)

            limit -= 1
        }

        printer.flush()
    }
}