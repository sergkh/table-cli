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
        XCTAssertEqual(exprTree.description, "Group(parts: [Text(String here: ), Var(name: str1), Text( and here: ), Var(name: str2)])")
    }

    func testParseExpressionsWithFns() throws {
        let (exprTree, _) = Format.parse("Header: %{header} values: %{values}")
        XCTAssertEqual(exprTree.description, "Group(parts: [Text(Header: ), Function(name: header), Text( values: ), Function(name: values)])")
    }

    func testParseExpressionsWithExec() throws {
        let (exprTree, _) = Format.parse("Exec: #{echo ${num1} + ${num2}}")
        XCTAssertEqual(exprTree.description, "Group(parts: [Text(Exec: ), Exec(command: Group(parts: [Text(echo ), Var(name: num1), Text( + ), Var(name: num2)]))])")
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
}
