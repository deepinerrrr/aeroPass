import 'package:flutter_test/flutter_test.dart';
import 'package:license_app/data/services/import_service.dart';
import 'package:license_app/data/services/xlsx_parser.dart';

void main() {
  group('Excel 题库导入规范校验', () {
    test('读取 A-G 列并归一化判断题答案', () {
      final result = ImportService.validateExcelSheets([
        XlsxSheetData(
          name: '示例',
          rows: const [
            ['选择题', 'C', '1001', '选项A', '选项B', '选项C', '选项D'],
            ['判断题', '正确', '1002', '正确', '错误', '', ''],
          ],
        ),
      ]);

      expect(result.isValid, isTrue);
      expect(result.rows, hasLength(2));
      expect(result.rows.first.answer, 'C');
      expect(result.rows.last.answer, 'A');
      expect(result.rows.last.type, 'judge');
    });

    test('拒绝重复题目编号', () {
      final result = ImportService.validateExcelSheets([
        XlsxSheetData(
          name: '示例',
          rows: const [
            ['题目一', 'A', '1001', 'A1', 'B1', '', ''],
            ['题目二', 'B', '1001', 'A2', 'B2', '', ''],
          ],
        ),
      ]);

      expect(result.isValid, isFalse);
      expect(result.message, contains('题目编号 1001 重复'));
    });

    test('拒绝没有对应选项的答案', () {
      final result = ImportService.validateExcelSheets([
        XlsxSheetData(
          name: '示例',
          rows: const [
            ['题目', 'D', '1001', 'A1', 'B1', 'C1', ''],
          ],
        ),
      ]);

      expect(result.isValid, isFalse);
      expect(result.message, contains('正确答案 D 没有对应的选项内容'));
    });
  });
}
