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
        asDate != nil
    }

    var isBoolean: Bool {
        return self.caseInsensitiveCompare("true") == .orderedSame || self.caseInsensitiveCompare("false") == .orderedSame
    }

    var boolValue: Bool {
        return self.caseInsensitiveCompare("true") == .orderedSame
    }

    var asDate: Date? {
        let formats = ["yyyy-MM-dd", "yyyy-MM-dd HH:mm:ss"]
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: 
                    self.replacingOccurrences(of: "T", with: " ")
                        .replacingOccurrences(of: "'", with: "")
                        .replacingOccurrences(of: "\"", with: "")) {
                return date
            }
        }
        
        return nil
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