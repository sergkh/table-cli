import XCTest
@testable import table

class ColumnsManipulationTableViewTests: XCTestCase {

    func testAddSingleStaticColumn() throws {
        let table = ParsedTable.fromArray([
            ["Alice", "30"],
            ["Bob", "25"]
        ], header: ["name", "age"])
        
        let format = try Format(format: "StaticValue").validated(header: nil)
        let newColumnsTable = NewColumnsTableView(
            table: table,
            additionalColumns: [("status", format)]
        )
        
        XCTAssertEqual(newColumnsTable.header.columnsStr(), "name,age,status")
        
        let row1 = try newColumnsTable.next()!
        XCTAssertEqual(row1["name"], "Alice")
        XCTAssertEqual(row1["age"], "30")
        XCTAssertEqual(row1["status"], "StaticValue")
        
        let row2 = try newColumnsTable.next()!
        XCTAssertEqual(row2["name"], "Bob")
        XCTAssertEqual(row2["age"], "25")
        XCTAssertEqual(row2["status"], "StaticValue")
        
        XCTAssertNil(try newColumnsTable.next())
    }
    
    func testAddMultipleStaticColumns() throws {
        let table = ParsedTable.fromArray([
            ["Alice", "30"]
        ], header: ["name", "age"])
        
        let format1 = try Format(format: "Active").validated(header: nil)
        let format2 = try Format(format: "Premium").validated(header: nil)
        
        let newColumnsTable = NewColumnsTableView(
            table: table,
            additionalColumns: [
                ("status", format1),
                ("tier", format2)
            ]
        )
        
        XCTAssertEqual(newColumnsTable.header.columnsStr(), "name,age,status,tier")
        
        let row = try newColumnsTable.next()!
        XCTAssertEqual(row["name"], "Alice")
        XCTAssertEqual(row["age"], "30")
        XCTAssertEqual(row["status"], "Active")
        XCTAssertEqual(row["tier"], "Premium")
        
        XCTAssertNil(try newColumnsTable.next())
    }
    
    func testAddColumnWithVariableSubstitution() throws {
        let table = ParsedTable.fromArray([
            ["Alice", "30"],
            ["Bob", "25"]
        ], header: ["name", "age"])
        
        let format = try Format(format: "Name: ${name}, Age: ${age}").validated(header: table.header)
        let newColumnsTable = NewColumnsTableView(
            table: table,
            additionalColumns: [("info", format)]
        )
        
        XCTAssertEqual(newColumnsTable.header.columnsStr(), "name,age,info")
        
        
        let row1 = try newColumnsTable.next()!
        XCTAssertEqual(row1["name"], "Alice")
        XCTAssertEqual(row1["age"], "30")
        XCTAssertEqual(row1["info"], "Name: Alice, Age: 30")

        let row2 = try newColumnsTable.next()!
        XCTAssertEqual(row2["name"], "Bob")
        XCTAssertEqual(row2["age"], "25")
        XCTAssertEqual(row2["info"], "Name: Bob, Age: 25")
        
        XCTAssertNil(try newColumnsTable.next())
    }
    
    func testAddColumnWithFunction() throws {
        let table = ParsedTable.fromArray([
            ["Alice", "30"],
            ["Bob", "25"]
        ], header: ["name", "age"])
        
        let format = try Format(format: "Header: %{header()}").validated(header: table.header)
        let newColumnsTable = NewColumnsTableView(
            table: table,
            additionalColumns: [("header_info", format)]
        )
        
        let row1 = try newColumnsTable.next()!
        XCTAssertEqual(row1["header_info"], "Header: name,age")
        
        let row2 = try newColumnsTable.next()!
        XCTAssertEqual(row2["header_info"], "Header: name,age")
        
        XCTAssertNil(try newColumnsTable.next())
    }
    
    func testAddColumnWithComplexExpression() throws {
        let table = ParsedTable.fromArray([
            ["Alice", "30", "100"],
            ["Bob", "25", "200"]
        ], header: ["name", "age", "score"])
        
        let format = try Format(format: "Sum: %{sum(${age},${score})}").validated(header: table.header)
        let newColumnsTable = NewColumnsTableView(
            table: table,
            additionalColumns: [("total", format)]
        )
        
        let row1 = try newColumnsTable.next()!
        XCTAssertEqual(row1["total"], "Sum: 130")
                
        let row2 = try newColumnsTable.next()!
        XCTAssertEqual(row2["total"], "Sum: 225")
        
        XCTAssertNil(try newColumnsTable.next())
    }
    
    func testEmptyTable() throws {
        let table = ParsedTable.empty()
        
        let format = try Format(format: "NewColumn").validated(header: nil)
        let newColumnsTable = NewColumnsTableView(
            table: table,
            additionalColumns: [("new_col", format)]
        )
        
        XCTAssertEqual(newColumnsTable.header.columnsStr(), "new_col")
        XCTAssertNil(try newColumnsTable.next())
    }
    
    func testGeneratedTableWithNewColumns() throws {
        let table = ParsedTable.generated(rows: 2)
        
        let statusFormat = try Format(format: "generated").validated(header: nil)
        let sourceFormat = try Format(format: "cli").validated(header: nil)
        let newColumnsTable = NewColumnsTableView(
            table: table,
            additionalColumns: [
                ("status", statusFormat),
                ("source", sourceFormat)
            ]
        )
        
        XCTAssertEqual(newColumnsTable.header.columnsStr(), "status,source")
        
        let row1 = try newColumnsTable.next()!
        XCTAssertEqual(row1.index, 0)
        XCTAssertEqual(row1["status"], "generated")
        XCTAssertEqual(row1["source"], "cli")
        
        let row2 = try newColumnsTable.next()!
        XCTAssertEqual(row2.index, 1)
        XCTAssertEqual(row2["status"], "generated")
        XCTAssertEqual(row2["source"], "cli")
        
        XCTAssertNil(try newColumnsTable.next())
    }
    
    func testPreservesRowIndex() throws {
        let table = ParsedTable.fromArray([
            ["Alice"],
            ["Bob"],
            ["Charlie"]
        ], header: ["name"])
        
        let format = try Format(format: "Extra").validated(header: nil)
        let newColumnsTable = NewColumnsTableView(
            table: table,
            additionalColumns: [("extra", format)]
        )
        
        let row1 = try newColumnsTable.next()!
        XCTAssertEqual(row1.index, 0)
        
        let row2 = try newColumnsTable.next()!
        XCTAssertEqual(row2.index, 1)
        
        let row3 = try newColumnsTable.next()!
        XCTAssertEqual(row3.index, 2)
        
        XCTAssertNil(try newColumnsTable.next())
    }
    
    func testMultipleColumnsWithDifferentFormats() throws {
        let table = ParsedTable.fromArray([
            ["Alice", "30"]
        ], header: ["name", "age"])
        
        let staticFormat = try Format(format: "Static").validated(header: nil)
        let varFormat = try Format(format: "${name}").validated(header: table.header)
        let funcFormat = try Format(format: "%{values()}").validated(header: table.header)
        
        let newColumnsTable = NewColumnsTableView(
            table: table,
            additionalColumns: [
                ("static_col", staticFormat),
                ("name_copy", varFormat),
                ("all_values", funcFormat)
            ]
        )
        
        XCTAssertEqual(newColumnsTable.header.columnsStr(), "name,age,static_col,name_copy,all_values")
        
        let row = try newColumnsTable.next()!
        XCTAssertEqual(row["static_col"], "Static")
        XCTAssertEqual(row["name_copy"], "Alice")
        XCTAssertEqual(row["all_values"], "Alice,30")
        
        XCTAssertNil(try newColumnsTable.next())
    }
    
    func testColumnOrderPreservation() throws {
        let table = ParsedTable.fromArray([
            ["Alice"]
        ], header: ["name"])
        
        let format1 = try Format(format: "First").validated(header: nil)
        let format2 = try Format(format: "Second").validated(header: nil)
        let format3 = try Format(format: "Third").validated(header: nil)
        
        let newColumnsTable = NewColumnsTableView(
            table: table,
            additionalColumns: [
                ("first", format1),
                ("second", format2),
                ("third", format3)
            ]
        )
        
        let row = try newColumnsTable.next()!
        XCTAssertEqual(row[0], "Alice")
        XCTAssertEqual(row[1], "First")
        XCTAssertEqual(row[2], "Second")
        XCTAssertEqual(row[3], "Third")
        
        XCTAssertNil(try newColumnsTable.next())
    }
    
    func testColumnWithEmptyFormat() throws {
        let table = ParsedTable.fromArray([
            ["Alice"]
        ], header: ["name"])
        
        let format = try Format(format: "").validated(header: nil)
        let newColumnsTable = NewColumnsTableView(
            table: table,
            additionalColumns: [("empty", format)]
        )
        
        let row = try newColumnsTable.next()!
        XCTAssertEqual(row["empty"], "")
        
        XCTAssertNil(try newColumnsTable.next())
    }
    
    func testColumnWithWhitespace() throws {
        let table = ParsedTable.fromArray([["Alice"]], header: ["name"])
        
        let format = try Format(format: "  Padded  ").validated(header: nil)
        let newColumnsTable = NewColumnsTableView(
            table: table,
            additionalColumns: [("padded", format)]
        )
        
        let row = try newColumnsTable.next()!
        XCTAssertEqual(row["padded"], "  Padded  ")
        
        XCTAssertNil(try newColumnsTable.next())
    }
    
    func testColumnWithSpecialCharacters() throws {
        let table = ParsedTable.fromArray([["Alice"]], header: ["name"])
        
        let format = try Format(format: "Value: $100 & 50%").validated(header: nil)
        let newColumnsTable = NewColumnsTableView(
            table: table,
            additionalColumns: [("special", format)]
        )
        
        let row = try newColumnsTable.next()!
        XCTAssertEqual(row["special"], "Value: $100 & 50%")
        
        XCTAssertNil(try newColumnsTable.next())
    }
    
    func testColumnAccessByIndex() throws {
        let table = ParsedTable.fromArray([
            ["Alice", "30"]
        ], header: ["name", "age"])
        
        let format = try Format(format: "Extra").validated(header: nil)
        let newColumnsTable = NewColumnsTableView(
            table: table,
            additionalColumns: [("extra", format)]
        )
        
        let row = try newColumnsTable.next()!
        XCTAssertEqual(row[0], "Alice")
        XCTAssertEqual(row[1], "30")
        XCTAssertEqual(row[2], "Extra")
        
        XCTAssertNil(try newColumnsTable.next())
    }
    
    func testColumnWithMaxFunction() throws {
        let table = ParsedTable.fromArray([
            ["Alice", "30", "40"]
        ], header: ["name", "age", "score"])
        
        let format = try Format(format: "Max: %{max(${age},${score})}").validated(header: table.header)
        let newColumnsTable = NewColumnsTableView(
            table: table,
            additionalColumns: [("max_value", format)]
        )
        
        let row = try newColumnsTable.next()!
        XCTAssertEqual(row["max_value"], "Max: 40")
        
        XCTAssertNil(try newColumnsTable.next())
    }

    func testRemovingColumns() throws {
        let table = ParsedTable.fromArray([
            ["Alice", "30", "Engineer"],
            ["Bob", "25", "Designer"]
        ], header: ["name", "age", "profession"])

        let hideColumnsTable = HideColumnsTableView(
            table: table,
            hideColumns: ["age"]
        )

        XCTAssertEqual(hideColumnsTable.header.columnsStr(), "name,profession")
        let row1 = try hideColumnsTable.next()!        
        XCTAssertEqual(row1["name"], "Alice")
        XCTAssertEqual(row1["profession"], "Engineer")
        XCTAssertNil(row1["age"])

        let row2 = try hideColumnsTable.next()!
        XCTAssertEqual(row2["name"], "Bob")
        XCTAssertEqual(row2["profession"], "Designer")
        XCTAssertNil(row2["age"])
    }
}

