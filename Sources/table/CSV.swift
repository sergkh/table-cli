class Csv {
  static func parseLine(_ line: String, delimeter: String) throws -> [String] {
      var chunks = [String]()
      var curChunkBuf = ""

      var idx = line.startIndex
      while(idx < line.endIndex) {
        let char = line[idx]    
        if char == "\"" {
          idx = line.index(after: idx) // skip quote

          if idx < line.endIndex {
            let quoteEnd = line[idx...].firstIndex(of: "\"") ?? line.endIndex
            curChunkBuf.append(contentsOf: line[idx..<quoteEnd])
            idx = quoteEnd
          } else {
            idx = line.endIndex
          }
        } else if char == delimeter.first { // TODO: fixme
          chunks.append(curChunkBuf)
          curChunkBuf = ""
        } else {
          curChunkBuf.append(char)
        }
        
        idx = line.index(after: idx)
      }

      chunks.append(curChunkBuf)
      return chunks
  }
}