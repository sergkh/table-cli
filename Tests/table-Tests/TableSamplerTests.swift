import XCTest
@testable import table

class TableSamplerTests: XCTestCase {

    func testSamplerOnEmptyTable() throws {
        let empty = SampledTableView(table: ParsedTable.empty(), percentage: 50)
        XCTAssertNil(empty.next())
    }

    func testSamplerOnOneRowTable() throws {
        var smallTable: any Table = SampledTableView(
            table: ParsedTable.fromArray((0...100).map { [ String($0) ] }), 
            percentage: 50
        )

        let sampledSize = count(&smallTable)

        XCTAssertEqual(sampledSize >= 1, true)
        XCTAssertEqual(sampledSize <= 100, true)
    }

    func count(_ table: inout any Table) -> Int {
        var count = 0
        while table.next() != nil {
            count += 1
        }
        return count
    }
}
