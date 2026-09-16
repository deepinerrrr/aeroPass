import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class XlsxSheetData {
  final String name;
  final List<List<String>> rows;

  XlsxSheetData({required this.name, required this.rows});
}

class XlsxParser {
  static List<XlsxSheetData> parse(String filePath) {
    final file = File(filePath);
    final bytes = file.readAsBytesSync();
    return parseBytes(bytes);
  }

  static List<XlsxSheetData> parseBytes(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    // 1. 读取共享字符串表
    final sharedStrings = _readSharedStrings(archive);

    // 2. 读取工作簿获取工作表名称映射
    final sheetNames = _readSheetNames(archive);

    // 3. 逐个读取工作表
    final result = <XlsxSheetData>[];
    for (int i = 0; i < sheetNames.length; i++) {
      final sheetFileName = 'xl/worksheets/sheet${i + 1}.xml';
      final sheetFile = archive.findFile(sheetFileName);
      if (sheetFile == null) continue;

      final content = _decodeContent(sheetFile.content as List<int>);
      final rows = _parseSheetXml(content, sharedStrings);
      result.add(XlsxSheetData(name: sheetNames[i], rows: rows));
    }

    return result;
  }

  static String _decodeContent(List<int> data) {
    return utf8.decode(data, allowMalformed: true);
  }

  static List<String> _readSharedStrings(Archive archive) {
    final file = archive.findFile('xl/sharedStrings.xml');
    if (file == null) return [];

    final content = _decodeContent(file.content as List<int>);
    final document = XmlDocument.parse(content);

    final strings = <String>[];
    for (final si in document.findAllElements('si')) {
      final sb = StringBuffer();
      for (final t in si.findAllElements('t')) {
        sb.write(t.innerText);
      }
      strings.add(sb.toString());
    }

    return strings;
  }

  static List<String> _readSheetNames(Archive archive) {
    final file = archive.findFile('xl/workbook.xml');
    if (file == null) return ['Sheet1'];

    final content = _decodeContent(file.content as List<int>);
    final document = XmlDocument.parse(content);

    final names = <String>[];
    for (final sheet in document.findAllElements('sheet')) {
      final name = sheet.getAttribute('name') ?? 'Sheet${names.length + 1}';
      names.add(name);
    }

    return names.isEmpty ? ['Sheet1'] : names;
  }

  static List<List<String>> _parseSheetXml(String xmlContent, List<String> sharedStrings) {
    final document = XmlDocument.parse(xmlContent);
    final rows = <List<String>>[];

    for (final rowElement in document.findAllElements('row')) {
      final cells = <int, String>{};
      int maxCol = 0;

      for (final cell in rowElement.findElements('c')) {
        final ref = cell.getAttribute('r') ?? '';
        final colIndex = _colRefToIndex(ref);
        if (colIndex < 0) continue;

        final type = cell.getAttribute('t');
        String value;

        // 优先检查内联字符串 <is><t>...</t></is>
        final isElement = cell.findElements('is').firstOrNull;
        if (isElement != null) {
          final sb = StringBuffer();
          for (final t in isElement.findAllElements('t')) {
            sb.write(t.innerText);
          }
          value = sb.toString();
        } else {
          final vElement = cell.findElements('v').firstOrNull;
          final rawValue = vElement?.innerText ?? '';

          if (type == 's') {
            final idx = int.tryParse(rawValue) ?? -1;
            value = (idx >= 0 && idx < sharedStrings.length) ? sharedStrings[idx] : '';
          } else if (type == 'b') {
            value = (rawValue == '1') ? '正确' : '错误';
          } else if (type == 'e') {
            value = '';
          } else if (type == 'str') {
            value = rawValue;
          } else {
            value = rawValue;
            final asDouble = double.tryParse(value);
            if (asDouble != null && asDouble == asDouble.toInt()) {
              value = asDouble.toInt().toString();
            }
          }
        }

        cells[colIndex] = value;
        if (colIndex > maxCol) maxCol = colIndex;
      }

      final row = List<String>.filled(maxCol + 1, '');
      cells.forEach((col, val) => row[col] = val);
      rows.add(row);
    }

    return rows;
  }

  static int _colRefToIndex(String ref) {
    int i = 0;
    while (i < ref.length && _isAlpha(ref.codeUnitAt(i))) {
      i++;
    }
    if (i == 0) return -1;
    final colPart = ref.substring(0, i);
    return _colLettersToIndex(colPart);
  }

  static bool _isAlpha(int code) =>
      (code >= 65 && code <= 90) || (code >= 97 && code <= 122);

  static int _colLettersToIndex(String letters) {
    int index = 0;
    for (int i = 0; i < letters.length; i++) {
      final ch = letters[i].toUpperCase();
      index = index * 26 + (ch.codeUnitAt(0) - 64);
    }
    return index - 1;
  }
}
