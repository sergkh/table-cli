import Foundation

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
        if let _ = Double(self) {
            return true
        }
        return false
    }

    var isDate: Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss" // Adjust as needed for your date format
        return dateFormatter.date(from: self.replacingOccurrences(of: "T", with: " ")) != nil
    }

    var isBoolean: Bool {
        return self.caseInsensitiveCompare("true") == .orderedSame || self.caseInsensitiveCompare("false") == .orderedSame
    }

    var boolValue: Bool {
        return self.caseInsensitiveCompare("true") == .orderedSame
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

extension Table {
    func memoized() -> InMemoryTableView {
        if self is InMemoryTableView {
            return self as! InMemoryTableView
        } else {
            return InMemoryTableView(table: self)
        }
    }
}

func debug(_ message: String) {
    Debug.debug(message)
}