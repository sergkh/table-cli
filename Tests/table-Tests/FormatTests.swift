import XCTest
@testable import table

class FormatTests: XCTestCase {
    let row = Row(
        header: Header(components: ["str1", "str2", "num1", "num2"], types: [.string, .string, .number, .number]),
        index: 0, 
        components: ["val1", "val2", "150", "200"]
    )

    func testParseExpressionsWithVars() throws {
        let (exprTree, _) = Format.parse("String here: ${str1} and here: ${str2}")                
        XCTAssertEqual(exprTree.description, "[Text(String here: ), Var(str1), Text( and here: ), Var(str2)]")
    }

    func testParseExpressionsWithFns() throws {
        let (exprTree, _) = Format.parse("Header: %{header()}, values: %{values()}, with args: %{fun(1,${str1},%{fun1()})}") // 
        XCTAssertEqual(exprTree.description, 
        "[Text(Header: ), Fun(name: header, arguments: []), Text(, values: ), Fun(name: values, arguments: []), Text(, with args: ), Fun(name: fun, arguments: [Text(1), Var(str1), Fun(name: fun1, arguments: [])])]")
    }

    func testParseExpressionsWithExec() throws {
        let (exprTree, _) = Format.parse("Exec: #{echo ${num1} + ${num2}}")
        XCTAssertEqual(exprTree.description, "[Text(Exec: ), Exec(command: Group([Text(echo ), Var(num1), Text( + ), Var(num2)]))]")
    }

    func testStringFormat() throws {
        let format = try Format(format: "Hello").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "Hello")        
    }

    func testSimpleVarsSubstitution() throws {
        let format = try Format(format: "String here: ${str1} and here: ${str2}").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "String here: val1 and here: val2")
    }

    func testFunctions() throws {
        let format = try Format(format: "Header: %{header} values: %{values}").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "Header: str1,str2,num1,num2 values: val1,val2,150,200")
    }

    func testExec() throws {
        let format = try Format(format: "Exec: #{echo '1'}").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "Exec: 1")
    }

    func testExecWithParams() throws {
        let format = try Format(format: "Result: #{echo \"${num1} + ${num2}\" | bc} and a var ${str1}").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "Result: 350 and a var val1")
    }

    func testDistinctOrderPreservation() throws {
        let testRow = Row(
            header: Header(components: ["tags"], types: [.string]),
            index: 0,
            components: ["red,blue,green,red,yellow,blue"]
        )
        let format = try Format(format: "%{distinct(${tags})}").validated(header: testRow.header)
        let result = format.fill(row: testRow)
        XCTAssertEqual(result, "red,blue,green,yellow")
    }
    
    func testDistinctWithSingleElement() throws {
        let distinctFunc = Functions.Distinct()
        let textExpr = TextExpr("a")
        let result = try distinctFunc.apply(row: row, arguments: [textExpr])
        XCTAssertEqual(result, "a")
    }
    
    func testDistinctWithAllUnique() throws {
        let distinctFunc = Functions.Distinct()
        let textExpr = TextExpr("a,b,c")
        let result = try distinctFunc.apply(row: row, arguments: [textExpr])
        XCTAssertEqual(result, "a,b,c")
    }
    
    func testDistinctWithAllSame() throws {
        let distinctFunc = Functions.Distinct()
        let textExpr = TextExpr("a,a,a,a")
        let result = try distinctFunc.apply(row: row, arguments: [textExpr])
        XCTAssertEqual(result, "a")
    }
    
    func testDistinctWithNumbers() throws {
        let distinctFunc = Functions.Distinct()
        let textExpr = TextExpr("1,2,3,1,4,2,5")
        let result = try distinctFunc.apply(row: row, arguments: [textExpr])
        XCTAssertEqual(result, "1,2,3,4,5")
    }
    
    func testSumWithMultipleArguments() throws {
        let format = try Format(format: "Sum: %{sum(1,2,3,4,5)}").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "Sum: 15")
    }
    
    func testSumWithCommaSeparatedList() throws {
        let format = try Format(format: "Sum: %{sum(10,20,30)}").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "Sum: 60")
    }
    
    func testSumWithColumnVariables() throws {
        let format = try Format(format: "Sum: %{sum(${num1},${num2})}").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "Sum: 350")
    }
    
    func testSumWithDecimals() throws {
        let format = try Format(format: "Sum: %{sum(10.5,20.3,30.2)}").validated(header: row.header)
        let result = format.fill(row: row)
        // Result should be 61.0 (as a decimal)
        XCTAssertTrue(result == "Sum: 61.0" || result == "Sum: 61", "Expected 'Sum: 61.0' or 'Sum: 61', got '\(result)'")
    }
    
    func testSumWithMixedIntegersAndDecimals() throws {
        let format = try Format(format: "Sum: %{sum(10,20.5,30)}").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "Sum: 60.5")
    }
    
    func testSumReturnsIntegerWhenWhole() throws {
        let format = try Format(format: "%{sum(10.0,20.0,30.0)}").validated(header: row.header)
        let result = format.fill(row: row)
        XCTAssertEqual(result, "60")
    }
    
    func testSumReturnsDecimalWhenNeeded() throws {
        let format = try Format(format: "%{sum(10.5,20.3)}").validated(header: row.header)
        let result = format.fill(row: row)
        XCTAssertEqual(result, "30.8")
    }
    
    func testSumWithSingleArgument() throws {
        let format = try Format(format: "Sum: %{sum(42)}").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "Sum: 42")
    }
    
    func testSumWithZero() throws {
        let format = try Format(format: "Sum: %{sum(0,0,0)}").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "Sum: 0")
    }
    
    func testSumWithNegativeNumbers() throws {
        let format = try Format(format: "Sum: %{sum(10,-5,3)}").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "Sum: 8")
    }
    
    func testSumWithLargeNumbers() throws {
        let format = try Format(format: "Sum: %{sum(1000,2000,3000)}").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "Sum: 6000")
    }
    
    func testSumValidationRequiresAtLeastOneArgument() throws {
        // This should fail validation
        XCTAssertThrowsError(try Format(format: "%{sum()}").validated(header: row.header)) { error in
            let errorMessage = String(describing: error)
            XCTAssertTrue(errorMessage.contains("requires at least one argument"), "Error message should contain 'requires at least one argument', got: \(errorMessage)")
        }
    }
    
    func testSumThrowsErrorOnNonNumericValue() throws {
        // Test the Sum function directly since Format.fill uses try! which causes fatal errors
        let sumFunc = Functions.Sum()
        let textExpr = TextExpr("abc")
        let numExpr1 = TextExpr("10")
        let numExpr2 = TextExpr("20")
        
        XCTAssertThrowsError(try sumFunc.apply(row: row, arguments: [numExpr1, textExpr, numExpr2])) { error in
            let errorMessage = String(describing: error)
            XCTAssertTrue(errorMessage.contains("requires numeric values"), "Error message should contain 'requires numeric values', got: \(errorMessage)")
        }
    }
    
    func testSumWithStringColumnThrowsError() throws {
        // Test the Sum function directly since Format.fill uses try! which causes fatal errors
        let sumFunc = Functions.Sum()
        let strExpr = VarExpr("str1")  // "val1" which is not numeric
        let numExpr = VarExpr("num1")  // "150" which is numeric
        
        XCTAssertThrowsError(try sumFunc.apply(row: row, arguments: [strExpr, numExpr])) { error in
            let errorMessage = String(describing: error)
            XCTAssertTrue(errorMessage.contains("requires numeric values"), "Error message should contain 'requires numeric values', got: \(errorMessage)")
        }
    }
    
    func testSumInComplexExpression() throws {
        let format = try Format(format: "Total: %{sum(${num1},${num2})} and text: ${str1}").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "Total: 350 and text: val1")
    }
    
    func testSumWithNestedExpressions() throws {
        // Sum with nested sum (if that makes sense)
        let format = try Format(format: "Sum: %{sum(10,%{sum(20,30)})}").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "Sum: 60")
    }

    func testMaxWithMultipleArguments() throws {
        let format = try Format(format: "Max: %{max(1,5,3,9,2)}").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "Max: 9")
    }
    
    func testMaxWithCommaSeparatedList() throws {
        let format = try Format(format: "Max: %{max(10,20,30,15)}").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "Max: 30")
    }
    
    func testMaxWithColumnVariables() throws {
        let format = try Format(format: "Max: %{max(${num1},${num2})}").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "Max: 200")
    }
    
    func testMaxWithDecimals() throws {
        let format = try Format(format: "Max: %{max(10.5,20.3,30.2,25.7)}").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "Max: 30.2")
    }
    
    func testMaxWithMixedIntegersAndDecimals() throws {
        let format = try Format(format: "Max: %{max(10,20.5,30,15.8)}").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "Max: 30")
    }
    
    func testMaxReturnsIntegerWhenWhole() throws {
        let format = try Format(format: "%{max(10.0,20.0,30.0)}").validated(header: row.header)
        let result = format.fill(row: row)
        XCTAssertEqual(result, "30")
    }
    
    func testMaxReturnsDecimalWhenNeeded() throws {
        let format = try Format(format: "%{max(10.5,20.3)}").validated(header: row.header)
        let result = format.fill(row: row)
        XCTAssertEqual(result, "20.3")
    }
    
    func testMaxWithSingleArgument() throws {
        let format = try Format(format: "Max: %{max(42)}").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "Max: 42")
    }
    
    func testMaxWithNegativeNumbers() throws {
        let format = try Format(format: "Max: %{max(-10,-5,-3)}").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "Max: -3")
    }
    
    func testMaxWithMixedPositiveAndNegative() throws {
        let format = try Format(format: "Max: %{max(-10,5,-3,0)}").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "Max: 5")
    }
    
    func testMaxValidationRequiresAtLeastOneArgument() throws {
        XCTAssertThrowsError(try Format(format: "%{max()}").validated(header: row.header)) { error in
            let errorMessage = String(describing: error)
            XCTAssertTrue(errorMessage.contains("requires at least one argument"), "Error message should contain 'requires at least one argument', got: \(errorMessage)")
        }
    }
    
    func testMaxThrowsErrorOnNonNumericValue() throws {
        let maxFunc = Functions.Max()
        let textExpr = TextExpr("abc")
        let numExpr1 = TextExpr("10")
        let numExpr2 = TextExpr("20")
        
        XCTAssertThrowsError(try maxFunc.apply(row: row, arguments: [numExpr1, textExpr, numExpr2])) { error in
            let errorMessage = String(describing: error)
            XCTAssertTrue(errorMessage.contains("requires numeric values"), "Error message should contain 'requires numeric values', got: \(errorMessage)")
        }
    }
    
    func testMaxInComplexExpression() throws {
        let format = try Format(format: "Maximum: %{max(${num1},${num2})} and text: ${str1}").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "Maximum: 200 and text: val1")
    }

    func testMinWithMultipleArguments() throws {
        let format = try Format(format: "Min: %{min(1,5,3,9,2)}").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "Min: 1")
    }
    
    func testMinWithCommaSeparatedList() throws {
        let format = try Format(format: "Min: %{min(10,20,30,15)}").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "Min: 10")
    }
    
    func testMinWithColumnVariables() throws {
        let format = try Format(format: "Min: %{min(${num1},${num2})}").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "Min: 150")
    }
    
    func testMinWithDecimals() throws {
        let format = try Format(format: "Min: %{min(10.5,20.3,30.2,25.7)}").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "Min: 10.5")
    }
    
    func testMinWithMixedIntegersAndDecimals() throws {
        let format = try Format(format: "Min: %{min(10,20.5,30,15.8)}").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "Min: 10")
    }
    
    func testMinReturnsIntegerWhenWhole() throws {
        let format = try Format(format: "%{min(10.0,20.0,30.0)}").validated(header: row.header)
        let result = format.fill(row: row)
        XCTAssertEqual(result, "10")
    }
    
    func testMinReturnsDecimalWhenNeeded() throws {
        let format = try Format(format: "%{min(10.5,20.3)}").validated(header: row.header)
        let result = format.fill(row: row)
        XCTAssertEqual(result, "10.5")
    }
    
    func testMinWithSingleArgument() throws {
        let format = try Format(format: "Min: %{min(42)}").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "Min: 42")
    }
    
    func testMinWithNegativeNumbers() throws {
        let format = try Format(format: "Min: %{min(-10,-5,-3)}").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "Min: -10")
    }
    
    func testMinWithMixedPositiveAndNegative() throws {
        let format = try Format(format: "Min: %{min(-10,5,-3,0)}").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "Min: -10")
    }
    
    func testMinValidationRequiresAtLeastOneArgument() throws {
        XCTAssertThrowsError(try Format(format: "%{min()}").validated(header: row.header)) { error in
            let errorMessage = String(describing: error)
            XCTAssertTrue(errorMessage.contains("requires at least one argument"), "Error message should contain 'requires at least one argument', got: \(errorMessage)")
        }
    }
    
    func testMinThrowsErrorOnNonNumericValue() throws {
        let minFunc = Functions.Min()
        let textExpr = TextExpr("abc")
        let numExpr1 = TextExpr("10")
        let numExpr2 = TextExpr("20")
        
        XCTAssertThrowsError(try minFunc.apply(row: row, arguments: [numExpr1, textExpr, numExpr2])) { error in
            let errorMessage = String(describing: error)
            XCTAssertTrue(errorMessage.contains("requires numeric values"), "Error message should contain 'requires numeric values', got: \(errorMessage)")
        }
    }
    
    func testMinInComplexExpression() throws {
        let format = try Format(format: "Minimum: %{min(${num1},${num2})} and text: ${str1}").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "Minimum: 150 and text: val1")
    }
    
    func testMinAndMaxTogether() throws {
        let format = try Format(format: "Range: %{min(10,20,30)} to %{max(10,20,30)}").validated(header: row.header)
        XCTAssertEqual(format.fill(row: row), "Range: 10 to 30")
    }
}
