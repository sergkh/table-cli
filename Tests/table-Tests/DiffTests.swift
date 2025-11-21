import XCTest
@testable import table

class DiffTests: XCTestCase {

    func testBasicDiffLeftMode() throws {
        let table1 = ParsedTable.fromArray([
            ["1", "Alice"],
            ["2", "Bob"],
            ["3", "Charlie"]
        ], header: ["id", "name"])
        
        let table2 = ParsedTable.fromArray([
            ["1", "Alice"],
            ["2", "Bob"]
        ], header: ["id", "name"])
        
        let diff = try Diff.parse(table2, diffOn: "id=id", firstTable: table1, mode: "left")
        let diffTable = DiffTableView(table: table1, diff: diff)
                
        let row = try diffTable.next()!
        XCTAssertEqual(row["id"], "3")
        XCTAssertEqual(row["name"], "Charlie")
        
        XCTAssertNil(try diffTable.next())
    }
    
    func testBasicDiffRightMode() throws {
        let table1 = ParsedTable.fromArray([
            ["1", "Alice"],
            ["2", "Bob"]
        ], header: ["id", "name"])

        let table2 = ParsedTable.fromArray([
            ["1", "Alice"],
            ["2", "Bob"],
            ["3", "Charlie"]
        ], header: ["id", "name"])
        
        let diff = try Diff.parse(table2, diffOn: "id=id", firstTable: table1, mode: "right")
        let diffTable = DiffTableView(table: table1, diff: diff)
        
        let row = try diffTable.next()!
        XCTAssertEqual(row["id"], "3")
        XCTAssertEqual(row["name"], "Charlie")
        
        XCTAssertNil(try diffTable.next())
    }
    
    func testBasicDiffBothMode() throws {
        let table1 = ParsedTable.fromArray([
            ["1", "Alice"],
            ["2", "Bob"],
            ["3", "Charlie"]
        ], header: ["id", "name"])

        let table2 = ParsedTable.fromArray([
            ["1", "Alice"],
            ["2", "Bob"],
            ["4", "David"]
        ], header: ["id", "name"])
        
        let diff = try Diff.parse(table2, diffOn: "id=id", firstTable: table1, mode: "both")
        let diffTable = DiffTableView(table: table1, diff: diff)

        XCTAssertEqual(diffTable.header.components(), ["_source", "id", "name"])

        let row1 = try diffTable.next()!
        XCTAssertEqual(row1["_source"], "left")
        XCTAssertEqual(row1["id"], "3")
        XCTAssertEqual(row1["name"], "Charlie")

        let row2 = try diffTable.next()!
        XCTAssertEqual(row2["_source"], "right")
        XCTAssertEqual(row2["id"], "4")
        XCTAssertEqual(row2["name"], "David")
        
        XCTAssertNil(try diffTable.next())
    }
    
    func testDiffWithDefaultFirstColumns() throws {
        let table1 = ParsedTable.fromArray([
            ["1", "Alice"],
            ["2", "Bob"],
            ["3", "Charlie"]
        ], header: ["id", "name"])
        
        let table2 = ParsedTable.fromArray([
            ["1", "Alice"],
            ["2", "Bob"]
        ], header: ["id", "name"])
        
        let diff = try Diff.parse(table2, diffOn: nil, firstTable: table1, mode: "left")
        let diffTable = DiffTableView(table: table1, diff: diff)
        
        let row = try diffTable.next()!
        XCTAssertEqual(row["id"], "3")
        XCTAssertEqual(row["name"], "Charlie")
        
        XCTAssertNil(try diffTable.next())
    }
    
    func testDiffWithCustomColumnMapping() throws {
        let table1 = ParsedTable.fromArray([
            ["1", "Alice"],
            ["2", "Bob"],
            ["3", "Charlie"]
        ], header: ["user_id", "name"])
        
        let table2 = ParsedTable.fromArray([
            ["1", "Alice"],
            ["2", "Bob"]
        ], header: ["id", "name"])
        
        let diff = try Diff.parse(table2, diffOn: "user_id=id", firstTable: table1, mode: "left")
        let diffTable = DiffTableView(table: table1, diff: diff)
        
        let row = try diffTable.next()!
        XCTAssertEqual(row["user_id"], "3")
        XCTAssertEqual(row["name"], "Charlie")
        
        XCTAssertNil(try diffTable.next())
    }
    
    func testDiffWithNoDifferences() throws {
        let table1 = ParsedTable.fromArray([
            ["1", "Alice"],
            ["2", "Bob"]
        ], header: ["id", "name"])
        
        let table2 = ParsedTable.fromArray([
            ["1", "Alice"],
            ["2", "Bob"]
        ], header: ["id", "name"])
        
        let diff = try Diff.parse(table2, diffOn: "id=id", firstTable: table1, mode: "left")
        let diffTable = DiffTableView(table: table1, diff: diff)

        XCTAssertNil(try diffTable.next())
    }
    
    func testDiffWithAllRowsDifferent() throws {
        let table1 = ParsedTable.fromArray([
            ["1", "Alice"],
            ["2", "Bob"]
        ], header: ["id", "name"])
        
        let table2 = ParsedTable.fromArray([
            ["3", "Charlie"],
            ["4", "David"]
        ], header: ["id", "name"])
        
        let diff = try Diff.parse(table2, diffOn: "id=id", firstTable: table1, mode: "left")
        let diffTable = DiffTableView(table: table1, diff: diff)

        let row1 = try diffTable.next()!
        XCTAssertEqual(row1["id"], "1")
        XCTAssertEqual(row1["name"], "Alice")
        
        let row2 = try diffTable.next()!
        XCTAssertEqual(row2["id"], "2")
        XCTAssertEqual(row2["name"], "Bob")
        
        XCTAssertNil(try diffTable.next())
    }
    
    func testDiffWithEmptySecondTable() throws {
        let table1 = ParsedTable.fromArray([
            ["1", "Alice"],
            ["2", "Bob"]
        ], header: ["id", "name"])
        
        let table2 = ParsedTable.fromArray([], header: ["id", "name"])
        
        let diff = try Diff.parse(table2, diffOn: "id=id", firstTable: table1, mode: "left")
        let diffTable = DiffTableView(table: table1, diff: diff)

        let row1 = try diffTable.next()!
        XCTAssertEqual(row1["id"], "1")
        XCTAssertEqual(row1["name"], "Alice")
        
        let row2 = try diffTable.next()!
        XCTAssertEqual(row2["id"], "2")
        XCTAssertEqual(row2["name"], "Bob")
        
        XCTAssertNil(try diffTable.next())
    }
    
    func testDiffWithEmptyFirstTable() throws {
        let table1 = ParsedTable.fromArray([], header: ["id", "name"])
        
        let table2 = ParsedTable.fromArray([
            ["1", "Alice"],
            ["2", "Bob"]
        ], header: ["id", "name"])
        
        let diff = try Diff.parse(table2, diffOn: "id=id", firstTable: table1, mode: "left")
        let diffTable = DiffTableView(table: table1, diff: diff)

        XCTAssertNil(try diffTable.next())
    }
    
    func testDiffRightModeWithEmptyFirstTable() throws {
        let table1 = ParsedTable.fromArray([], header: ["id", "name"])
        
        let table2 = ParsedTable.fromArray([
            ["1", "Alice"],
            ["2", "Bob"]
        ], header: ["id", "name"])
        
        let diff = try Diff.parse(table2, diffOn: "id=id", firstTable: table1, mode: "right")
        let diffTable = DiffTableView(table: table1, diff: diff)

        let row1 = try diffTable.next()!
        XCTAssertEqual(row1["id"], "1")
        XCTAssertEqual(row1["name"], "Alice")
        
        let row2 = try diffTable.next()!
        XCTAssertEqual(row2["id"], "2")
        XCTAssertEqual(row2["name"], "Bob")
        
        XCTAssertNil(try diffTable.next())
    }
    
    func testDiffBothModeWithMultipleDifferences() throws {
        let table1 = ParsedTable.fromArray([
            ["1", "Alice"],
            ["2", "Bob"],
            ["3", "Charlie"],
            ["4", "David"]
        ], header: ["id", "name"])
        
        let table2 = ParsedTable.fromArray([
            ["1", "Alice"],
            ["3", "Charlie"],
            ["5", "Eve"],
            ["6", "Frank"]
        ], header: ["id", "name"])
        
        let diff = try Diff.parse(table2, diffOn: "id=id", firstTable: table1, mode: "both")
        let diffTable = DiffTableView(table: table1, diff: diff)

        let row1 = try diffTable.next()!
        XCTAssertEqual(row1["_source"], "left")
        XCTAssertEqual(row1["id"], "2")
        XCTAssertEqual(row1["name"], "Bob")
        
        let row2 = try diffTable.next()!
        XCTAssertEqual(row2["_source"], "left")
        XCTAssertEqual(row2["id"], "4")
        XCTAssertEqual(row2["name"], "David")

        let row3 = try diffTable.next()!
        XCTAssertEqual(row3["_source"], "right")
        XCTAssertEqual(row3["id"], "5")
        XCTAssertEqual(row3["name"], "Eve")
        
        let row4 = try diffTable.next()!
        XCTAssertEqual(row4["_source"], "right")
        XCTAssertEqual(row4["id"], "6")
        XCTAssertEqual(row4["name"], "Frank")
        
        XCTAssertNil(try diffTable.next())
    }
    
    func testDiffThrowsErrorOnMissingColumnInFirstTable() throws {
        let table1 = ParsedTable.fromArray([
            ["1", "Alice"]
        ], header: ["id", "name"])
        
        let table2 = ParsedTable.fromArray([
            ["1", "Alice"]
        ], header: ["id", "name"])
        
        XCTAssertThrowsError(try Diff.parse(table2, diffOn: "nonexistent=id", firstTable: table1, mode: "left")) { error in
            let errorMessage = String(describing: error)
            XCTAssertTrue(errorMessage.contains("not found") || errorMessage.contains("first table"), 
                         "Error should mention column not found in first table, got: \(errorMessage)")
        }
    }
    
    func testDiffThrowsErrorOnMissingColumnInSecondTable() throws {
        let table1 = ParsedTable.fromArray([
            ["1", "Alice"]
        ], header: ["id", "name"])
        
        let table2 = ParsedTable.fromArray([
            ["1", "Alice"]
        ], header: ["id", "name"])
        
        XCTAssertThrowsError(try Diff.parse(table2, diffOn: "id=nonexistent", firstTable: table1, mode: "left")) { error in
            let errorMessage = String(describing: error)
            XCTAssertTrue(errorMessage.contains("not found") || errorMessage.contains("second table"), 
                         "Error should mention column not found in second table, got: \(errorMessage)")
        }
    }
    
    func testDiffThrowsErrorOnInvalidDiffExpression() throws {
        let table1 = ParsedTable.fromArray([
            ["1", "Alice"]
        ], header: ["id", "name"])
        
        let table2 = ParsedTable.fromArray([
            ["1", "Alice"]
        ], header: ["id", "name"])
        
        // Invalid format - no equals sign
        XCTAssertThrowsError(try Diff.parse(table2, diffOn: "id-id", firstTable: table1, mode: "left")) { error in
            let errorMessage = String(describing: error)
            XCTAssertTrue(errorMessage.contains("format"), 
                        "Error should mention format, got: \(errorMessage)")
        }

        XCTAssertThrowsError(try Diff.parse(table2, diffOn: "id=id=extra", firstTable: table1, mode: "left")) { error in
            let errorMessage = String(describing: error)
            XCTAssertTrue(errorMessage.contains("format"), 
                        "Error should mention format, got: \(errorMessage)")
        }
    }
    
    func testDiffThrowsErrorOnInvalidMode() throws {
        let table1 = ParsedTable.fromArray([
            ["1", "Alice"]
        ], header: ["id", "name"])
        
        let table2 = ParsedTable.fromArray([
            ["1", "Alice"]
        ], header: ["id", "name"])
        
        XCTAssertThrowsError(try Diff.parse(table2, diffOn: "id=id", firstTable: table1, mode: "invalid")) { error in
            let errorMessage = String(describing: error)
            XCTAssertTrue(errorMessage.contains("Invalid diff mode") || errorMessage.contains("invalid"), 
                        "Error should mention invalid diff mode, got: \(errorMessage)")
        }
    }
    
    func testDiffWithMultipleColumns() throws {
        let table1 = ParsedTable.fromArray([
            ["1", "Alice", "25"],
            ["2", "Bob", "30"],
            ["3", "Charlie", "35"]
        ], header: ["id", "name", "age"])
        
        let table2 = ParsedTable.fromArray([
            ["1", "Alice", "25"],
            ["2", "Bob", "30"]
        ], header: ["id", "name", "age"])
        
        let diff = try Diff.parse(table2, diffOn: "id=id", firstTable: table1, mode: "left")
        let diffTable = DiffTableView(table: table1, diff: diff)
        
        let row = try diffTable.next()!
        XCTAssertEqual(row["id"], "3")
        XCTAssertEqual(row["name"], "Charlie")
        XCTAssertEqual(row["age"], "35")
        
        XCTAssertNil(try diffTable.next())
    }
    
    func testDiffPreservesRowIndex() throws {
        let table1 = ParsedTable.fromArray([
            ["1", "Alice"],
            ["2", "Bob"],
            ["3", "Charlie"]
        ], header: ["id", "name"])
        
        let table2 = ParsedTable.fromArray([
            ["1", "Alice"],
            ["2", "Bob"]
        ], header: ["id", "name"])
        
        let diff = try Diff.parse(table2, diffOn: "id=id", firstTable: table1, mode: "left")
        let diffTable = DiffTableView(table: table1, diff: diff)
        
        let row = try diffTable.next()!
        XCTAssertEqual(row.index, 2)
    }
    
    func testDiffWithNumericValues() throws {
        let table1 = ParsedTable.fromArray([
            ["100", "Product A"],
            ["200", "Product B"],
            ["300", "Product C"]
        ], header: ["product_id", "name"])
        
        let table2 = ParsedTable.fromArray([
            ["100", "Product A"],
            ["200", "Product B"]
        ], header: ["product_id", "name"])
        
        let diff = try Diff.parse(table2, diffOn: "product_id=product_id", firstTable: table1, mode: "left")
        let diffTable = DiffTableView(table: table1, diff: diff)
        
        let row = try diffTable.next()!
        XCTAssertEqual(row["product_id"], "300")
        XCTAssertEqual(row["name"], "Product C")
        
        XCTAssertNil(try diffTable.next())
    }
    
    func testDiffWithWhitespaceInColumnMapping() throws {
        let table1 = ParsedTable.fromArray([
            ["1", "Alice"],
            ["2", "Bob"],
            ["3", "Charlie"]
        ], header: ["id", "name"])
        
        let table2 = ParsedTable.fromArray([
            ["1", "Alice"],
            ["2", "Bob"]
        ], header: ["id", "name"])

        let diff = try Diff.parse(table2, diffOn: " id = id ", firstTable: table1, mode: "left")
        let diffTable = DiffTableView(table: table1, diff: diff)
        
        let row = try diffTable.next()!
        XCTAssertEqual(row["id"], "3")
        XCTAssertEqual(row["name"], "Charlie")
        
        XCTAssertNil(try diffTable.next())
    }
    
    func testDiffDefaultModeIsLeft() throws {
        let table1 = ParsedTable.fromArray([
            ["1", "Alice"],
            ["2", "Bob"],
            ["3", "Charlie"]
        ], header: ["id", "name"])
        
        let table2 = ParsedTable.fromArray([
            ["1", "Alice"],
            ["2", "Bob"]
        ], header: ["id", "name"])
        
        let diff = try Diff.parse(table2, diffOn: "id=id", firstTable: table1, mode: nil)
        let diffTable = DiffTableView(table: table1, diff: diff)

        let row = try diffTable.next()!
        XCTAssertEqual(row["id"], "3")
        XCTAssertEqual(row["name"], "Charlie")
        
        XCTAssertNil(try diffTable.next())
    }
    
    func testDiffBothModeHeader() throws {
        let table1 = ParsedTable.fromArray([
            ["1", "Alice"]
        ], header: ["id", "name"])
        
        let table2 = ParsedTable.fromArray([
            ["2", "Bob"]
        ], header: ["id", "name"])
        
        let diff = try Diff.parse(table2, diffOn: "id=id", firstTable: table1, mode: "both")
        let diffTable = DiffTableView(table: table1, diff: diff)
        
        let header = diffTable.header
        XCTAssertEqual(header.components(), ["_source", "id", "name"])
        XCTAssertEqual(header.size, 3)
    }
    
    func testDiffLeftModeHeader() throws {
        let table1 = ParsedTable.fromArray([
            ["1", "Alice"]
        ], header: ["id", "name"])
        
        let table2 = ParsedTable.fromArray([
            ["2", "Bob"]
        ], header: ["id", "name"])
        
        let diff = try Diff.parse(table2, diffOn: "id=id", firstTable: table1, mode: "left")
        let diffTable = DiffTableView(table: table1, diff: diff)
        
        let header = diffTable.header
        XCTAssertEqual(header.components(), ["id", "name"])
        XCTAssertEqual(header.size, 2)
    }
}

