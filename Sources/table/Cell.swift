class Cell {
  private var computedValue: String?
  private let computeValue: () -> String
  public let type: CellType

  public var value: String {
    get {
      if let computedValue = computedValue {
        return computedValue
      } else {
        computedValue = computeValue()      
        return computedValue!
      }
    }
  }

  public var description: String { return value }

  init(value: String, type: CellType = .string) {
    self.computedValue = value
    self.computeValue = { value }
    self.type = type
  }

  init(fn: @escaping () -> String, type: CellType = .string) {
    self.computeValue = fn
    self.computedValue = nil
    self.type = type
  }
}
