import Foundation

@main struct ImportValidationTests {
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let importer = ExcelQuestionImporter()
        let valid = try importer.parse(url: root.appendingPathComponent("valid.xlsx"))
        precondition(valid.count == 2 && valid[1].isTrueFalse && valid[0].sheetName == "气象")
        print("PASS valid workbook, header, worksheet name, and judge normalization")
        for name in ["missing", "duplicate", "nooption", "badanswer"] {
            do { _ = try importer.parse(url: root.appendingPathComponent(name + ".xlsx")); preconditionFailure(name) }
            catch let error as QuestionImportError {
                let message = error.localizedDescription
                precondition(message.contains("气象") && message.contains("行"))
                print("PASS \(name) rejected with worksheet and row diagnostics")
            }
        }
        print("RESULT 5 import checks passed")
    }
}
