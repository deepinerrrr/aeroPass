class StudyRecord {
  final int? id;
  final String questionId;
  int isCorrect;
  int isFavorite;
  int isMastered;
  int isWrong;
  int practiceCount;
  String? lastPracticeAt;

  StudyRecord({
    this.id,
    required this.questionId,
    this.isCorrect = 0,
    this.isFavorite = 0,
    this.isMastered = 0,
    this.isWrong = 0,
    this.practiceCount = 0,
    this.lastPracticeAt,
  });

  factory StudyRecord.fromMap(Map<String, dynamic> map) {
    return StudyRecord(
      id: map['id'] as int?,
      questionId: map['question_id'] as String,
      isCorrect: map['is_correct'] as int? ?? 0,
      isFavorite: map['is_favorite'] as int? ?? 0,
      isMastered: map['is_mastered'] as int? ?? 0,
      isWrong: map['is_wrong'] as int? ?? 0,
      practiceCount: map['practice_count'] as int? ?? 0,
      lastPracticeAt: map['last_practice_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question_id': questionId,
      'is_correct': isCorrect,
      'is_favorite': isFavorite,
      'is_mastered': isMastered,
      'is_wrong': isWrong,
      'practice_count': practiceCount,
      'last_practice_at': lastPracticeAt,
    };
  }

  bool get isFavorited => isFavorite == 1;
  bool get isMasteredFlag => isMastered == 1;
  bool get isWrongFlag => isWrong == 1;
  bool get isCorrectFlag => isCorrect == 1;
}
