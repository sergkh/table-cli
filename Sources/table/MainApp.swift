import ArgumentParser
import Foundation

struct Debug {
    // this one is set on start, so we don't care about concurrency checks
    nonisolated(unsafe) private static var debug: Bool = false
    private static let standardError = FileHandle.standardError
    private static let nl = "\n".data(using: .utf8)!

    static func enableDebug() {
        debug = true
        Debug.debug("Debug mode enabled")
    }

    static func debug(_ message: String) {
        if debug {            
            standardError.write(message.data(using: .utf8)!)
            standardError.write(nl)
        }
    }

    static func isDebugEnabled() -> Bool {
        return debug
    }
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
@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
struct MainApp: AsyncParsableCommand {    
    static let configuration = CommandConfiguration(
        commandName: "table",
        abstract: "A utility for transforming CSV files of SQL output.",
        discussion: """
            Examples:

              Print CSV data in the specified format:
              table in.csv --print "${name} ${last_name}: ${email}"

              Filter rows and display only specified columns:
              table in.csv --filter 'available>5' --columns 'item,available'.

              Some options like --add or --print support expressions that can be used to substitute column values or execute commands. Commands and functions also support nesting of expressions.
                - ${column_name} - substitutes column value. Example: ${name} will be substituted with the value of the 'name' column.
                - #{command} - executes bash command and substitutes its output. Example: #{echo "hello ${name}"}
                - %{function} - executes internal functions. Example %{distinct(${items})} Supported functions:
                    \(Functions.all.map { "\($0.description)" }.joined(separator: "\n\t"))
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

    @Flag(name: .customLong("debug"), help: "Prints debug output") 
    var debugEnabled = false

    @Option(name: .customLong("header"), help: "Override header. Columns should be specified separated by comma.")
    var header: String?

    @Option(name: .customLong("types"), help: "Optionally specify column types explicitly. If not set, the tool will try to detect types automatically. Example: --types string,number,date or in short form . Supported types: string, number, date, boolean.")
    var columnTypes: String?

    @Option(name: .customLong("columns"), help: "Speficies a comma separated list of columns to show in the output. Not compatible with --print.")
    var columns: String?    

    @Option(name: .customLong("skip"), help: "Skip a specified number of initial lines.")
    var skipLines: Int?

    @Option(name: .customLong("limit"), help: "Process only up to specified number of lines.")
    var limitLines: Int?

    @Option(name: [.customLong("print")], help: "Format output accorindg to format string. Use ${column name} to print column value. Expression #{cmd} can be used to execute command. Example: Column1 value is ${column1} and execution result #{curl service/${column2}}.")
    var printFormat: String?

    @Option(name: [.customLong("as")], help: "Prints output in the specified format. Supported formats: table (default) or csv.")
    var asFormat: String? 

    @Option(name: [.customShort("f"), .customLong("filter")], 
                help: ArgumentHelp(
                    "Filter rows by a single value criteria. Example: --filter 'country=UA',  --filter 'size>10'",
                    discussion: """
                        Supported comparison operations: '=' - equal,'!=' - not equal, < - smaller, <= - smaller or equal, > - bigger, >= - bigger or equal, '^=' - starts with, '$=' - ends with, '~=' - contains. 
                        To invert filter place ! before the filter expression, e.g. --filter '!country=UA' will return all rows where country is not equal to UA.
                        """)
                )
    var filters: [String] = []

    @Option(
        name: .customLong("add"), 
        help: ArgumentHelp(            
            "Adds a new column from a shell command output allowing to substitute other column values into it",
            discussion: "Example: --add 'col_name=#{curl http://email-db.com/${email}}'")
    )
    var addColumns: [String] = []

    @Option(name: .customLong("distinct"), help: "Returns only distinct values for the specified column set. Example: --distinct name,city_id.")
    var distinctColumns: [String] = []

    @Option(name: .customLong("duplicate"), help: "Outputs only duplicate rows by the specified columns. Example: --duplicate name,city_id will find duplicates by both name and city_id columns.")
    var duplicateColumns: [String] = []

    @Option(name: .customLong("group-by"), help: "Groups rows by the specified columns. Example: --group-by city_id,region.")
    var groupBy: [String] = []

    @Option(name: .customLong("join"), help: "Speficies a second file path to join with the current one. Joining column is the first one for both tables or can be specified by the --on option.")
    var joinFile: String?

    @Option(name: .customLong("on"), help: "Speficies column names to join on. Requires --join option. Syntax {table1 column}={table 2 column}. Example: --on city_id=id.")
    var joinCriteria: String?

    @Option(name: .customLong("sort"), help: "Sorts output by the specified columns. Example: --sort column1,column2. Use '!' prefix to sort in descending order.")
    var sortColumns: String?

    @Option(name: .customLong("sample"), help: "Samples percentage of the total rows. Example: --sample 50. Samples only half of the rows.")
    var sample: Int?

    @Option(name: .customLong("generate"), help: "Generates a sample empty table with the specified number of rows. Example: '--generate 1000 --add id=%{uuid}' will generate a table of UUIDs with 1000 rows.")
    var generate: Int?

    mutating func run() async throws {
                
        if debugEnabled {
            Debug.enableDebug()
        }
        
        let userTypes = try columnTypes.map { try CellType.fromStringList($0) }

        let headerOverride = header.map { try! Header(data: $0, delimeter: ",", trim: false, hasOuterBorders: false) }
        
        var table: any Table

        if let generate {
            if inputFile != nil {
                throw RuntimeError("Input file is not expected when generating rows. Use --generate without input file.")
            }
            debug("Generating \(generate) rows")
            table = ParsedTable.generated(rows: generate)
        } else {
            table = try ParsedTable.parse(path: inputFile, hasHeader: !noInHeader, headerOverride: headerOverride, delimeter: delimeter, userTypes: userTypes)
        }
        
        let parsedFilters = filters.isEmpty ? nil : try filters.map { try Filter.compile(filter: $0, header: table.header) }

        if !addColumns.isEmpty {
            // TODO: add support of Dynamic Row values and move validation right before rendering
            let columns = try addColumns.enumerated().map { (index, colDefinition) in
                let parts = colDefinition.split(separator: "=", maxSplits: 1)
                if (parts.count != 2) {
                    throw RuntimeError("Invalid add column format: '--add \(colDefinition)'. Expected format: col_name=format")
                }

                let colName = String(parts[0]).trimmingCharacters(in: CharacterSet.whitespaces)
                let formatStr = String(parts[1])

                debug("Adding a column: \(colName) with format: '\(formatStr)'")
            
                return (colName, try Format(format: formatStr).validated(header: table.header)) 
            }

            table = NewColumnsTableView(table: table, additionalColumns: columns)
        }

        if let joinFile {
            table = JoinTableView(table: table, join: try Join.parse(joinFile, joinOn: joinCriteria, firstTable: table))
        }

        if !distinctColumns.isEmpty {
            try distinctColumns.forEach { if table.header.index(ofColumn: $0) == nil { throw RuntimeError("Column \($0) in distinct clause is not found in the table") } }
            table = DistinctTableView(table: table, distinctColumns: distinctColumns)
        }

        if !duplicateColumns.isEmpty {
            try duplicateColumns.forEach { if table.header.index(ofColumn: $0) == nil { throw RuntimeError("Column \($0) in distinct clause is not found in the table") } }
            table = DuplicateTableView(table: table, duplicateColumns: duplicateColumns)
        }

        if !groupBy.isEmpty {
            try groupBy.forEach { if table.header.index(ofColumn: $0) == nil { throw RuntimeError("Column \($0) in group-by clause is not found in the table") } }
            table = GroupedTableView(table: table, groupBy: groupBy)
        }

        let formatOpt = try printFormat.map { try Format(format: $0).validated(header: table.header) }

        if let sortColumns {
            let expression = try Sort(sortColumns).validated(header: table.header)
            debug("Sorting by columns: \(expression.columns.map { (name, order) in "\(name) \(order)" }.joined(separator: ","))")             
            table = try InMemoryTableView(table: table).sort(expr: expression)
        }

        if let columns {
            let columns = columns.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            debug("Showing columns: \(columns.joined(separator: ","))")
            try columns.forEach { if table.header.index(ofColumn: $0) == nil { throw RuntimeError("Column \($0) in columns clause is not found in the table") } }
            table = ColumnsTableView(table: table, visibleColumns: columns)
        }

        if let sample {
            debug("Sampling \(sample)% of the rows")
            table = SampledTableView(table: table, percentage: sample)
        }

        let printer = try buildPrinter(formatOpt: formatOpt, outFileFmt: try FileType.outFormat(strFormat: asFormat), outputFile: outputFile)

        // when print format is set, header is not relevant anymore
        if !skipOutHeader {
            printer.writeHeader(header: table.header)
        }

        var skip = skipLines ?? 0
        var limit = limitLines ?? Int.max
        
        while let row = try table.next() {
            if let parsedFilters {
                if (!parsedFilters.allSatisfy { $0.apply(row: row) }) { 
                    continue 
                }
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