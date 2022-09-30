enum Errors: Error {
  case formatError(msg: String)
  case notATable
  case fileNotFound(name: String)
}