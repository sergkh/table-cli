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
            """,
        version: appVersion     
    )

    @Argument var inputFile: String?

    @Option(name: [.short, .customLong("output")], help: "Output file. Or stdout by default.")
    var outputFile: String?
    
    @Flag(name: .customLong("no-in-header"), help: "Input file does not have a header. Header can be set externally using --header option or will be automatically named as col1,col2 etc.")
    var noInHeader = false

    @Flag(name: .customLong("no-out-header"), help: "Do not print header in the output.") 
    var skipOutHeader = false

    @Option(name: .customLong("limit"), help: "Process only up to specified number of lines.")
    var limitLines: Int?

    @Option(name: [.customLong("print")], help: "Format output accorindg to format string. Use ${column name} to print column value. Example: Column1 value is ${column1}.")
    var printFormat: String?

    @Option(name: .customLong("delimeter"), help: "CSV file delimeter. If not set app will try to detect delimeter automatically/")
    var delimeter: String?

    // @Option(name: .shortAndLong, help: "Filter rows by value. Multiple filters can be set separated by comma. Example: country=UA or size>10")
    // var filter: String?

    @Option(name: .customLong("header"), help: "Override header. Columns should be specified separated by comma.")
    var header: String?

    mutating func run() {
        do {
            let outHandle: FileHandle
            
            if let outFile = outputFile {
                outHandle = try FileHandle(forWritingAtPath: outFile).orThrow(Errors.fileNotFound(name: outFile))
            } else {
                outHandle = FileHandle.standardOutput
            }

            let headerOverride = header.map { ParsedHeader(data: $0, delimeter: ",", trim: false, hasOuterBorders: false) }
            let table = try Table.parse(path: inputFile, hasHeader: !noInHeader, headerOverride: headerOverride, delimeter: delimeter)
            
            let newLine = "\n".data(using: .utf8)!

            var headerLines = 0

            // when print format is set, header is not relevant anymore
            if !skipOutHeader && printFormat == nil {
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
            switch error {
                case .fileNotFound(let name): 
                    stdErrPrint("File '\(name)' is not found\n")
                case .formatError(let error): 
                    stdErrPrint("File format error: \(error)\n")
                default: 
                    stdErrPrint("Unknown error happened\n")
            }
            
        } catch {
            stdErrPrint("Program failed: \(error)\n")
        }
    }

    func stdErrPrint(_ msg: String) {
        let stderr = FileHandle.standardError
        stderr.write(msg.data(using: .utf8)!)
    }
}