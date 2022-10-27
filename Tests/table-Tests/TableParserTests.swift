import XCTest
@testable import table

class TableParserTests: XCTestCase {

    // print(""); fflush(stdout)
    func testParseEmptyTable() throws {
        let emptyTable = try Table.parse(reader: ArrayLineReader(), hasHeader: nil, headerOverride: nil, delimeter: nil)
        XCTAssertEqual(emptyTable.conf.delimeter, ",")
        XCTAssertNil(emptyTable.next())
    }

    func testParseOneColumnTable() throws {
        let oneLineTable = try Table.parse(reader: ArrayLineReader([ "1,2,3" ]), hasHeader: nil, headerOverride: nil, delimeter: nil)
        XCTAssertEqual(oneLineTable.header.columnsStr(), "1,2,3")
        XCTAssertNil(oneLineTable.next())
    }

    func testRespectDelimeter() throws {
        let oneLineTable = try Table.parse(reader: ArrayLineReader([ "Column,1; Column2" ]), hasHeader: nil, headerOverride: nil, delimeter: ";")
        XCTAssertEqual(oneLineTable.header.columnsStr(), "\"Column,1\",Column2")
        XCTAssertNil(oneLineTable.next())
    }
}
