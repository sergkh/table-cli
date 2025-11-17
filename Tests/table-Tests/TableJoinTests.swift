import XCTest
@testable import table

class JoinTests: XCTestCase {

    func testBasicJoinWithMatchingRows() throws {
        // First table: users with id and name
        let table1 = ParsedTable.fromArray([
            ["1", "Alice"],
            ["2", "Bob"],
            ["3", "Charlie"]
        ], header: ["id", "name"])
        
        // Second table: user details with user_id and email
        let table2 = ParsedTable.fromArray([
            ["1", "alice@example.com"],
            ["2", "bob@example.com"],
            ["3", "charlie@example.com"]
        ], header: ["user_id", "email"])
        
        let join = try Join.parse(table2, joinOn: "id=user_id", firstTable: table1)
        let joinedTable = JoinTableView(table: table1, join: join)
        
        // First row
        let row1 = try joinedTable.next()!
        XCTAssertEqual(row1["id"], "1")
        XCTAssertEqual(row1["name"], "Alice")
        XCTAssertEqual(row1["user_id"], "1")
        XCTAssertEqual(row1["email"], "alice@example.com")
        
        // Second row
        let row2 = try joinedTable.next()!
        XCTAssertEqual(row2["id"], "2")
        XCTAssertEqual(row2["name"], "Bob")
        XCTAssertEqual(row2["user_id"], "2")
        XCTAssertEqual(row2["email"], "bob@example.com")
        
        // Third row
        let row3 = try joinedTable.next()!
        XCTAssertEqual(row3["id"], "3")
        XCTAssertEqual(row3["name"], "Charlie")
        XCTAssertEqual(row3["user_id"], "3")
        XCTAssertEqual(row3["email"], "charlie@example.com")
        
        XCTAssertNil(try joinedTable.next())
    }
    
    func testJoinWithNoMatches() throws {
        // Left join behavior: rows from first table are kept even if no match
        let table1 = ParsedTable.fromArray([
            ["1", "Alice"],
            ["2", "Bob"],
            ["99", "Unknown"]
        ], header: ["id", "name"])
        
        let table2 = ParsedTable.fromArray([
            ["1", "alice@example.com"],
            ["2", "bob@example.com"]
        ], header: ["user_id", "email"])
        
        let join = try Join.parse(table2, joinOn: "id=user_id", firstTable: table1)
        let joinedTable = JoinTableView(table: table1, join: join)
        
        // First row - has match
        let row1 = try joinedTable.next()!
        XCTAssertEqual(row1["id"], "1")
        XCTAssertEqual(row1["name"], "Alice")
        XCTAssertEqual(row1["email"], "alice@example.com")
        
        // Second row - has match
        let row2 = try joinedTable.next()!
        XCTAssertEqual(row2["id"], "2")
        XCTAssertEqual(row2["name"], "Bob")
        XCTAssertEqual(row2["email"], "bob@example.com")
        
        // Third row - no match, should have empty cells for joined columns
        let row3 = try joinedTable.next()!
        XCTAssertEqual(row3["id"], "99")
        XCTAssertEqual(row3["name"], "Unknown")
        XCTAssertEqual(row3["user_id"], "")
        XCTAssertEqual(row3["email"], "")
        
        XCTAssertNil(try joinedTable.next())
    }
    
    func testJoinWithDefaultFirstColumns() throws {
        // When no join expression is provided, uses first column of both tables
        let table1 = ParsedTable.fromArray([
            ["1", "Alice"],
            ["2", "Bob"]
        ], header: ["id", "name"])
        
        let table2 = ParsedTable.fromArray([
            ["1", "active"],
            ["2", "inactive"]
        ], header: ["id", "status"])
        
        let join = try Join.parse(table2, joinOn: nil, firstTable: table1)
        let joinedTable = JoinTableView(table: table1, join: join)
        
        let row1 = try joinedTable.next()!
        XCTAssertEqual(row1["id"], "1")
        XCTAssertEqual(row1["name"], "Alice")
        XCTAssertEqual(row1["status"], "active")
        
        let row2 = try joinedTable.next()!
        XCTAssertEqual(row2["id"], "2")
        XCTAssertEqual(row2["name"], "Bob")
        XCTAssertEqual(row2["status"], "inactive")
        
        XCTAssertNil(try joinedTable.next())
    }
    
    func testJoinHeaderCombination() throws {
        let table1 = ParsedTable.fromArray([
            ["1", "Alice"]
        ], header: ["id", "name"])
        
        let table2 = ParsedTable.fromArray([
            ["1", "alice@example.com", "active"]
        ], header: ["user_id", "email", "status"])
        
        let join = try Join.parse(table2, joinOn: "id=user_id", firstTable: table1)
        let joinedTable = JoinTableView(table: table1, join: join)
        
        // Header should combine both tables
        let header = joinedTable.header
        XCTAssertEqual(header.components(), ["id", "name", "user_id", "email", "status"])
        XCTAssertEqual(header.size, 5)
    }
    
    func testJoinThrowsErrorOnDuplicateValues() throws {
        // Second table has duplicate values in join column
        let table1 = ParsedTable.fromArray([
            ["1", "Alice"]
        ], header: ["id", "name"])
        
        let table2 = ParsedTable.fromArray([
            ["1", "email1@example.com"],
            ["1", "email2@example.com"]  // Duplicate id
        ], header: ["user_id", "email"])
        
        XCTAssertThrowsError(try Join.parse(table2, joinOn: "id=user_id", firstTable: table1)) { error in
            let errorMessage = String(describing: error)
            XCTAssertTrue(errorMessage.contains("duplicate values"), "Error should mention duplicate values, got: \(errorMessage)")
        }
    }
    
    func testJoinThrowsErrorOnMissingColumnInSecondTable() throws {
        let table1 = ParsedTable.fromArray([
            ["1", "Alice"]
        ], header: ["id", "name"])
        
        let table2 = ParsedTable.fromArray([
            ["1", "email@example.com"]
        ], header: ["user_id", "email"])
        
        XCTAssertThrowsError(try Join.parse(table2, joinOn: "id=nonexistent", firstTable: table1)) { error in
            let errorMessage = String(describing: error)
            XCTAssertTrue(errorMessage.contains("not found"), "Error should mention column not found, got: \(errorMessage)")
        }
    }
    
    func testJoinThrowsErrorOnInvalidJoinExpression() throws {
        let table1 = ParsedTable.fromArray([
            ["1", "Alice"]
        ], header: ["id", "name"])
        
        let table2 = ParsedTable.fromArray([
            ["1", "email@example.com"]
        ], header: ["user_id", "email"])
        
        // Invalid format - no equals sign
        XCTAssertThrowsError(try Join.parse(table2, joinOn: "id-user_id", firstTable: table1)) { error in
            let errorMessage = String(describing: error)
            XCTAssertTrue(errorMessage.contains("format"), "Error should mention format, got: \(errorMessage)")
        }
        
        // Invalid format - too many parts
        XCTAssertThrowsError(try Join.parse(table2, joinOn: "id=user_id=extra", firstTable: table1)) { error in
            let errorMessage = String(describing: error)
            XCTAssertTrue(errorMessage.contains("format"), "Error should mention format, got: \(errorMessage)")
        }
    }
    
    func testJoinWithMultipleColumns() throws {
        // Test join with tables that have multiple columns
        let table1 = ParsedTable.fromArray([
            ["1", "Alice", "25"],
            ["2", "Bob", "30"]
        ], header: ["id", "name", "age"])
        
        let table2 = ParsedTable.fromArray([
            ["1", "alice@example.com", "Engineer"],
            ["2", "bob@example.com", "Manager"]
        ], header: ["user_id", "email", "role"])
        
        let join = try Join.parse(table2, joinOn: "id=user_id", firstTable: table1)
        let joinedTable = JoinTableView(table: table1, join: join)
        
        let row1 = try joinedTable.next()!
        XCTAssertEqual(row1["id"], "1")
        XCTAssertEqual(row1["name"], "Alice")
        XCTAssertEqual(row1["age"], "25")
        XCTAssertEqual(row1["user_id"], "1")
        XCTAssertEqual(row1["email"], "alice@example.com")
        XCTAssertEqual(row1["role"], "Engineer")
        
        let row2 = try joinedTable.next()!
        XCTAssertEqual(row2["id"], "2")
        XCTAssertEqual(row2["name"], "Bob")
        XCTAssertEqual(row2["age"], "30")
        XCTAssertEqual(row2["user_id"], "2")
        XCTAssertEqual(row2["email"], "bob@example.com")
        XCTAssertEqual(row2["role"], "Manager")
        
        XCTAssertNil(try joinedTable.next())
    }
    
    func testJoinWithPartialMatches() throws {
        // Some rows match, some don't
        let table1 = ParsedTable.fromArray([
            ["1", "Alice"],
            ["2", "Bob"],
            ["3", "Charlie"],
            ["4", "David"]
        ], header: ["id", "name"])
        
        let table2 = ParsedTable.fromArray([
            ["1", "alice@example.com"],
            ["3", "charlie@example.com"]
        ], header: ["user_id", "email"])
        
        let join = try Join.parse(table2, joinOn: "id=user_id", firstTable: table1)
        let joinedTable = JoinTableView(table: table1, join: join)
        
        // Row 1 - has match
        let row1 = try joinedTable.next()!
        XCTAssertEqual(row1["id"], "1")
        XCTAssertEqual(row1["name"], "Alice")
        XCTAssertEqual(row1["email"], "alice@example.com")
        
        // Row 2 - no match
        let row2 = try joinedTable.next()!
        XCTAssertEqual(row2["id"], "2")
        XCTAssertEqual(row2["name"], "Bob")
        XCTAssertEqual(row2["email"], "")
        
        // Row 3 - has match
        let row3 = try joinedTable.next()!
        XCTAssertEqual(row3["id"], "3")
        XCTAssertEqual(row3["name"], "Charlie")
        XCTAssertEqual(row3["email"], "charlie@example.com")
        
        // Row 4 - no match
        let row4 = try joinedTable.next()!
        XCTAssertEqual(row4["id"], "4")
        XCTAssertEqual(row4["name"], "David")
        XCTAssertEqual(row4["email"], "")
        
        XCTAssertNil(try joinedTable.next())
    }
    
    func testJoinWithEmptySecondTable() throws {
        // Second table is empty
        let table1 = ParsedTable.fromArray([
            ["1", "Alice"],
            ["2", "Bob"]
        ], header: ["id", "name"])
        
        let table2 = ParsedTable.fromArray([], header: ["user_id", "email"])
        
        let join = try Join.parse(table2, joinOn: "id=user_id", firstTable: table1)
        let joinedTable = JoinTableView(table: table1, join: join)
        
        // All rows should have empty joined columns
        let row1 = try joinedTable.next()!
        XCTAssertEqual(row1["id"], "1")
        XCTAssertEqual(row1["name"], "Alice")
        XCTAssertEqual(row1["user_id"], "")
        XCTAssertEqual(row1["email"], "")
        
        let row2 = try joinedTable.next()!
        XCTAssertEqual(row2["id"], "2")
        XCTAssertEqual(row2["name"], "Bob")
        XCTAssertEqual(row2["user_id"], "")
        XCTAssertEqual(row2["email"], "")
        
        XCTAssertNil(try joinedTable.next())
    }
    
    func testJoinWithNumericValues() throws {
        // Test join with numeric string values
        let table1 = ParsedTable.fromArray([
            ["100", "Product A"],
            ["200", "Product B"]
        ], header: ["product_id", "name"])
        
        let table2 = ParsedTable.fromArray([
            ["100", "10.99"],
            ["200", "20.50"]
        ], header: ["id", "price"])
        
        let join = try Join.parse(table2, joinOn: "product_id=id", firstTable: table1)
        let joinedTable = JoinTableView(table: table1, join: join)
        
        let row1 = try joinedTable.next()!
        XCTAssertEqual(row1["product_id"], "100")
        XCTAssertEqual(row1["name"], "Product A")
        XCTAssertEqual(row1["id"], "100")
        XCTAssertEqual(row1["price"], "10.99")
        
        let row2 = try joinedTable.next()!
        XCTAssertEqual(row2["product_id"], "200")
        XCTAssertEqual(row2["name"], "Product B")
        XCTAssertEqual(row2["id"], "200")
        XCTAssertEqual(row2["price"], "20.50")
        
        XCTAssertNil(try joinedTable.next())
    }
    
    func testJoinPreservesRowIndex() throws {
        // Verify that row indices are preserved from the first table
        let table1 = ParsedTable.fromArray([
            ["1", "Alice"],
            ["2", "Bob"]
        ], header: ["id", "name"])
        
        let table2 = ParsedTable.fromArray([
            ["1", "alice@example.com"]
        ], header: ["user_id", "email"])
        
        let join = try Join.parse(table2, joinOn: "id=user_id", firstTable: table1)
        let joinedTable = JoinTableView(table: table1, join: join)
        
        let row1 = try joinedTable.next()!
        XCTAssertEqual(row1.index, 0)
        
        let row2 = try joinedTable.next()!
        XCTAssertEqual(row2.index, 1)
    }
}

