import Foundation

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