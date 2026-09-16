class Question {
  final int? id;
  final String questionId;
  final String content;
  final String? optionA;
  final String? optionB;
  final String? optionC;
  final String? optionD;
  final String answer;
  final String? referenceAnswer;
  final String type;
  final String? sheetName;
  final int? bankId;

  Question({
    this.id,
    required this.questionId,
    required this.content,
    this.optionA,
    this.optionB,
    this.optionC,
    this.optionD,
    required this.answer,
    this.referenceAnswer,
    required this.type,
    this.sheetName,
    this.bankId,
  });

  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      id: map['id'] as int?,
      questionId: map['question_id'] as String,
      content: map['content'] as String,
      optionA: map['option_a'] as String?,
      optionB: map['option_b'] as String?,
      optionC: map['option_c'] as String?,
      optionD: map['option_d'] as String?,
      answer: map['answer'] as String,
      referenceAnswer: map['reference_answer'] as String?,
      type: map['type'] as String? ?? 'single',
      sheetName: map['sheet_name'] as String?,
      bankId: map['bank_id'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question_id': questionId,
      'content': content,
      'option_a': optionA,
      'option_b': optionB,
      'option_c': optionC,
      'option_d': optionD,
      'answer': answer,
      'reference_answer': referenceAnswer,
      'type': type,
      'sheet_name': sheetName,
      'bank_id': bankId,
    };
  }

  List<String> get options {
    final list = <String>[];
    if (optionA != null && optionA!.isNotEmpty) list.add(optionA!);
    if (optionB != null && optionB!.isNotEmpty) list.add(optionB!);
    if (optionC != null && optionC!.isNotEmpty) list.add(optionC!);
    if (optionD != null && optionD!.isNotEmpty) list.add(optionD!);
    return list;
  }

  List<String> get optionLabels {
    if (type == 'judge') return ['A', 'B'];
    return ['A', 'B', 'C', 'D'];
  }

  String get correctOptionText {
    switch (answer.toUpperCase()) {
      case 'A': return optionA ?? '';
      case 'B': return optionB ?? '';
      case 'C': return optionC ?? '';
      case 'D': return optionD ?? '';
      default: return answer;
    }
  }

  bool get isJudge => type == 'judge';

  /// 是否属于“正确答案为四个选项中文本最长”的题目。
  /// 仅对单选题（非判断题）且四个选项均非空时判定；
  /// 正确答案文本长度需严格大于其余三个选项的文本长度。
  bool get isLongestAnswerQuestion {
    if (isJudge) return false;
    final a = optionA ?? '';
    final b = optionB ?? '';
    final c = optionC ?? '';
    final d = optionD ?? '';
    if (a.isEmpty || b.isEmpty || c.isEmpty || d.isEmpty) return false;
    final ans = answer.toUpperCase();
    int? correctLen;
    switch (ans) {
      case 'A':
        correctLen = a.length;
        break;
      case 'B':
        correctLen = b.length;
        break;
      case 'C':
        correctLen = c.length;
        break;
      case 'D':
        correctLen = d.length;
        break;
      default:
        return false;
    }
    return correctLen > a.length &&
        correctLen > b.length &&
        correctLen > c.length &&
        correctLen > d.length;
  }
}

/// 合集来源信息：父题目 + 创建合集时使用的关键词。
class ParentQuestionInfo {
  final Question question;
  final String keywords;

  const ParentQuestionInfo({required this.question, required this.keywords});
}

/// 合集列表项信息：关键词 + 收录题目数量。
class CollectionInfo {
  final String keyword;
  final int questionCount;

  const CollectionInfo({required this.keyword, required this.questionCount});
}
