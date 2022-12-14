import ArgumentParser
import Foundation

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

    // TODO: Support complex or multiple filters?
    @Option(name: .shortAndLong, help: "Filter rows by value. Example: country=UA or size>10.")
    var filter: String?

    // TODO: Support adding more than one column?
    @Option(name: .customLong("add"), help: "Adds a new column from a shell command output allowing to substitute other column values into it. Example: --add 'curl http://email-db.com/${email}'.")
    var addColumn: String?

    mutating func run() throws {
        let outHandle: FileHandle
        
        if let outFile = outputFile {
            if (!FileManager.default.createFile(atPath: outFile, contents: nil, attributes: nil)) {
                throw RuntimeError("Unable to create output file \(outFile)")
            }
            outHandle = try FileHandle(forWritingAtPath: outFile).orThrow(RuntimeError("Output file \(outFile) is not found"))
        } else {
            outHandle = FileHandle.standardOutput
        }

        let headerOverride = header.map { ParsedHeader(data: $0, delimeter: ",", trim: false, hasOuterBorders: false) }
        let table = try Table.parse(path: inputFile, hasHeader: !noInHeader, headerOverride: headerOverride, delimeter: delimeter)
        
        let filter = try filter.map { try Filter.compile(filter: $0, header: table.header ?? AutoHeader.shared) }

        var mapper = try columns.map { try ColumnsMapper.parse(cols: $0, header: table.header ?? AutoHeader.shared) }

        if let addColumn {
            mapper = try (mapper ?? ColumnsMapper()).addColumn(name: "newCol1", valueProvider: try Format(format: addColumn).validated(header: table.header))
        }

        let formatOpt = try printFormat.map { try Format(format: $0).validated(header: table.header) }

        let newLine = "\n".data(using: .utf8)!

        // when print format is set, header is not relevant anymore
        if !skipOutHeader && printFormat == nil {
            if let header = table.header {
                let mappedHeader = mapper.map { $0.map(header: header) } ?? header
                outHandle.write(mappedHeader.asCsvData())
                outHandle.write(newLine)
            }
        }

        var skip = skipLines ?? 0
        var limit = limitLines ?? Int.max

        for row in table {
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

            let mappedRow = mapper.map { $0.map(row: row) } ?? row

            if let rowFormat = formatOpt {
                outHandle.write(rowFormat.fillData(rows: [row, mappedRow]))
            } else {                
                outHandle.write(mappedRow.asCsvData())
            }
            
            outHandle.write(newLine)
            limit -= 1
        }
    }
}