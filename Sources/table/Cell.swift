class Cell {
  private var computedValue: String?
  private let computeValue: () -> String

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

  init(value: String) {
    self.computedValue = value
    self.computeValue = { value }
  }

  init(fn: @escaping () -> String) {
    self.computeValue = fn
    self.computedValue = nil
  }
}
