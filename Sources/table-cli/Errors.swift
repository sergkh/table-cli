enum Errors: Error {
  case formatError(msg: String)
  case invalidFormat
  case notATable
  case fileNotFound(name: String)
}