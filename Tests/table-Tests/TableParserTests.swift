import XCTest
@testable import table

class TableParserTests: XCTestCase {

    // print(""); fflush(stdout)
    func testParseEmptyTable() throws {
        let emptyTable = try ParsedTable.parse(reader: ArrayLineReader(lines: []), hasHeader: nil, headerOverride: nil, delimeter: nil)
        XCTAssertEqual(emptyTable.conf.delimeter, ",")
        XCTAssertNil(try emptyTable.next())
    }

    func testParseOneColumnTable() throws {
        let oneLineTable = try ParsedTable.parse(reader: ArrayLineReader(lines: [ "1,2,3" ]), hasHeader: nil, headerOverride: nil, delimeter: nil)
        XCTAssertEqual(oneLineTable.header.columnsStr(), "1,2,3")
        XCTAssertNil(try oneLineTable.next())
    }

    // TODO: fix in accordance to https://www.rfc-editor.org/rfc/rfc4180
    func testRespectDelimeter() throws {
        let table = try ParsedTable.parse(reader: ArrayLineReader(lines: [
            "\"Column,1\",\"Column,2\"",
            "\"Val,1\",\"Val,2\""
        ]), hasHeader: nil, headerOverride: nil, delimeter: ",")
        XCTAssertEqual(table.header.components()[0], "Column,1")
        XCTAssertEqual(table.header.components()[1], "Column,2")
        
        let row = try table.next()!
        
        XCTAssertEqual(row.components[0].value, "Val,1")
        XCTAssertEqual(row.components[1].value, "Val,2")

    }
}
