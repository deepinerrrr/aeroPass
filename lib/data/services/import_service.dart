import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/question_model.dart';
import '../models/question_bank_model.dart';
import '../database/database_helper.dart';
import 'xlsx_parser.dart';

class ImportService {
  final DatabaseHelper _db = DatabaseHelper();

  Future<ImportResult> importFromAsset() async {
    try {
      debugPrint('开始加载JSON题库文件...');
      final String jsonString = await rootBundle.loadString(
        'assets/questions.json',
      );
      debugPrint('JSON文件大小: ${jsonString.length} 字符');
      return _parseJson(jsonString);
    } catch (e) {
      debugPrint('导入异常: $e');
      return ImportResult(success: false, message: '导入失败: $e', count: 0);
    }
  }

  Future<ImportResult> _parseJson(String jsonString) async {
    debugPrint('开始解析JSON...');
    final List<dynamic> jsonList = jsonDecode(jsonString);
    debugPrint('JSON包含 ${jsonList.length} 道题目');

    // 确保存在默认题库记录
    final activeBank = await _db.getActiveBank();
    int bankId;
    if (activeBank != null) {
      bankId = activeBank.id!;
    } else {
      final now = DateTime.now().toIso8601String();
      bankId = await _db.insertQuestionBank(
        QuestionBank(
          name: '默认题库',
          source: 'asset',
          createdAt: now,
          isActive: 1,
        ),
      );
    }

    final questions = <Question>[];

    for (final item in jsonList) {
      final map = item as Map<String, dynamic>;
      questions.add(
        Question(
          questionId: map['question_id'] as String,
          content: map['content'] as String,
          optionA: map['option_a'] as String?,
          optionB: map['option_b'] as String?,
          optionC: map['option_c'] as String?,
          optionD: map['option_d'] as String?,
          answer: map['answer'] as String,
          type: map['type'] as String? ?? 'single',
          sheetName: map['sheet_name'] as String?,
          bankId: bankId,
        ),
      );

      if (questions.length % 1000 == 0) {
        debugPrint('已解析 ${questions.length} 道题目...');
      }
    }

    debugPrint('解析完成，共 ${questions.length} 道题目');

    if (questions.isNotEmpty) {
      debugPrint('开始插入数据库...');
      await _db.insertQuestions(questions);
      await _db.updateBankQuestionCount(bankId);
      debugPrint('数据库插入完成');
    }

    return ImportResult(
      success: true,
      message: '成功导入 ${questions.length} 道题目',
      count: questions.length,
    );
  }

  Future<ImportResult> importFromExcel(String filePath, String bankName) async {
    try {
      debugPrint('开始解析Excel文件: $filePath');
      if (!filePath.toLowerCase().endsWith('.xlsx')) {
        return ImportResult(
          success: false,
          message: '仅支持 .xlsx 格式文件',
          count: 0,
        );
      }
      final file = File(filePath);
      if (!await file.exists()) {
        return ImportResult(success: false, message: '文件不存在', count: 0);
      }

      final sheets = XlsxParser.parse(filePath);
      debugPrint('解析到 ${sheets.length} 个工作表');

      final validation = validateExcelSheets(sheets);
      if (!validation.isValid) {
        return ImportResult(
          success: false,
          message: validation.message,
          count: 0,
        );
      }

      // 创建题库记录
      final now = DateTime.now().toIso8601String();
      final bankId = await _db.insertQuestionBank(
        QuestionBank(
          name: bankName,
          source: 'file',
          filePath: filePath,
          createdAt: now,
          isActive: 1,
        ),
      );

      final questions = validation.rows
          .map(
            (row) => Question(
              questionId: row.questionId,
              content: row.content,
              optionA: row.optionA,
              optionB: row.optionB,
              optionC: row.optionC,
              optionD: row.optionD,
              answer: row.answer,
              type: row.type,
              sheetName: row.sheetName,
              bankId: bankId,
            ),
          )
          .toList();

      debugPrint('Excel解析完成，共 ${questions.length} 道题目');

      if (questions.isNotEmpty) {
        await _db.insertQuestions(questions);
        await _db.updateBankQuestionCount(bankId);
        // 静默去重，防止用户重复刷到一样的题目
        try {
          final removed = await _db.deduplicateQuestions(bankId: bankId);
          if (removed > 0) {
            debugPrint('题库去重：移除 $removed 道重复题目');
          }
        } catch (e) {
          debugPrint('题库去重失败: $e');
        }
      }

      return ImportResult(
        success: true,
        message: '成功导入 ${questions.length} 道题目',
        count: questions.length,
        bankId: bankId,
      );
    } catch (e, stack) {
      debugPrint('Excel导入异常: $e');
      debugPrint('堆栈: $stack');
      return ImportResult(success: false, message: '导入失败: $e', count: 0);
    }
  }

  static ExcelImportValidation validateExcelSheets(List<XlsxSheetData> sheets) {
    final validRows = <ExcelQuestionRow>[];
    final errors = <String>[];
    final seenIds = <String>{};

    for (final sheet in sheets) {
      for (var rowIndex = 0; rowIndex < sheet.rows.length; rowIndex++) {
        final row = sheet.rows[rowIndex];
        if (row.every((cell) => cell.trim().isEmpty)) continue;
        if (_isHeaderRow(row)) continue;

        final location = '「${sheet.name}」第 ${rowIndex + 1} 行';
        final content = _cell(row, 0);
        final rawAnswer = _cell(row, 1);
        final questionId = _cell(row, 2);
        final optionA = _cell(row, 3);
        final optionB = _cell(row, 4);
        final optionC = _cell(row, 5);
        final optionD = _cell(row, 6);
        final answer = _normalizeAnswer(rawAnswer);

        if (content.isEmpty) {
          errors.add('$location：A 列题目内容不能为空');
        } else if (rawAnswer.isEmpty) {
          errors.add('$location：B 列正确答案不能为空');
        } else if (answer == null) {
          errors.add('$location：B 列仅可填写 A、B、C、D、正确、错误、对或错');
        } else if (questionId.isEmpty) {
          errors.add('$location：C 列题目编号不能为空');
        } else if (!seenIds.add(questionId)) {
          errors.add('$location：题目编号 $questionId 重复');
        } else if (optionA.isEmpty || optionB.isEmpty) {
          errors.add('$location：D、E 列的选项 A、B 均为必填');
        } else if ((answer == 'C' && optionC.isEmpty) ||
            (answer == 'D' && optionD.isEmpty)) {
          errors.add('$location：正确答案 $answer 没有对应的选项内容');
        } else {
          final isJudge =
              (optionC.isEmpty && optionD.isEmpty) ||
              ((optionA == '正确' || optionA == '对') &&
                  (optionB == '错误' || optionB == '错'));
          validRows.add(
            ExcelQuestionRow(
              content: content,
              answer: answer,
              questionId: questionId,
              optionA: optionA,
              optionB: optionB,
              optionC: optionC.isEmpty ? null : optionC,
              optionD: optionD.isEmpty ? null : optionD,
              type: isJudge ? 'judge' : 'single',
              sheetName: sheet.name,
            ),
          );
        }
      }
    }

    if (errors.isNotEmpty) {
      final preview = errors.take(5).join('\n');
      final remaining = errors.length - 5;
      return ExcelImportValidation(
        rows: const [],
        errors: errors,
        message:
            '文件内容不符合导入规范：\n$preview${remaining > 0 ? '\n另有 $remaining 处问题' : ''}',
      );
    }
    if (validRows.isEmpty) {
      return const ExcelImportValidation(
        rows: [],
        errors: ['没有可导入的题目'],
        message: '文件中没有可导入的题目，请按格式规范填写 A–G 列',
      );
    }
    return ExcelImportValidation(
      rows: validRows,
      errors: const [],
      message: '',
    );
  }

  static String _cell(List<String> row, int index) {
    if (index >= row.length) return '';
    return row[index].trim();
  }

  static String? _normalizeAnswer(String answer) {
    switch (answer.trim().toUpperCase()) {
      case 'A':
      case 'B':
      case 'C':
      case 'D':
        return answer.trim().toUpperCase();
      case '正确':
      case '对':
        return 'A';
      case '错误':
      case '错':
        return 'B';
      default:
        return null;
    }
  }

  static bool _isHeaderRow(List<String> row) {
    final first = _cell(row, 0).toLowerCase();
    final second = _cell(row, 1).toLowerCase();
    final third = _cell(row, 2).toLowerCase();
    return (first.contains('题目') ||
            first.contains('题干') ||
            first == 'content') &&
        (second.contains('答案') || second == 'answer') &&
        (third.contains('编号') || third == 'id' || third.contains('question'));
  }
}

class ExcelQuestionRow {
  final String content;
  final String answer;
  final String questionId;
  final String optionA;
  final String optionB;
  final String? optionC;
  final String? optionD;
  final String type;
  final String sheetName;

  const ExcelQuestionRow({
    required this.content,
    required this.answer,
    required this.questionId,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.type,
    required this.sheetName,
  });
}

class ExcelImportValidation {
  final List<ExcelQuestionRow> rows;
  final List<String> errors;
  final String message;

  const ExcelImportValidation({
    required this.rows,
    required this.errors,
    required this.message,
  });

  bool get isValid => errors.isEmpty && rows.isNotEmpty;
}

class ImportResult {
  final bool success;
  final String message;
  final int count;
  final int? bankId;

  ImportResult({
    required this.success,
    required this.message,
    required this.count,
    this.bankId,
  });
}
