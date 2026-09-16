import 'dart:convert';

class Note {
  final int? id;
  final String questionId;
  final String content;
  final String? handwritingData;
  final int noteType;
  final String? createdAt;
  final String? updatedAt;

  Note({
    this.id,
    required this.questionId,
    required this.content,
    this.handwritingData,
    this.noteType = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as int?,
      questionId: map['question_id'] as String,
      content: map['content'] as String? ?? '',
      handwritingData: map['handwriting_data'] as String?,
      noteType: map['note_type'] as int? ?? 0,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question_id': questionId,
      'content': content,
      'handwriting_data': handwritingData,
      'note_type': noteType,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  Note copyWith({
    int? id,
    String? questionId,
    String? content,
    String? handwritingData,
    int? noteType,
    String? createdAt,
    String? updatedAt,
  }) {
    return Note(
      id: id ?? this.id,
      questionId: questionId ?? this.questionId,
      content: content ?? this.content,
      handwritingData: handwritingData ?? this.handwritingData,
      noteType: noteType ?? this.noteType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class StrokePoint {
  final double x;
  final double y;
  final double pressure;

  StrokePoint({
    required this.x,
    required this.y,
    this.pressure = 1.0,
  });

  factory StrokePoint.fromJson(Map<String, dynamic> json) {
    return StrokePoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      pressure: (json['pressure'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'pressure': pressure,
    };
  }
}

class HandwritingStroke {
  final List<StrokePoint> points;
  final String color;
  final double strokeWidth;

  HandwritingStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });

  factory HandwritingStroke.fromJson(Map<String, dynamic> json) {
    return HandwritingStroke(
      points: (json['points'] as List<dynamic>)
          .map((p) => StrokePoint.fromJson(p as Map<String, dynamic>))
          .toList(),
      color: json['color'] as String? ?? '#000000',
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 2.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'points': points.map((p) => p.toJson()).toList(),
      'color': color,
      'strokeWidth': strokeWidth,
    };
  }
}

class HandwritingData {
  final List<HandwritingStroke> strokes;
  final double canvasWidth;
  final double canvasHeight;

  HandwritingData({
    required this.strokes,
    required this.canvasWidth,
    required this.canvasHeight,
  });

  factory HandwritingData.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return HandwritingData(
      strokes: (json['strokes'] as List<dynamic>?)
              ?.map((s) => HandwritingStroke.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      canvasWidth: (json['canvasWidth'] as num?)?.toDouble() ?? 300,
      canvasHeight: (json['canvasHeight'] as num?)?.toDouble() ?? 400,
    );
  }

  String toJson() {
    return jsonEncode({
      'strokes': strokes.map((s) => s.toJson()).toList(),
      'canvasWidth': canvasWidth,
      'canvasHeight': canvasHeight,
    });
  }

  factory HandwritingData.empty() {
    return HandwritingData(
      strokes: [],
      canvasWidth: 300,
      canvasHeight: 400,
    );
  }
}
