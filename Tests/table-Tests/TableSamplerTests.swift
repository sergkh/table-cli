import XCTest
@testable import table

class TableSamplerTests: XCTestCase {

    func testSamplerOnEmptyTable() throws {
        let empty = SampledTableView(table: ParsedTable.empty(), percentage: 50)
        XCTAssertNil(empty.next())
    }

    func testHalfSamplerOnOneRowTable() throws {
        var smallTable: any Table = SampledTableView(
            table: ParsedTable.fromArray((0...1000).map { [ String($0) ] }), 
            percentage: 50
        )

        let sampledSize = count(&smallTable)

        XCTAssertEqual(sampledSize >= 400, true)
        XCTAssertEqual(sampledSize <= 600, true)
    }

    func testPercentageSamplerOnOneRowTable() throws {
        var smallTable: any Table = SampledTableView(
            table: ParsedTable.fromArray((0...1000).map { [ String($0) ] }), 
            percentage: 80
        )

        let sampledSize = count(&smallTable)
        
        XCTAssertEqual(sampledSize >= 700, true)
        XCTAssertEqual(sampledSize <= 900, true)
    }

    func count(_ table: inout any Table) -> Int {
        var count = 0
        while table.next() != nil {
            count += 1
        }
        return count
    }
}
