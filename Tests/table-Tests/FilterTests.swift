import XCTest
@testable import table

class FilterTests: XCTestCase {
    let header = Header(components: ["col1", "col2"])

    func testComparesNumbersCorrectly() throws {        
        let filter = try Filter.compile(filter: "col1 > 12", header: header)

        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["111", "4"])))
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["1a", "4"])))
        
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["1", "4"])))        
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["12", "4"])))
    }

    func testComparesDatesCorrectly() throws {        
        let filter = try Filter.compile(filter: "col1 >= 2024-06-01 09:47:56", header: header)

        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["2024-06-01 09:47:56", "4"])))
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["2024-06-02 09:47:56", "4"])))
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["2024-06-01 09:47:57", "4"])))
    }

    func testComparesStringsCorrectly() throws {        
        let filter = try Filter.compile(filter: "col1 = Test", header: header)

        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["Test", "4"])))
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["test", "4"])))
    }
}
