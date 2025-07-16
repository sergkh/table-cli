import XCTest
@testable import table

class FormatTests: XCTestCase {
    let row = Row(
        header: Header(components: ["str1", "str2", "num1", "num2"], types: [.string, .string, .number, .number]),
        index: 0, 
        components: ["val1", "val2", "150", "200"]
    )

    func testStringFormat() throws {
        let format = try Format(format: "Hello").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "Hello")        
    }

    func testSimpleVarsSubstitution() throws {
        let format = try Format(format: "String here: ${str1} and here: ${str2}").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "String here: val1 and here: val2")
    }

    func testIgnoreEscaped() throws {
        let format = try Format(format: "String here: ${str1} and here: ${str2}").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "String here: val1 and here: val2")
    }
}
