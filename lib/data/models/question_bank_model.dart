class QuestionBank {
  final int? id;
  final String name;
  final String source; // 'asset' | 'file'
  final String? filePath;
  final int totalCount;
  final String sheetNames; // 逗号分隔
  final String createdAt;
  final int isActive;

  QuestionBank({
    this.id,
    required this.name,
    this.source = 'asset',
    this.filePath,
    this.totalCount = 0,
    this.sheetNames = '',
    required this.createdAt,
    this.isActive = 0,
  });

  factory QuestionBank.fromMap(Map<String, dynamic> map) {
    return QuestionBank(
      id: map['id'] as int?,
      name: map['name'] as String,
      source: map['source'] as String? ?? 'asset',
      filePath: map['file_path'] as String?,
      totalCount: map['total_count'] as int? ?? 0,
      sheetNames: map['sheet_names'] as String? ?? '',
      createdAt: map['created_at'] as String,
      isActive: map['is_active'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'source': source,
      'file_path': filePath,
      'total_count': totalCount,
      'sheet_names': sheetNames,
      'created_at': createdAt,
      'is_active': isActive,
    };
  }

  List<String> get sheetNameList =>
      sheetNames.isEmpty ? <String>[] : sheetNames.split(',');

  bool get isActiveBank => isActive == 1;
  bool get isFromFile => source == 'file';
}
