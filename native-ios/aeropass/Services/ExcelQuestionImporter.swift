import CoreXLSX
import Foundation

enum QuestionImportError: LocalizedError {
    case unsupportedFormat
    case unreadableWorkbook
    case noValidQuestions
    case invalidRows([String])

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat: return "请选择 .xlsx 格式的题库文件"
        case .unreadableWorkbook: return "无法读取该工作簿"
        case .noValidQuestions: return "未找到有效题目，请检查列顺序"
        case .invalidRows(let errors): return errors.prefix(5).joined(separator: "\n") + (errors.count > 5 ? "\n另有 \(errors.count - 5) 处错误，请全部修正后导入" : "")
        }
    }
}

struct ExcelQuestionImporter {
    /// Flutter 题库格式：A 题干、B 答案、C 题号、D-G 选项 A-D。
    func parse(url: URL) throws -> [QuestionData] {
        guard url.pathExtension.lowercased() == "xlsx" else {
            throw QuestionImportError.unsupportedFormat
        }
        guard let file = XLSXFile(filepath: url.path) else {
            throw QuestionImportError.unreadableWorkbook
        }

        let sharedStrings = try file.parseSharedStrings()
        var result: [QuestionData] = []
        var seen = Set<String>()
        var errors: [String] = []

        for workbook in try file.parseWorkbooks() {
            for (optionalName, path) in try file.parseWorksheetPathsAndNames(workbook: workbook) {
                let sheetName = optionalName ?? "工作表"
                let worksheet = try file.parseWorksheet(at: path)

                for row in worksheet.data?.rows ?? [] {
                    var values: [String: String] = [:]
                    for cell in row.cells {
                        let column = cell.reference.column.value
                        let value: String
                        if let sharedStrings {
                            let rich = cell.richStringValue(sharedStrings).compactMap(\.text).joined()
                            value = cell.stringValue(sharedStrings) ?? (rich.isEmpty ? (cell.value ?? "") : rich)
                        } else {
                            value = cell.value ?? ""
                        }
                        values[column] = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    }

                    let content = values["A"] ?? ""
                    let rawAnswer = values["B"] ?? ""
                    let questionID = values["C"] ?? ""
                    if values.values.allSatisfy({ $0.isEmpty }) || isHeader(content: content, answer: rawAnswer, questionID: questionID) { continue }
                    let location = "「\(sheetName)」第 \(row.reference) 行"
                    let answer: String
                    switch rawAnswer.uppercased() {
                    case "正确", "对", "TRUE": answer = "A"
                    case "错误", "错", "FALSE": answer = "B"
                    default: answer = rawAnswer.uppercased()
                    }
                    let a = nonEmpty(values["D"])
                    let b = nonEmpty(values["E"])
                    let c = nonEmpty(values["F"])
                    let d = nonEmpty(values["G"])
                    if content.isEmpty { errors.append("\(location)：A 列题干不能为空"); continue }
                    if rawAnswer.isEmpty { errors.append("\(location)：B 列正确答案不能为空"); continue }
                    if !["A", "B", "C", "D"].contains(answer) { errors.append("\(location)：B 列只能填写 A、B、C、D、正确、错误、对或错"); continue }
                    if questionID.isEmpty { errors.append("\(location)：C 列题号不能为空"); continue }
                    if !seen.insert(questionID).inserted { errors.append("\(location)：题号 \(questionID) 重复"); continue }
                    if a == nil || b == nil { errors.append("\(location)：D、E 列选项 A、B 必填"); continue }
                    if (answer == "C" && c == nil) || (answer == "D" && d == nil) { errors.append("\(location)：正确答案 \(answer) 没有对应选项"); continue }
                    let isJudge = (c == nil && d == nil) || (["正确", "对"].contains(a ?? "") && ["错误", "错"].contains(b ?? ""))

                    result.append(QuestionData(
                        questionId: questionID,
                        content: content,
                        correctAnswer: answer,
                        optionA: a,
                        optionB: b,
                        optionC: c,
                        optionD: d,
                        type: isJudge ? "judge" : "single",
                        sheetName: sheetName
                    ))
                }
            }
        }
        if !errors.isEmpty { throw QuestionImportError.invalidRows(errors) }
        guard !result.isEmpty else { throw QuestionImportError.noValidQuestions }
        return result
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    private func isHeader(content: String, answer: String, questionID: String) -> Bool {
        let combined = "\(content)|\(answer)|\(questionID)".lowercased()
        return combined.contains("题干|答案|题号") || combined.contains("题目|答案|题号") || combined.contains("题目内容|正确答案|题目编号") || combined.contains("question|answer|id")
    }
}
