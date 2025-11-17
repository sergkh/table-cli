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
    
    func testSemicolonDelimiter() throws {
        let table = try ParsedTable.parse(reader: ArrayLineReader(lines: [
            "name;age;city",
            "John;30;New York",
            "Jane;25;London"
        ]), hasHeader: nil, headerOverride: nil, delimeter: ";")
        
        XCTAssertEqual(table.header.components()[0], "name")
        XCTAssertEqual(table.header.components()[1], "age")
        XCTAssertEqual(table.header.components()[2], "city")
        
        let row1 = try table.next()!
        XCTAssertEqual(row1.components[0].value, "John")
        XCTAssertEqual(row1.components[1].value, "30")
        XCTAssertEqual(row1.components[2].value, "New York")
        
        let row2 = try table.next()!
        XCTAssertEqual(row2.components[0].value, "Jane")
        XCTAssertEqual(row2.components[1].value, "25")
        XCTAssertEqual(row2.components[2].value, "London")
    }
    
    func testTabDelimiter() throws {
        let table = try ParsedTable.parse(reader: ArrayLineReader(lines: [
            "col1\tcol2\tcol3",
            "val1\tval2\tval3"
        ]), hasHeader: nil, headerOverride: nil, delimeter: "\t")
        
        XCTAssertEqual(table.header.components()[0], "col1")
        XCTAssertEqual(table.header.components()[1], "col2")
        XCTAssertEqual(table.header.components()[2], "col3")
        
        let row = try table.next()!
        XCTAssertEqual(row.components[0].value, "val1")
        XCTAssertEqual(row.components[1].value, "val2")
        XCTAssertEqual(row.components[2].value, "val3")
    }
    
    func testPipeDelimiter() throws {
        let table = try ParsedTable.parse(reader: ArrayLineReader(lines: [
            "a|b|c",
            "1|2|3"
        ]), hasHeader: nil, headerOverride: nil, delimeter: "|")
        
        XCTAssertEqual(table.header.components()[0], "a")
        XCTAssertEqual(table.header.components()[1], "b")
        XCTAssertEqual(table.header.components()[2], "c")
        
        let row = try table.next()!
        XCTAssertEqual(row.components[0].value, "1")
        XCTAssertEqual(row.components[1].value, "2")
        XCTAssertEqual(row.components[2].value, "3")
    }

    func testQuotedFieldsWithCommas() throws {
        let table = try ParsedTable.parse(reader: ArrayLineReader(lines: [
            "\"Name,Full\",Age,City",
            "\"Smith,John\",30,\"New York, NY\""
        ]), hasHeader: nil, headerOverride: nil, delimeter: ",")
        
        XCTAssertEqual(table.header.components()[0], "Name,Full")
        XCTAssertEqual(table.header.components()[1], "Age")
        XCTAssertEqual(table.header.components()[2], "City")
        
        let row = try table.next()!
        XCTAssertEqual(row.components[0].value, "Smith,John")
        XCTAssertEqual(row.components[1].value, "30")
        XCTAssertEqual(row.components[2].value, "New York, NY")
    }
    
    func testMixedQuotedAndUnquotedFields() throws {
        let table = try ParsedTable.parse(reader: ArrayLineReader(lines: [
            "name,age,\"city,state\"",
            "John,30,\"New York,NY\"",
            "\"Jane Doe\",25,Chicago"
        ]), hasHeader: nil, headerOverride: nil, delimeter: ",")
        
        XCTAssertEqual(table.header.components()[0], "name")
        XCTAssertEqual(table.header.components()[1], "age")
        XCTAssertEqual(table.header.components()[2], "city,state")
        
        let row1 = try table.next()!
        XCTAssertEqual(row1.components[0].value, "John")
        XCTAssertEqual(row1.components[1].value, "30")
        XCTAssertEqual(row1.components[2].value, "New York,NY")
        
        let row2 = try table.next()!
        XCTAssertEqual(row2.components[0].value, "Jane Doe")
        XCTAssertEqual(row2.components[1].value, "25")
        XCTAssertEqual(row2.components[2].value, "Chicago")
    }
    
    func testQuotedFieldsWithQuotes() throws {
        // RFC 4180: If double-quotes are used to enclose fields, then a double-quote
        // appearing inside a field must be escaped by preceding it with another double quote.
        // Note: Current implementation does not handle escaped quotes ("" -> ") per RFC 4180.
        // The parser finds the first quote after an opening quote and treats everything
        // between them as content, then continues. This means escaped quotes are treated
        // as separate quoted sections, resulting in the quotes being stripped entirely.
        let table = try ParsedTable.parse(reader: ArrayLineReader(lines: [
            "name,description",
            "\"John \"\"Johnny\"\" Smith\",\"He said \"\"Hello\"\"\""
        ]), hasHeader: nil, headerOverride: nil, delimeter: ",")
        
        XCTAssertEqual(table.header.components()[0], "name")
        XCTAssertEqual(table.header.components()[1], "description")
        
        let row = try table.next()!
        // Current behavior: The parser treats each quote pair separately, so
        // "John ""Johnny"" Smith" becomes "John " + "Johnny" + " Smith" = "John Johnny Smith"
        // This is a limitation - RFC 4180 escaping is not fully supported
        XCTAssertEqual(row.components[0].value, "John Johnny Smith")
        XCTAssertEqual(row.components[1].value, "He said Hello")
    }
    
    func testQuotedFieldsWithNewlines() throws {
        let table = try ParsedTable.parse(reader: ArrayLineReader(lines: [
            "id,description",
            "1,\"Line 1\nLine 2\nLine 3\"",
            "2,\"Another\nMulti-line\""
        ]), hasHeader: nil, headerOverride: nil, delimeter: ",")
        
        XCTAssertEqual(table.header.components()[0], "id")
        XCTAssertEqual(table.header.components()[1], "description")
        
        let row1 = try table.next()!
        XCTAssertEqual(row1.components[0].value, "1")
        XCTAssertEqual(row1.components[1].value, "Line 1\nLine 2\nLine 3")
        
        let row2 = try table.next()!
        XCTAssertEqual(row2.components[0].value, "2")
        XCTAssertEqual(row2.components[1].value, "Another\nMulti-line")
    }
    
    func testAllFieldsQuoted() throws {
        let table = try ParsedTable.parse(reader: ArrayLineReader(lines: [
            "\"col1\",\"col2\",\"col3\"",
            "\"val1\",\"val2\",\"val3\""
        ]), hasHeader: nil, headerOverride: nil, delimeter: ",")
        
        XCTAssertEqual(table.header.components()[0], "col1")
        XCTAssertEqual(table.header.components()[1], "col2")
        XCTAssertEqual(table.header.components()[2], "col3")
        
        let row = try table.next()!
        XCTAssertEqual(row.components[0].value, "val1")
        XCTAssertEqual(row.components[1].value, "val2")
        XCTAssertEqual(row.components[2].value, "val3")
    }
    
    func testEmptyFields() throws {
        let table = try ParsedTable.parse(reader: ArrayLineReader(lines: [
            "a,b,c",
            ",,",  // All empty
            "1,,3",  // Middle empty
            ",2,",  // First and last empty
            "1,2,"  // Last empty
        ]), hasHeader: nil, headerOverride: nil, delimeter: ",")
        
        XCTAssertEqual(table.header.components().count, 3)
        
        let row1 = try table.next()!
        XCTAssertEqual(row1.components[0].value, "")
        XCTAssertEqual(row1.components[1].value, "")
        XCTAssertEqual(row1.components[2].value, "")
        
        let row2 = try table.next()!
        XCTAssertEqual(row2.components[0].value, "1")
        XCTAssertEqual(row2.components[1].value, "")
        XCTAssertEqual(row2.components[2].value, "3")
        
        let row3 = try table.next()!
        XCTAssertEqual(row3.components[0].value, "")
        XCTAssertEqual(row3.components[1].value, "2")
        XCTAssertEqual(row3.components[2].value, "")
        
        let row4 = try table.next()!
        XCTAssertEqual(row4.components[0].value, "1")
        XCTAssertEqual(row4.components[1].value, "2")
        XCTAssertEqual(row4.components[2].value, "")
    }
    
    func testQuotedEmptyFields() throws {
        let table = try ParsedTable.parse(reader: ArrayLineReader(lines: [
            "a,b,c",
            "\"\",\"\",\"\"",
            "\"\",b,\"\""
        ]), hasHeader: nil, headerOverride: nil, delimeter: ",")
        
        let row1 = try table.next()!
        XCTAssertEqual(row1.components[0].value, "")
        XCTAssertEqual(row1.components[1].value, "")
        XCTAssertEqual(row1.components[2].value, "")
        
        let row2 = try table.next()!
        XCTAssertEqual(row2.components[0].value, "")
        XCTAssertEqual(row2.components[1].value, "b")
        XCTAssertEqual(row2.components[2].value, "")
    }
    
    func testWhitespaceInUnquotedFields() throws {
        let table = try ParsedTable.parse(reader: ArrayLineReader(lines: [
            "a,b,c",
            "  value1  , value2 ,value3"
        ]), hasHeader: nil, headerOverride: nil, delimeter: ",")
        
        let row = try table.next()!
        // Note: Current implementation may preserve whitespace
        XCTAssertEqual(row.components[0].value, "  value1  ")
        XCTAssertEqual(row.components[1].value, " value2 ")
        XCTAssertEqual(row.components[2].value, "value3")
    }
    
    func testWhitespaceInQuotedFields() throws {
        let table = try ParsedTable.parse(reader: ArrayLineReader(lines: [
            "a,b",
            "\"  value1  \",\" value2 \""
        ]), hasHeader: nil, headerOverride: nil, delimeter: ",")
        
        let row = try table.next()!
        XCTAssertEqual(row.components[0].value, "  value1  ")
        XCTAssertEqual(row.components[1].value, " value2 ")
    }
    
    func testFieldsWithSpecialCharacters() throws {
        let table = try ParsedTable.parse(reader: ArrayLineReader(lines: [
            "col1,col2,col3",
            "value@domain.com,\"$100.50\",\"item & item\""
        ]), hasHeader: nil, headerOverride: nil, delimeter: ",")
        
        let row = try table.next()!
        XCTAssertEqual(row.components[0].value, "value@domain.com")
        XCTAssertEqual(row.components[1].value, "$100.50")
        XCTAssertEqual(row.components[2].value, "item & item")
    }
    
    func testFieldsWithUnicode() throws {
        let table = try ParsedTable.parse(reader: ArrayLineReader(lines: [
            "name,city",
            "José,北京",
            "François,Москва"
        ]), hasHeader: nil, headerOverride: nil, delimeter: ",")
        
        let row1 = try table.next()!
        XCTAssertEqual(row1.components[0].value, "José")
        XCTAssertEqual(row1.components[1].value, "北京")
        
        let row2 = try table.next()!
        XCTAssertEqual(row2.components[0].value, "François")
        XCTAssertEqual(row2.components[1].value, "Москва")
    }
    
    func testSingleField() throws {
        let table = try ParsedTable.parse(reader: ArrayLineReader(lines: [
            "single",
            "value"
        ]), hasHeader: nil, headerOverride: nil, delimeter: ",")
        
        XCTAssertEqual(table.header.components().count, 1)
        XCTAssertEqual(table.header.components()[0], "single")
        
        let row = try table.next()!
        XCTAssertEqual(row.components.count, 1)
        XCTAssertEqual(row.components[0].value, "value")
    }
    
    func testManyColumns() throws {
        let header = (1...20).map { "col\($0)" }.joined(separator: ",")
        let values = (1...20).map { "val\($0)" }.joined(separator: ",")
        
        let table = try ParsedTable.parse(reader: ArrayLineReader(lines: [
            header,
            values
        ]), hasHeader: nil, headerOverride: nil, delimeter: ",")
        
        XCTAssertEqual(table.header.components().count, 20)
        
        let row = try table.next()!
        XCTAssertEqual(row.components.count, 20)
        XCTAssertEqual(row.components[0].value, "val1")
        XCTAssertEqual(row.components[19].value, "val20")
    }
    
    func testQuotedFieldAtStart() throws {
        let table = try ParsedTable.parse(reader: ArrayLineReader(lines: [
            "\"quoted\",unquoted,normal",
            "\"value1\",value2,value3"
        ]), hasHeader: nil, headerOverride: nil, delimeter: ",")
        
        XCTAssertEqual(table.header.components()[0], "quoted")
        XCTAssertEqual(table.header.components()[1], "unquoted")
        XCTAssertEqual(table.header.components()[2], "normal")
        
        let row = try table.next()!
        XCTAssertEqual(row.components[0].value, "value1")
        XCTAssertEqual(row.components[1].value, "value2")
        XCTAssertEqual(row.components[2].value, "value3")
    }
    
    func testQuotedFieldAtEnd() throws {
        let table = try ParsedTable.parse(reader: ArrayLineReader(lines: [
            "normal,unquoted,\"quoted\"",
            "value1,value2,\"value3\""
        ]), hasHeader: nil, headerOverride: nil, delimeter: ",")
        
        XCTAssertEqual(table.header.components()[0], "normal")
        XCTAssertEqual(table.header.components()[1], "unquoted")
        XCTAssertEqual(table.header.components()[2], "quoted")
        
        let row = try table.next()!
        XCTAssertEqual(row.components[0].value, "value1")
        XCTAssertEqual(row.components[1].value, "value2")
        XCTAssertEqual(row.components[2].value, "value3")
    }
    
    func testMultipleRows() throws {
        let table = try ParsedTable.parse(reader: ArrayLineReader(lines: [
            "a,b,c",
            "1,2,3",
            "4,5,6",
            "7,8,9"
        ]), hasHeader: nil, headerOverride: nil, delimeter: ",")
        
        var row = try table.next()!
        XCTAssertEqual(row.components[0].value, "1")
        XCTAssertEqual(row.components[1].value, "2")
        XCTAssertEqual(row.components[2].value, "3")
        
        row = try table.next()!
        XCTAssertEqual(row.components[0].value, "4")
        XCTAssertEqual(row.components[1].value, "5")
        XCTAssertEqual(row.components[2].value, "6")
        
        row = try table.next()!
        XCTAssertEqual(row.components[0].value, "7")
        XCTAssertEqual(row.components[1].value, "8")
        XCTAssertEqual(row.components[2].value, "9")
        
        XCTAssertNil(try table.next())
    }
    
    func testAutomaticCommaDetection() throws {
        let table = try ParsedTable.parse(reader: ArrayLineReader(lines: [
            "a,b,c",
            "1,2,3"
        ]), hasHeader: nil, headerOverride: nil, delimeter: nil)
        
        XCTAssertEqual(table.conf.delimeter, ",")
        XCTAssertEqual(table.header.components()[0], "a")
    }
    
    func testAutomaticSemicolonDetection() throws {
        let table = try ParsedTable.parse(reader: ArrayLineReader(lines: [
            "a;b;c",
            "1;2;3"
        ]), hasHeader: nil, headerOverride: nil, delimeter: nil)
        
        XCTAssertEqual(table.conf.delimeter, ";")
        XCTAssertEqual(table.header.components()[0], "a")
    }
    
    func testAutomaticTabDetection() throws {
        let table = try ParsedTable.parse(reader: ArrayLineReader(lines: [
            "a\tb\tc",
            "1\t2\t3"
        ]), hasHeader: nil, headerOverride: nil, delimeter: nil)
        
        XCTAssertEqual(table.conf.delimeter, "\t")
        XCTAssertEqual(table.header.components()[0], "a")
    }
}
