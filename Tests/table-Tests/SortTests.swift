import XCTest
@testable import table

class SortTests: XCTestCase {

    func testSortSingleColumnAscending() throws {
        let table = ParsedTable.fromArray([
            ["3", "Charlie"],
            ["1", "Alice"],
            ["2", "Bob"]
        ], header: ["id", "name"])
        
        let sortExpr = try Sort("id").validated(header: table.header)
        var sortedTable = try InMemoryTableView(table: table).sort(expr: sortExpr)
        
        let row1 = try sortedTable.next()!
        XCTAssertEqual(row1["id"], "1")
        XCTAssertEqual(row1["name"], "Alice")
        
        let row2 = try sortedTable.next()!
        XCTAssertEqual(row2["id"], "2")
        XCTAssertEqual(row2["name"], "Bob")
        
        let row3 = try sortedTable.next()!
        XCTAssertEqual(row3["id"], "3")
        XCTAssertEqual(row3["name"], "Charlie")
        
        XCTAssertNil(try sortedTable.next())
    }
    
    func testSortSingleColumnDescending() throws {
        let table = ParsedTable.fromArray([
            ["1", "Alice"],
            ["3", "Charlie"],
            ["2", "Bob"]
        ], header: ["id", "name"])
        
        let sortExpr = try Sort("!id").validated(header: table.header)
        var sortedTable = try InMemoryTableView(table: table).sort(expr: sortExpr)
        
        let row1 = try sortedTable.next()!
        XCTAssertEqual(row1["id"], "3")
        XCTAssertEqual(row1["name"], "Charlie")
        
        let row2 = try sortedTable.next()!
        XCTAssertEqual(row2["id"], "2")
        XCTAssertEqual(row2["name"], "Bob")
        
        let row3 = try sortedTable.next()!
        XCTAssertEqual(row3["id"], "1")
        XCTAssertEqual(row3["name"], "Alice")
        
        XCTAssertNil(try sortedTable.next())
    }
    
    func testSortMultipleColumns() throws {
        // Sort by name first (ascending), then by id (ascending)
        let table = ParsedTable.fromArray([
            ["2", "Alice"],
            ["1", "Alice"],
            ["3", "Bob"],
            ["4", "Alice"]
        ], header: ["id", "name"])
        
        let sortExpr = try Sort("name,id").validated(header: table.header)
        var sortedTable = try InMemoryTableView(table: table).sort(expr: sortExpr)
        
        // All Alice rows should come first, sorted by id
        let row1 = try sortedTable.next()!
        XCTAssertEqual(row1["id"], "1")
        XCTAssertEqual(row1["name"], "Alice")
        
        let row2 = try sortedTable.next()!
        XCTAssertEqual(row2["id"], "2")
        XCTAssertEqual(row2["name"], "Alice")
        
        let row3 = try sortedTable.next()!
        XCTAssertEqual(row3["id"], "4")
        XCTAssertEqual(row3["name"], "Alice")
        
        let row4 = try sortedTable.next()!
        XCTAssertEqual(row4["id"], "3")
        XCTAssertEqual(row4["name"], "Bob")
        
        XCTAssertNil(try sortedTable.next())
    }
    
    func testSortMultipleColumnsMixedOrder() throws {
        // Sort by name descending, then by id ascending
        let table = ParsedTable.fromArray([
            ["1", "Alice"],
            ["2", "Bob"],
            ["3", "Alice"],
            ["4", "Bob"]
        ], header: ["id", "name"])
        
        let sortExpr = try Sort("!name,id").validated(header: table.header)
        var sortedTable = try InMemoryTableView(table: table).sort(expr: sortExpr)
        
        // Bob rows first (descending name), then Alice rows
        let row1 = try sortedTable.next()!
        XCTAssertEqual(row1["id"], "2")
        XCTAssertEqual(row1["name"], "Bob")
        
        let row2 = try sortedTable.next()!
        XCTAssertEqual(row2["id"], "4")
        XCTAssertEqual(row2["name"], "Bob")
        
        let row3 = try sortedTable.next()!
        XCTAssertEqual(row3["id"], "1")
        XCTAssertEqual(row3["name"], "Alice")
        
        let row4 = try sortedTable.next()!
        XCTAssertEqual(row4["id"], "3")
        XCTAssertEqual(row4["name"], "Alice")
        
        XCTAssertNil(try sortedTable.next())
    }
    
    func testSortNumericValues() throws {
        // Numeric sorting should be numeric-aware, not lexicographic
        let table = ParsedTable.fromArray([
            ["10", "Item 10"],
            ["2", "Item 2"],
            ["1", "Item 1"],
            ["20", "Item 20"]
        ], header: ["id", "name"])
        
        let sortExpr = try Sort("id").validated(header: table.header)
        var sortedTable = try InMemoryTableView(table: table).sort(expr: sortExpr)
        
        // Should be sorted numerically: 1, 2, 10, 20 (not lexicographically: 1, 10, 2, 20)
        let row1 = try sortedTable.next()!
        XCTAssertEqual(row1["id"], "1")
        
        let row2 = try sortedTable.next()!
        XCTAssertEqual(row2["id"], "2")
        
        let row3 = try sortedTable.next()!
        XCTAssertEqual(row3["id"], "10")
        
        let row4 = try sortedTable.next()!
        XCTAssertEqual(row4["id"], "20")
        
        XCTAssertNil(try sortedTable.next())
    }
    
    func testSortNumericDescending() throws {
        let table = ParsedTable.fromArray([
            ["5", "Item 5"],
            ["100", "Item 100"],
            ["1", "Item 1"],
            ["50", "Item 50"]
        ], header: ["id", "name"])
        
        let sortExpr = try Sort("!id").validated(header: table.header)
        var sortedTable = try InMemoryTableView(table: table).sort(expr: sortExpr)
        
        // Should be sorted numerically descending: 100, 50, 5, 1
        let row1 = try sortedTable.next()!
        XCTAssertEqual(row1["id"], "100")
        
        let row2 = try sortedTable.next()!
        XCTAssertEqual(row2["id"], "50")
        
        let row3 = try sortedTable.next()!
        XCTAssertEqual(row3["id"], "5")
        
        let row4 = try sortedTable.next()!
        XCTAssertEqual(row4["id"], "1")
        
        XCTAssertNil(try sortedTable.next())
    }
    
    func testSortMixedNumericAndString() throws {
        // When comparing: if both are numeric, compare numerically; otherwise compare as strings
        let table = ParsedTable.fromArray([
            ["10", "Item 10"],
            ["2a", "Item 2a"],
            ["1", "Item 1"],
            ["2", "Item 2"]
        ], header: ["id", "name"])
        
        let sortExpr = try Sort("id").validated(header: table.header)
        var sortedTable = try InMemoryTableView(table: table).sort(expr: sortExpr)
        
        // Numeric values sorted numerically first, then strings lexicographically
        // "1" and "2" and "10" are numeric, so sorted: 1, 2, 10
        // "2a" is string, compared with others as string: "10" < "2a" lexicographically
        let row1 = try sortedTable.next()!
        XCTAssertEqual(row1["id"], "1")
        
        let row2 = try sortedTable.next()!
        XCTAssertEqual(row2["id"], "2")
        
        let row3 = try sortedTable.next()!
        XCTAssertEqual(row3["id"], "10")  // Numeric comparison: 10 > 2
        
        let row4 = try sortedTable.next()!
        XCTAssertEqual(row4["id"], "2a")  // String comparison: "10" < "2a" lexicographically
        
        XCTAssertNil(try sortedTable.next())
    }
    
    func testSortStringValues() throws {
        let table = ParsedTable.fromArray([
            ["1", "Zebra"],
            ["2", "Apple"],
            ["3", "Banana"]
        ], header: ["id", "name"])
        
        let sortExpr = try Sort("name").validated(header: table.header)
        var sortedTable = try InMemoryTableView(table: table).sort(expr: sortExpr)
        
        let row1 = try sortedTable.next()!
        XCTAssertEqual(row1["name"], "Apple")
        
        let row2 = try sortedTable.next()!
        XCTAssertEqual(row2["name"], "Banana")
        
        let row3 = try sortedTable.next()!
        XCTAssertEqual(row3["name"], "Zebra")
        
        XCTAssertNil(try sortedTable.next())
    }
    
    func testSortStringDescending() throws {
        let table = ParsedTable.fromArray([
            ["1", "Apple"],
            ["2", "Banana"],
            ["3", "Zebra"]
        ], header: ["id", "name"])
        
        let sortExpr = try Sort("!name").validated(header: table.header)
        var sortedTable = try InMemoryTableView(table: table).sort(expr: sortExpr)
        
        let row1 = try sortedTable.next()!
        XCTAssertEqual(row1["name"], "Zebra")
        
        let row2 = try sortedTable.next()!
        XCTAssertEqual(row2["name"], "Banana")
        
        let row3 = try sortedTable.next()!
        XCTAssertEqual(row3["name"], "Apple")
        
        XCTAssertNil(try sortedTable.next())
    }
    
    func testSortCaseSensitive() throws {
        // String sorting should be case-sensitive
        let table = ParsedTable.fromArray([
            ["1", "apple"],
            ["2", "Banana"],
            ["3", "Apple"]
        ], header: ["id", "name"])
        
        let sortExpr = try Sort("name").validated(header: table.header)
        var sortedTable = try InMemoryTableView(table: table).sort(expr: sortExpr)
        
        // Case-sensitive: "Apple" comes before "Banana" (A < B), and "apple" comes after (a > A)
        let row1 = try sortedTable.next()!
        XCTAssertEqual(row1["name"], "Apple")
        
        let row2 = try sortedTable.next()!
        XCTAssertEqual(row2["name"], "Banana")
        
        let row3 = try sortedTable.next()!
        XCTAssertEqual(row3["name"], "apple")
        
        XCTAssertNil(try sortedTable.next())
    }
    
    func testSortEmptyTable() throws {
        let table = ParsedTable.fromArray([], header: ["id", "name"])
        
        let sortExpr = try Sort("id").validated(header: table.header)
        var sortedTable = try InMemoryTableView(table: table).sort(expr: sortExpr)
        
        XCTAssertNil(try sortedTable.next())
    }
    
    func testSortSingleRow() throws {
        let table = ParsedTable.fromArray([
            ["1", "Alice"]
        ], header: ["id", "name"])
        
        let sortExpr = try Sort("id").validated(header: table.header)
        var sortedTable = try InMemoryTableView(table: table).sort(expr: sortExpr)
        
        let row = try sortedTable.next()!
        XCTAssertEqual(row["id"], "1")
        XCTAssertEqual(row["name"], "Alice")
        
        XCTAssertNil(try sortedTable.next())
    }
    
    func testSortAlreadySorted() throws {
        // Sorting an already sorted table should maintain order
        let table = ParsedTable.fromArray([
            ["1", "Alice"],
            ["2", "Bob"],
            ["3", "Charlie"]
        ], header: ["id", "name"])
        
        let sortExpr = try Sort("id").validated(header: table.header)
        var sortedTable = try InMemoryTableView(table: table).sort(expr: sortExpr)
        
        let row1 = try sortedTable.next()!
        XCTAssertEqual(row1["id"], "1")
        
        let row2 = try sortedTable.next()!
        XCTAssertEqual(row2["id"], "2")
        
        let row3 = try sortedTable.next()!
        XCTAssertEqual(row3["id"], "3")
        
        XCTAssertNil(try sortedTable.next())
    }
    
    func testSortWithWhitespaceInColumnNames() throws {
        // Test that whitespace in sort expression is handled correctly
        let table = ParsedTable.fromArray([
            ["2", "Bob"],
            ["1", "Alice"]
        ], header: ["id", "name"])
        
        // Sort expression with whitespace
        let sortExpr = try Sort(" id ").validated(header: table.header)
        var sortedTable = try InMemoryTableView(table: table).sort(expr: sortExpr)
        
        let row1 = try sortedTable.next()!
        XCTAssertEqual(row1["id"], "1")
        
        let row2 = try sortedTable.next()!
        XCTAssertEqual(row2["id"], "2")
        
        XCTAssertNil(try sortedTable.next())
    }
    
    func testSortWithMultipleWhitespace() throws {
        let table = ParsedTable.fromArray([
            ["2", "Bob", "X"],
            ["1", "Alice", "Y"]
        ], header: ["id", "name", "status"])
        
        // Multiple columns with whitespace
        let sortExpr = try Sort(" name , id ").validated(header: table.header)
        var sortedTable = try InMemoryTableView(table: table).sort(expr: sortExpr)
        
        let row1 = try sortedTable.next()!
        XCTAssertEqual(row1["name"], "Alice")
        
        let row2 = try sortedTable.next()!
        XCTAssertEqual(row2["name"], "Bob")
        
        XCTAssertNil(try sortedTable.next())
    }

    func testSortThrowsErrorOnInvalidColumn() throws {
        let table = ParsedTable.fromArray([
            ["1", "Alice"]
        ], header: ["id", "name"])
        
        XCTAssertThrowsError(try Sort("nonexistent").validated(header: table.header)) { error in
            let errorMessage = String(describing: error)
            XCTAssertTrue(errorMessage.contains("Unknown column"), "Error should mention unknown column, got: \(errorMessage)")
            XCTAssertTrue(errorMessage.contains("nonexistent"), "Error should mention the column name, got: \(errorMessage)")
        }
    }
    
    func testSortThrowsErrorOnMultipleInvalidColumns() throws {
        let table = ParsedTable.fromArray([
            ["1", "Alice"]
        ], header: ["id", "name"])
        
        XCTAssertThrowsError(try Sort("id,invalid1,invalid2").validated(header: table.header)) { error in
            let errorMessage = String(describing: error)
            XCTAssertTrue(errorMessage.contains("Unknown column"), "Error should mention unknown column, got: \(errorMessage)")
        }
    }
    
    func testSortThreeColumns() throws {
        // Sort by three columns
        let table = ParsedTable.fromArray([
            ["1", "Alice", "A"],
            ["2", "Alice", "B"],
            ["3", "Bob", "A"],
            ["4", "Alice", "A"]
        ], header: ["id", "name", "status"])
        
        let sortExpr = try Sort("name,status,id").validated(header: table.header)
        var sortedTable = try InMemoryTableView(table: table).sort(expr: sortExpr)
        
        // All Alice rows first, sorted by status, then by id
        let row1 = try sortedTable.next()!
        XCTAssertEqual(row1["id"], "1")
        XCTAssertEqual(row1["name"], "Alice")
        XCTAssertEqual(row1["status"], "A")
        
        let row2 = try sortedTable.next()!
        XCTAssertEqual(row2["id"], "4")
        XCTAssertEqual(row2["name"], "Alice")
        XCTAssertEqual(row2["status"], "A")
        
        let row3 = try sortedTable.next()!
        XCTAssertEqual(row3["id"], "2")
        XCTAssertEqual(row3["name"], "Alice")
        XCTAssertEqual(row3["status"], "B")
        
        let row4 = try sortedTable.next()!
        XCTAssertEqual(row4["id"], "3")
        XCTAssertEqual(row4["name"], "Bob")
        XCTAssertEqual(row4["status"], "A")
        
        XCTAssertNil(try sortedTable.next())
    }
    
    func testSortAllDescending() throws {
        let table = ParsedTable.fromArray([
            ["1", "Alice"],
            ["2", "Bob"],
            ["3", "Alice"]
        ], header: ["id", "name"])
        
        let sortExpr = try Sort("!name,!id").validated(header: table.header)
        var sortedTable = try InMemoryTableView(table: table).sort(expr: sortExpr)
        
        // Bob first (descending name), then Alice rows in descending id order
        let row1 = try sortedTable.next()!
        XCTAssertEqual(row1["name"], "Bob")
        XCTAssertEqual(row1["id"], "2")
        
        let row2 = try sortedTable.next()!
        XCTAssertEqual(row2["name"], "Alice")
        XCTAssertEqual(row2["id"], "3")
        
        let row3 = try sortedTable.next()!
        XCTAssertEqual(row3["name"], "Alice")
        XCTAssertEqual(row3["id"], "1")
        
        XCTAssertNil(try sortedTable.next())
    }
    
    func testSortWithNegativeNumbers() throws {
        let table = ParsedTable.fromArray([
            ["-5", "Item -5"],
            ["10", "Item 10"],
            ["-1", "Item -1"],
            ["5", "Item 5"]
        ], header: ["id", "name"])
        
        let sortExpr = try Sort("id").validated(header: table.header)
        var sortedTable = try InMemoryTableView(table: table).sort(expr: sortExpr)
        
        // Should sort numerically: -5, -1, 5, 10
        let row1 = try sortedTable.next()!
        XCTAssertEqual(row1["id"], "-5")
        
        let row2 = try sortedTable.next()!
        XCTAssertEqual(row2["id"], "-1")
        
        let row3 = try sortedTable.next()!
        XCTAssertEqual(row3["id"], "5")
        
        let row4 = try sortedTable.next()!
        XCTAssertEqual(row4["id"], "10")
        
        XCTAssertNil(try sortedTable.next())
    }
    
    func testSortPreservesOriginalRowData() throws {
        // Ensure sorting doesn't modify the actual row data, just the order
        let table = ParsedTable.fromArray([
            ["3", "Charlie", "C"],
            ["1", "Alice", "A"],
            ["2", "Bob", "B"]
        ], header: ["id", "name", "status"])
        
        let sortExpr = try Sort("id").validated(header: table.header)
        var sortedTable = try InMemoryTableView(table: table).sort(expr: sortExpr)
        
        let row1 = try sortedTable.next()!
        XCTAssertEqual(row1["id"], "1")
        XCTAssertEqual(row1["name"], "Alice")
        XCTAssertEqual(row1["status"], "A")
        
        let row2 = try sortedTable.next()!
        XCTAssertEqual(row2["id"], "2")
        XCTAssertEqual(row2["name"], "Bob")
        XCTAssertEqual(row2["status"], "B")
        
        let row3 = try sortedTable.next()!
        XCTAssertEqual(row3["id"], "3")
        XCTAssertEqual(row3["name"], "Charlie")
        XCTAssertEqual(row3["status"], "C")
        
        XCTAssertNil(try sortedTable.next())
    }
}

