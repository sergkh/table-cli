import XCTest
@testable import table

class CellTypesTests: XCTestCase {

    func testParsesTypesCorrectly() throws {
        let types = try CellType.fromStringList("date,string,number,boolean")
        XCTAssertEqual(types, [.date, .string, .number, .boolean])
    }

    func testInfersTypesCorrectly() throws {
        let types = CellType.infer(rows: [
            ["2024-06-01 00:11:00", "Hello", "123", "true"],
            ["2024-06-02 01:01:00", "World", "456.78", "false"]
        ])

        XCTAssertEqual(types, [.date, .string, .number, .boolean])
    }

    func testCorrectsInferenceOnLaterColumns() throws {
        let types = CellType.infer(rows: [
            ["2024-06-01 00:11:00", "Hello", "123", "true"],
            ["2024-06-02 01:01:00", "World", "456.78", "false"],
            ["string", "World", "not a number", "unknown"]
        ])

        XCTAssertEqual(types, [.string, .string, .string, .string])
    }
}
