import ArgumentParser
import Foundation

@main
struct MainApp: ParsableCommand {
    @Argument var inputFile: String?

    @Option(name: [.short, .customLong("output")], help: "Output file. Or stdout")
    var outputFile: String?
    
    @Flag(name: .customLong("no-out-header"), help: "Do not print header in the output") 
    var skipOutHeader = false

    @Option(name: .customLong("limit"), help: "Process only up to specified number of lines")
    var limitLines: Int?

    @Option(name: [.customLong("print")], help: "Format output accorindg to format string. Use ${column name} to print column value. Example: Column1 value is ${column1}")
    var printFormat: String?

    @Option(name: .customLong("delimeter"), help: "CSV file delimeter. If not set app will try to detect delimeter automatically")
    var delimeter: String?

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

            let headerOverride = header.map { ParsedHeader(data: $0, delimeter: ",", trim: false, hasOuterBorders: false) }

            let table = try Table.parse(path: inputFile, hasHeader: nil, headerOverride: headerOverride, delimeter: delimeter)
            
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
            print("Error: \(error)")
        } catch {
            print("Unknown error:")
        }
    }
}