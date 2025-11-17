import XCTest
@testable import table

class FilterTests: XCTestCase {
    let header = Header(components: ["col1", "col2"], types: [.string, .string])

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
    
    func testEqualityOperator() throws {
        let filter = try Filter.compile(filter: "col1 = value", header: header)
        
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["value", "other"])))
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["Value", "other"])))
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["different", "other"])))
    }
    
    func testEqualityWithNumbers() throws {
        let filter = try Filter.compile(filter: "col1 = 42", header: header)
        
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["42", "other"])))
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["43", "other"])))
    }
    
    func testEqualityWithEmptyString() throws {
        let filter = try Filter.compile(filter: "col1 = ", header: header)
        
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["", "other"])))
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["value", "other"])))
    }
    
    func testNotEqualOperator() throws {
        let filter = try Filter.compile(filter: "col1 != value", header: header)
        
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["value", "other"])))
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["Value", "other"])))
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["different", "other"])))
    }
    
    func testNotEqualWithNumbers() throws {
        let filter = try Filter.compile(filter: "col1 != 42", header: header)
        
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["42", "other"])))
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["43", "other"])))
    }
    
    func testLessThanOperator() throws {
        let filter = try Filter.compile(filter: "col1 < 10", header: header)
        
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["5", "other"])))
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["9", "other"])))
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["10", "other"])))
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["15", "other"])))
    }
    
    func testLessThanWithNegativeNumbers() throws {
        let filter = try Filter.compile(filter: "col1 < 0", header: header)
        
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["-5", "other"])))
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["-1", "other"])))
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["0", "other"])))
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["5", "other"])))
    }
    
    func testLessThanWithStrings() throws {
        let filter = try Filter.compile(filter: "col1 < zebra", header: header)
        
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["apple", "other"])))
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["banana", "other"])))
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["zebra", "other"])))
    }
    
    func testLessThanOrEqualOperator() throws {
        let filter = try Filter.compile(filter: "col1 <= 10", header: header)
        
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["5", "other"])))
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["10", "other"])))
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["11", "other"])))
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["15", "other"])))
    }
    
    func testGreaterThanOperator() throws {
        let filter = try Filter.compile(filter: "col1 > 10", header: header)
        
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["5", "other"])))
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["10", "other"])))
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["11", "other"])))
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["15", "other"])))
    }
    
    func testGreaterThanWithZero() throws {
        let filter = try Filter.compile(filter: "col1 > 0", header: header)
        
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["0", "other"])))
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["-5", "other"])))
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["1", "other"])))
    }
    
    func testGreaterThanOrEqualOperator() throws {
        let filter = try Filter.compile(filter: "col1 >= 10", header: header)
        
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["5", "other"])))
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["10", "other"])))
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["11", "other"])))
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["15", "other"])))
    }
    
    func testContainsOperator() throws {
        let filter = try Filter.compile(filter: "col1 ~= test", header: header)
        
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["test", "other"])))
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["testing", "other"])))
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["mytest", "other"])))
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["my test value", "other"])))
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["Test", "other"])))
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["different", "other"])))
    }
    
    func testContainsWithSpecialCharacters() throws {
        let filter = try Filter.compile(filter: "col1 ~= $100", header: header)
        
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["Price: $100", "other"])))
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["$100", "other"])))
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["Price: 100", "other"])))
    }
    
    func testStartsWithOperator() throws {
        let filter = try Filter.compile(filter: "col1 ^= prefix", header: header)
        
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["prefix", "other"])))
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["prefixsuffix", "other"])))
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["prefix value", "other"])))
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["myprefix", "other"])))
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["Prefix", "other"])))
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["different", "other"])))
    }
    
    func testStartsWithWithEmptyString() throws {
        let filter = try Filter.compile(filter: "col1 ^= ", header: header)    
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["any", "other"])))
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["", "other"])))
    }

    func testEndsWithOperator() throws {
        let filter = try Filter.compile(filter: "col1 $= suffix", header: header)
        
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["suffix", "other"])))
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["mysuffix", "other"])))
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["value suffix", "other"])))
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["suffixmy", "other"])))
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["Suffix", "other"])))
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["different", "other"])))
    }
    
    func testEndsWithWithEmptyString() throws {
        let filter = try Filter.compile(filter: "col1 $= ", header: header)
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["any", "other"])))
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["", "other"])))
    }
    
    func testInvertedFilter() throws {
        let filter = try Filter.compile(filter: "!col1 = value", header: header)
        
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["value", "other"])))
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["Value", "other"])))
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["different", "other"])))
    }
    
    func testInvertedGreaterThan() throws {
        let filter = try Filter.compile(filter: "!col1 > 10", header: header)
        
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["5", "other"])))
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["10", "other"])))
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["11", "other"])))
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["15", "other"])))
    }
    
    func testInvertedContains() throws {
        let filter = try Filter.compile(filter: "!col1 ~= test", header: header)
        
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["test", "other"])))
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["testing", "other"])))
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["different", "other"])))
    }
    
    func testFilterWithWhitespace() throws {
        let filter = try Filter.compile(filter: "col1 = test value", header: header)
        
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["test value", "other"])))
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["testvalue", "other"])))
    }
    
    func testFilterWithLeadingTrailingWhitespace() throws {
        let filter = try Filter.compile(filter: "col1 =  value  ", header: header)
        
        // Filter trims whitespace from value
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["value", "other"])))
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: [" value ", "other"])))
    }
        
    func testNumberComparisonWithNonNumericString() throws {
        let filter = try Filter.compile(filter: "col1 > 10", header: header)
        
        // When row value is not numeric, falls back to string comparison
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["abc", "other"])))
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["1a", "other"])))
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["5", "other"])))
    }
    
    func testStringComparisonWithNumericValue() throws {
        let filter = try Filter.compile(filter: "col1 = 42", header: header)
        
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["42", "other"])))
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["43", "other"])))
    }
    
    func testInvalidFilterFormat() throws {
        XCTAssertThrowsError(try Filter.compile(filter: "invalid format", header: header)) { error in
            let errorMessage = String(describing: error)
            XCTAssertTrue(errorMessage.contains("Invalid filter format"))
        }
    }
    
    func testUnknownColumn() throws {
        XCTAssertThrowsError(try Filter.compile(filter: "unknown_col = value", header: header)) { error in
            let errorMessage = String(describing: error)
            XCTAssertTrue(errorMessage.contains("unknown column"))
            XCTAssertTrue(errorMessage.contains("unknown_col"))
        }
    }
    
    func testUnsupportedOperator() throws {
        // Note: This might not throw if the regex matches but operator is invalid
        // Let's test with a clearly invalid operator
        XCTAssertThrowsError(try Filter.compile(filter: "col1 == value", header: header)) { error in
            let errorMessage = String(describing: error)
            XCTAssertTrue(errorMessage.contains("unsupported comparison operation") || 
                        errorMessage.contains("Invalid filter format"))
        }
    }
    
    func testFilterWithZero() throws {
        let filter = try Filter.compile(filter: "col1 = 0", header: header)
        
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["0", "other"])))
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["1", "other"])))
    }
    
    func testFilterWithLargeNumbers() throws {
        let filter = try Filter.compile(filter: "col1 > 1000000", header: header)
        
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["2000000", "other"])))
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["500000", "other"])))
    }
    
    func testFilterWithColumnNamesContainingNumbers() throws {
        let headerWithNumbers = Header(components: ["col1", "col2", "col_123"], types: [.string, .string, .string])
        let filter = try Filter.compile(filter: "col_123 = test", header: headerWithNumbers)
        
        XCTAssertTrue(filter.apply(row: Row(header: headerWithNumbers, index: 0, components: ["value", "other", "test"])))
        XCTAssertFalse(filter.apply(row: Row(header: headerWithNumbers, index: 0, components: ["value", "other", "different"])))
    }
    
    func testFilterWithSpecialCharactersInValue() throws {
        let filter = try Filter.compile(filter: "col1 = test@example.com", header: header)
        
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["test@example.com", "other"])))
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["test@example", "other"])))
    }
    
    func testFilterWithUnicodeCharacters() throws {
        let filter = try Filter.compile(filter: "col1 = café", header: header)
        
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["café", "other"])))
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["cafe", "other"])))
    }
    
    func testFilterOnSecondColumn() throws {
        let filter = try Filter.compile(filter: "col2 = value", header: header)
        
        XCTAssertTrue(filter.apply(row: Row(header: header, index: 0, components: ["other", "value"])))
        XCTAssertFalse(filter.apply(row: Row(header: header, index: 0, components: ["other", "different"])))
    }
    
    func testFilterWithDifferentColumnTypes() throws {
        let mixedHeader = Header(components: ["name", "age", "active"], types: [.string, .number, .boolean])
        let filter = try Filter.compile(filter: "age > 18", header: mixedHeader)
        
        XCTAssertTrue(filter.apply(row: Row(header: mixedHeader, index: 0, components: ["Alice", "25", "true"])))
        XCTAssertFalse(filter.apply(row: Row(header: mixedHeader, index: 0, components: ["Bob", "15", "true"])))
    }
}
