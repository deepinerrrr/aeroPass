import 'dart:convert';
import 'note_model.dart';

/// 背题模式下正确选项文本的底色标注范围。
class TextHighlight {
  final int start;
  final int end;
  final String color;

  const TextHighlight({
    required this.start,
    required this.end,
    this.color = '#FFF176',
  });

  bool overlaps(int s, int e) => start < e && s < end;

  factory TextHighlight.fromJson(Map<String, dynamic> json) {
    return TextHighlight(
      start: (json['start'] as num).toInt(),
      end: (json['end'] as num).toInt(),
      color: json['color'] as String? ?? '#FFF176',
    );
  }

  Map<String, dynamic> toJson() => {'start': start, 'end': end, 'color': color};
}

/// 背题模式下某道题的全部标注：文字底色标注 + 自由圈画笔迹。
class MemorizeAnnotation {
  final String questionId;
  final List<TextHighlight> highlights;
  final List<HandwritingStroke> strokes;

  MemorizeAnnotation({
    required this.questionId,
    List<TextHighlight>? highlights,
    List<HandwritingStroke>? strokes,
  })  : highlights = highlights ?? [],
        strokes = strokes ?? [];

  bool get isEmpty => highlights.isEmpty && strokes.isEmpty;

  static List<TextHighlight> _parseHighlights(String? source) {
    if (source == null || source.isEmpty) return [];
    try {
      final list = jsonDecode(source) as List<dynamic>;
      return list
          .map((e) => TextHighlight.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static List<HandwritingStroke> _parseStrokes(String? source) {
    if (source == null || source.isEmpty) return [];
    try {
      final list = jsonDecode(source) as List<dynamic>;
      return list
          .map((e) => HandwritingStroke.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  factory MemorizeAnnotation.fromMap(Map<String, dynamic> map) {
    return MemorizeAnnotation(
      questionId: map['question_id'] as String,
      highlights: _parseHighlights(map['highlights'] as String?),
      strokes: _parseStrokes(map['strokes'] as String?),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'question_id': questionId,
      'highlights': jsonEncode(highlights.map((h) => h.toJson()).toList()),
      'strokes': jsonEncode(strokes.map((s) => s.toJson()).toList()),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}
