extension Optional {
    func orThrow(_ errorExpression: @autoclosure () -> Error) throws -> Wrapped {
        switch self {
        case .some(let value):
            return value
        case .none:
            throw errorExpression()
        }
    }
}

extension String {
    func matches(_ regex: String) -> Bool {
        return self.range(of: regex, options: .regularExpression, range: nil, locale: nil) != nil
    }

    var isNumber: Bool {
        return self.matches("^-?[0-9]*$")
    }

}

extension Array {
    // appends optional element to array
    func with(_ x: Element?) -> Array {
        if let x {
            return self + [x]
        } else {
            return self
        }        
    }
}