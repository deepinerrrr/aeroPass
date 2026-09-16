import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/question_model.dart';
import '../models/study_record_model.dart';
import '../models/note_model.dart';
import '../models/question_bank_model.dart';
import '../models/annotation_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'license_app.db');

    return await openDatabase(
      path,
      version: 8,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE question_banks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        source TEXT DEFAULT 'asset',
        file_path TEXT,
        total_count INTEGER DEFAULT 0,
        sheet_names TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        is_active INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE questions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question_id TEXT UNIQUE NOT NULL,
        content TEXT NOT NULL,
        option_a TEXT,
        option_b TEXT,
        option_c TEXT,
        option_d TEXT,
        answer TEXT NOT NULL,
        reference_answer TEXT,
        type TEXT NOT NULL DEFAULT 'single',
        sheet_name TEXT,
        bank_id INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE study_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question_id TEXT UNIQUE NOT NULL,
        is_correct INTEGER DEFAULT 0,
        is_favorite INTEGER DEFAULT 0,
        is_mastered INTEGER DEFAULT 0,
        is_wrong INTEGER DEFAULT 0,
        practice_count INTEGER DEFAULT 0,
        last_practice_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mode TEXT NOT NULL,
        sub_mode TEXT NOT NULL,
        sheet_name TEXT,
        current_index INTEGER DEFAULT 0,
        total_count INTEGER DEFAULT 0,
        correct_count INTEGER DEFAULT 0,
        updated_at TEXT,
        bank_id INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE ai_chat_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question_id TEXT NOT NULL,
        messages TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE mock_exam_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        correct_count INTEGER NOT NULL,
        total_count INTEGER NOT NULL,
        score REAL NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question_id TEXT NOT NULL,
        content TEXT DEFAULT '',
        handwriting_data TEXT,
        note_type INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE developer_config (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        config_key TEXT UNIQUE NOT NULL,
        config_value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE related_questions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bank_id INTEGER NOT NULL DEFAULT 0,
        question_id TEXT NOT NULL,
        related_question_id TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        keywords TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        UNIQUE(bank_id, question_id, related_question_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE memorize_annotations (
        question_id TEXT PRIMARY KEY,
        highlights TEXT DEFAULT '[]',
        strokes TEXT DEFAULT '[]',
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_memorize_annotations_question ON memorize_annotations(question_id)',
    );

    await db.execute(
      'CREATE INDEX idx_questions_sheet ON questions(sheet_name)',
    );
    await db.execute('CREATE INDEX idx_questions_id ON questions(question_id)');
    await db.execute('CREATE INDEX idx_questions_bank ON questions(bank_id)');
    await db.execute('CREATE INDEX idx_study_wrong ON study_records(is_wrong)');
    await db.execute(
      'CREATE INDEX idx_study_favorite ON study_records(is_favorite)',
    );
    await db.execute(
      'CREATE INDEX idx_study_mastered ON study_records(is_mastered)',
    );
    await db.execute(
      'CREATE INDEX idx_ai_chat_question ON ai_chat_history(question_id)',
    );
    await db.execute('CREATE INDEX idx_notes_question ON notes(question_id)');
    await db.execute(
      'CREATE INDEX idx_developer_config_key ON developer_config(config_key)',
    );
    await db.execute(
      'CREATE INDEX idx_related_questions_question ON related_questions(bank_id, question_id, sort_order)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE questions ADD COLUMN reference_answer TEXT',
      );
      await db.execute('''
        CREATE TABLE ai_chat_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          question_id TEXT NOT NULL,
          messages TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_ai_chat_question ON ai_chat_history(question_id)',
      );
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE mock_exam_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          correct_count INTEGER NOT NULL,
          total_count INTEGER NOT NULL,
          score REAL NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE notes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          question_id TEXT NOT NULL,
          content TEXT DEFAULT '',
          handwriting_data TEXT,
          note_type INTEGER DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE developer_config (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          config_key TEXT UNIQUE NOT NULL,
          config_value TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await db.execute('CREATE INDEX idx_notes_question ON notes(question_id)');
      await db.execute(
        'CREATE INDEX idx_developer_config_key ON developer_config(config_key)',
      );
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE question_banks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          source TEXT DEFAULT 'asset',
          file_path TEXT,
          total_count INTEGER DEFAULT 0,
          sheet_names TEXT DEFAULT '',
          created_at TEXT NOT NULL,
          is_active INTEGER DEFAULT 0
        )
      ''');
      await db.execute('ALTER TABLE questions ADD COLUMN bank_id INTEGER');
      await db.execute('ALTER TABLE progress ADD COLUMN bank_id INTEGER');
      await db.execute('CREATE INDEX idx_questions_bank ON questions(bank_id)');

      // 迁移现有数据：为已存在的题目创建默认题库
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM questions',
      );
      final count = Sqflite.firstIntValue(countResult) ?? 0;

      if (count > 0) {
        final sheetResult = await db.rawQuery(
          'SELECT DISTINCT sheet_name FROM questions WHERE sheet_name IS NOT NULL',
        );
        final sheetNames = sheetResult
            .map((e) => e['sheet_name'] as String)
            .join(',');

        final now = DateTime.now().toIso8601String();
        await db.insert('question_banks', {
          'name': '默认题库',
          'source': 'asset',
          'file_path': null,
          'total_count': count,
          'sheet_names': sheetNames,
          'created_at': now,
          'is_active': 1,
        });

        final bankResult = await db.rawQuery(
          'SELECT last_insert_rowid() as id',
        );
        final bankId = bankResult.first['id'];

        await db.rawUpdate('UPDATE questions SET bank_id = ?', [bankId]);
        await db.rawUpdate('UPDATE progress SET bank_id = ?', [bankId]);
      }
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE related_questions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          bank_id INTEGER NOT NULL DEFAULT 0,
          question_id TEXT NOT NULL,
          related_question_id TEXT NOT NULL,
          sort_order INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          UNIQUE(bank_id, question_id, related_question_id)
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_related_questions_question ON related_questions(bank_id, question_id, sort_order)',
      );
    }
    if (oldVersion < 7) {
      await db.execute(
        "ALTER TABLE related_questions ADD COLUMN keywords TEXT DEFAULT ''",
      );
    }
    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE memorize_annotations (
          question_id TEXT PRIMARY KEY,
          highlights TEXT DEFAULT '[]',
          strokes TEXT DEFAULT '[]',
          updated_at TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_memorize_annotations_question ON memorize_annotations(question_id)',
      );
    }
  }

  // ============ 高级筛选：答案最长题 ============

  /// 返回判定“正确答案为四个选项中文本最长”题目的 SQL 布尔表达式。
  /// [alias] 用于 JOIN 查询中限定 questions 表别名（如 'q'）。
  static String _longestAnswerCondition({String alias = ''}) {
    final p = alias.isEmpty ? '' : '$alias.';
    return [
      "(${p}type != 'judge'",
      "AND ${p}option_a IS NOT NULL AND ${p}option_a != ''",
      "AND ${p}option_b IS NOT NULL AND ${p}option_b != ''",
      "AND ${p}option_c IS NOT NULL AND ${p}option_c != ''",
      "AND ${p}option_d IS NOT NULL AND ${p}option_d != ''",
      'AND (',
      "(${p}answer = 'A' AND LENGTH(${p}option_a) > LENGTH(${p}option_b) AND LENGTH(${p}option_a) > LENGTH(${p}option_c) AND LENGTH(${p}option_a) > LENGTH(${p}option_d))",
      "OR (${p}answer = 'B' AND LENGTH(${p}option_b) > LENGTH(${p}option_a) AND LENGTH(${p}option_b) > LENGTH(${p}option_c) AND LENGTH(${p}option_b) > LENGTH(${p}option_d))",
      "OR (${p}answer = 'C' AND LENGTH(${p}option_c) > LENGTH(${p}option_a) AND LENGTH(${p}option_c) > LENGTH(${p}option_b) AND LENGTH(${p}option_c) > LENGTH(${p}option_d))",
      "OR (${p}answer = 'D' AND LENGTH(${p}option_d) > LENGTH(${p}option_a) AND LENGTH(${p}option_d) > LENGTH(${p}option_b) AND LENGTH(${p}option_d) > LENGTH(${p}option_c))",
      '))',
    ].join(' ');
  }

  /// 统计题库中“正确答案为四个选项中文本最长”的题目数量。
  Future<int> getLongestAnswerCount({int? bankId}) async {
    final db = await database;
    final cond = _longestAnswerCondition();
    if (bankId != null) {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM questions WHERE bank_id = ? AND $cond',
        [bankId],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    }
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM questions WHERE $cond',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ============ 题库管理 ============

  Future<QuestionBank?> getActiveBank() async {
    final db = await database;
    final result = await db.query(
      'question_banks',
      where: 'is_active = 1',
      limit: 1,
    );
    if (result.isEmpty) return null;
    return QuestionBank.fromMap(result.first);
  }

  Future<QuestionBank?> getBankById(int bankId) async {
    final db = await database;
    final result = await db.query(
      'question_banks',
      where: 'id = ?',
      whereArgs: [bankId],
    );
    if (result.isEmpty) return null;
    return QuestionBank.fromMap(result.first);
  }

  Future<List<QuestionBank>> getAllBanks() async {
    final db = await database;
    final result = await db.query('question_banks', orderBy: 'id ASC');
    return result.map((e) => QuestionBank.fromMap(e)).toList();
  }

  /// 获取随应用内置的默认题库。
  ///
  /// 默认题库以 source=asset 为准，名称仅作为兼容旧数据的兜底，避免用户
  /// 切换到导入题库后误把导入题目加入“默认题库判断题”合集。
  Future<QuestionBank?> getDefaultBank() async {
    final db = await database;
    var result = await db.query(
      'question_banks',
      where: "source = 'asset'",
      orderBy: 'id ASC',
      limit: 1,
    );
    if (result.isEmpty) {
      result = await db.query(
        'question_banks',
        where: 'name = ?',
        whereArgs: ['默认题库'],
        orderBy: 'id ASC',
        limit: 1,
      );
    }
    if (result.isEmpty) return null;
    return QuestionBank.fromMap(result.first);
  }

  Future<int> insertQuestionBank(QuestionBank bank) async {
    final db = await database;
    // 如果设置为激活，先取消其他题库的激活状态
    if (bank.isActive == 1) {
      await db.rawUpdate('UPDATE question_banks SET is_active = 0');
    }
    return await db.insert('question_banks', bank.toMap());
  }

  Future<void> setActiveBank(int bankId) async {
    final db = await database;
    await db.rawUpdate('UPDATE question_banks SET is_active = 0');
    await db.update(
      'question_banks',
      {'is_active': 1},
      where: 'id = ?',
      whereArgs: [bankId],
    );
  }

  Future<void> updateBankQuestionCount(int bankId) async {
    final db = await database;
    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM questions WHERE bank_id = ?',
      [bankId],
    );
    final count = Sqflite.firstIntValue(countResult) ?? 0;

    final sheetResult = await db.rawQuery(
      'SELECT DISTINCT sheet_name FROM questions WHERE bank_id = ? AND sheet_name IS NOT NULL',
      [bankId],
    );
    final sheetNames = sheetResult
        .map((e) => e['sheet_name'] as String)
        .join(',');

    await db.update(
      'question_banks',
      {'total_count': count, 'sheet_names': sheetNames},
      where: 'id = ?',
      whereArgs: [bankId],
    );
  }

  Future<void> deleteQuestionBank(int bankId) async {
    final db = await database;
    await db.delete(
      'related_questions',
      where: 'bank_id = ?',
      whereArgs: [bankId],
    );
    // 获取该题库下的所有 question_id，用于级联删除
    final questionIds = await db.rawQuery(
      'SELECT question_id FROM questions WHERE bank_id = ?',
      [bankId],
    );
    final ids = questionIds.map((e) => e['question_id'] as String).toList();

    await db.delete('questions', where: 'bank_id = ?', whereArgs: [bankId]);
    await db.delete('progress', where: 'bank_id = ?', whereArgs: [bankId]);

    // 删除关联的 study_records、notes、ai_chat_history
    if (ids.isNotEmpty) {
      final placeholders = ids.map((_) => '?').join(',');
      await db.delete(
        'study_records',
        where: 'question_id IN ($placeholders)',
        whereArgs: ids,
      );
      await db.delete(
        'notes',
        where: 'question_id IN ($placeholders)',
        whereArgs: ids,
      );
      await db.delete(
        'ai_chat_history',
        where: 'question_id IN ($placeholders)',
        whereArgs: ids,
      );
    }

    await db.delete('question_banks', where: 'id = ?', whereArgs: [bankId]);

    // 如果删除的是当前激活题库，激活第一个剩余题库
    final remaining = await db.query(
      'question_banks',
      orderBy: 'id ASC',
      limit: 1,
    );
    if (remaining.isNotEmpty) {
      await db.update(
        'question_banks',
        {'is_active': 1},
        where: 'id = ?',
        whereArgs: [remaining.first['id']],
      );
    }
  }

  // ============ 题目操作 ============

  Future<List<Question>> getRelatedQuestions(
    String questionId, {
    int? bankId,
  }) async {
    final db = await database;
    final scope = bankId ?? 0;
    final result = bankId == null
        ? await db.rawQuery(
            '''
            SELECT q.* FROM related_questions r
            INNER JOIN questions q ON q.question_id = r.related_question_id
            WHERE r.bank_id = ? AND r.question_id = ? AND q.bank_id IS NULL
            ORDER BY r.sort_order ASC
          ''',
            [scope, questionId],
          )
        : await db.rawQuery(
            '''
            SELECT q.* FROM related_questions r
            INNER JOIN questions q ON q.question_id = r.related_question_id
            WHERE r.bank_id = ? AND r.question_id = ? AND q.bank_id = ?
            ORDER BY r.sort_order ASC
          ''',
            [scope, questionId, bankId],
          );
    return result.map((e) => Question.fromMap(e)).toList();
  }

  Future<void> saveRelatedQuestions(
    String questionId,
    List<Question> related, {
    int? bankId,
    Map<String, String>? keywords,
  }) async {
    final db = await database;
    final scope = bankId ?? 0;
    await db.transaction((txn) async {
      final newIds = related.map((e) => e.questionId).toSet();
      // 删除不再保留的关联
      if (newIds.isEmpty) {
        await txn.delete(
          'related_questions',
          where: 'bank_id = ? AND question_id = ?',
          whereArgs: [scope, questionId],
        );
      } else {
        final placeholders = newIds.map((_) => '?').join(',');
        await txn.rawDelete(
          'DELETE FROM related_questions WHERE bank_id = ? AND question_id = ? '
          'AND related_question_id NOT IN ($placeholders)',
          [scope, questionId, ...newIds],
        );
      }
      final now = DateTime.now().toIso8601String();
      for (var index = 0; index < related.length; index++) {
        final rid = related[index].questionId;
        final kw = (keywords?[rid] ?? '').trim();
        // 新关联写入关键词；已存在的关联保留原关键词（IGNORE）
        await txn.insert('related_questions', {
          'bank_id': scope,
          'question_id': questionId,
          'related_question_id': rid,
          'sort_order': index,
          'keywords': kw,
          'created_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        // 更新排序
        await txn.update(
          'related_questions',
          {'sort_order': index},
          where: 'bank_id = ? AND question_id = ? AND related_question_id = ?',
          whereArgs: [scope, questionId, rid],
        );
      }
    });
  }

  /// 批量查询哪些题目被添加到了其他题目的合集中。
  /// 返回 Map: related_question_id -> 该题目所属的父合集信息列表（含创建关键词）。
  Future<Map<String, List<ParentQuestionInfo>>> getBulkParentQuestions(
    List<String> questionIds, {
    int? bankId,
  }) async {
    if (questionIds.isEmpty) return {};
    final db = await database;
    final scope = bankId ?? 0;
    final placeholders = questionIds.map((_) => '?').join(',');
    final result = bankId == null
        ? await db.rawQuery(
            '''
            SELECT r.related_question_id AS rid, r.keywords AS rkw, q.* FROM related_questions r
            INNER JOIN questions q ON q.question_id = r.question_id
            WHERE r.bank_id = ? AND r.related_question_id IN ($placeholders)
              AND q.bank_id IS NULL
            ORDER BY r.created_at DESC
          ''',
            [scope, ...questionIds],
          )
        : await db.rawQuery(
            '''
            SELECT r.related_question_id AS rid, r.keywords AS rkw, q.* FROM related_questions r
            INNER JOIN questions q ON q.question_id = r.question_id
            WHERE r.bank_id = ? AND r.related_question_id IN ($placeholders)
              AND q.bank_id = ?
            ORDER BY r.created_at DESC
          ''',
            [scope, ...questionIds, bankId],
          );
    final map = <String, List<ParentQuestionInfo>>{};
    for (final row in result) {
      final rid = row['rid'] as String;
      final kw = (row['rkw'] as String?) ?? '';
      map
          .putIfAbsent(rid, () => [])
          .add(
            ParentQuestionInfo(question: Question.fromMap(row), keywords: kw),
          );
    }
    return map;
  }

  /// 批量查询哪些题目拥有合集（即作为 question_id 出现在 related_questions 中）。
  Future<Set<String>> getQuestionIdsWithRelated(
    List<String> questionIds, {
    int? bankId,
  }) async {
    if (questionIds.isEmpty) return {};
    final db = await database;
    final scope = bankId ?? 0;
    final placeholders = questionIds.map((_) => '?').join(',');
    final result = await db.rawQuery(
      'SELECT DISTINCT question_id FROM related_questions WHERE bank_id = ? AND question_id IN ($placeholders)',
      [scope, ...questionIds],
    );
    return result.map((e) => e['question_id'] as String).toSet();
  }

  /// 批量查询哪些题目被添加到了合集（即作为 related_question_id 出现）。
  Future<Set<String>> getQuestionIdsInRelated(
    List<String> questionIds, {
    int? bankId,
  }) async {
    if (questionIds.isEmpty) return {};
    final db = await database;
    final scope = bankId ?? 0;
    final placeholders = questionIds.map((_) => '?').join(',');
    final result = await db.rawQuery(
      'SELECT DISTINCT related_question_id FROM related_questions WHERE bank_id = ? AND related_question_id IN ($placeholders)',
      [scope, ...questionIds],
    );
    return result.map((e) => e['related_question_id'] as String).toSet();
  }

  /// 批量查询哪些题目存在用户笔记（有文字内容或手写数据）。
  Future<Set<String>> getQuestionIdsWithNotes(List<String> questionIds) async {
    if (questionIds.isEmpty) return {};
    final db = await database;
    final placeholders = questionIds.map((_) => '?').join(',');
    final result = await db.rawQuery(
      'SELECT DISTINCT question_id FROM notes WHERE question_id IN ($placeholders) AND (content != "" OR handwriting_data IS NOT NULL)',
      questionIds,
    );
    return result.map((e) => e['question_id'] as String).toSet();
  }

  /// 批量查询已掌握题目。分批执行以避免大型题库超过 SQLite 参数上限。
  Future<Set<String>> getMasteredQuestionIds(List<String> questionIds) async {
    if (questionIds.isEmpty) return {};
    final db = await database;
    final masteredIds = <String>{};
    const batchSize = 800;
    for (var start = 0; start < questionIds.length; start += batchSize) {
      final end = (start + batchSize).clamp(0, questionIds.length);
      final batch = questionIds.sublist(start, end);
      final placeholders = batch.map((_) => '?').join(',');
      final result = await db.rawQuery(
        'SELECT question_id FROM study_records '
        'WHERE is_mastered = 1 AND question_id IN ($placeholders)',
        batch,
      );
      masteredIds.addAll(result.map((row) => row['question_id'] as String));
    }
    return masteredIds;
  }

  Future<void> insertQuestions(List<Question> questions) async {
    final db = await database;
    final batch = db.batch();
    for (final q in questions) {
      batch.insert(
        'questions',
        q.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<int> getQuestionCount({
    int? bankId,
    bool excludeLongestAnswer = false,
  }) async {
    final db = await database;
    final extra = excludeLongestAnswer
        ? ' AND NOT ${_longestAnswerCondition()}'
        : '';
    if (bankId != null) {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM questions WHERE bank_id = ?$extra',
        [bankId],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    }
    final where = extra.isEmpty ? '' : 'WHERE NOT ${_longestAnswerCondition()}';
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM questions $where',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getQuestionCountBySheet(
    String sheetName, {
    int? bankId,
    bool excludeLongestAnswer = false,
  }) async {
    final db = await database;
    final extra = excludeLongestAnswer
        ? ' AND NOT ${_longestAnswerCondition()}'
        : '';
    if (bankId != null) {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM questions WHERE sheet_name = ? AND bank_id = ?$extra',
        [sheetName, bankId],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    }
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM questions WHERE sheet_name = ?$extra',
      [sheetName],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<String>> getSheetNames({int? bankId}) async {
    final db = await database;
    if (bankId != null) {
      final result = await db.rawQuery(
        'SELECT DISTINCT sheet_name FROM questions WHERE sheet_name IS NOT NULL AND bank_id = ?',
        [bankId],
      );
      return result.map((e) => e['sheet_name'] as String).toList();
    }
    final result = await db.rawQuery(
      'SELECT DISTINCT sheet_name FROM questions WHERE sheet_name IS NOT NULL',
    );
    return result.map((e) => e['sheet_name'] as String).toList();
  }

  Future<List<Question>> getQuestionsBySheet(
    String sheetName, {
    int limit = 50,
    int offset = 0,
    int? bankId,
    bool excludeLongestAnswer = false,
  }) async {
    final db = await database;
    final extra = excludeLongestAnswer
        ? ' AND NOT ${_longestAnswerCondition()}'
        : '';
    if (bankId != null) {
      final result = await db.rawQuery(
        'SELECT * FROM questions WHERE sheet_name = ? AND bank_id = ?$extra '
        'ORDER BY question_id ASC LIMIT ? OFFSET ?',
        [sheetName, bankId, limit, offset],
      );
      return result.map((e) => Question.fromMap(e)).toList();
    }
    final result = await db.rawQuery(
      'SELECT * FROM questions WHERE sheet_name = ?$extra '
      'ORDER BY question_id ASC LIMIT ? OFFSET ?',
      [sheetName, limit, offset],
    );
    return result.map((e) => Question.fromMap(e)).toList();
  }

  Future<List<Question>> getAllQuestions({
    int limit = 50,
    int offset = 0,
    int? bankId,
    bool excludeLongestAnswer = false,
  }) async {
    final db = await database;
    final extra = excludeLongestAnswer
        ? ' AND NOT ${_longestAnswerCondition()}'
        : '';
    if (bankId != null) {
      final result = await db.rawQuery(
        'SELECT * FROM questions WHERE bank_id = ?$extra '
        'ORDER BY question_id ASC LIMIT ? OFFSET ?',
        [bankId, limit, offset],
      );
      return result.map((e) => Question.fromMap(e)).toList();
    }
    final where = extra.isEmpty ? '' : 'WHERE NOT ${_longestAnswerCondition()}';
    final result = await db.rawQuery(
      'SELECT * FROM questions $where '
      'ORDER BY question_id ASC LIMIT ? OFFSET ?',
      [limit, offset],
    );
    return result.map((e) => Question.fromMap(e)).toList();
  }

  Future<List<Question>> getRandomQuestions({
    int limit = 50,
    int? bankId,
    bool excludeLongestAnswer = false,
  }) async {
    final db = await database;
    final extra = excludeLongestAnswer
        ? ' AND NOT ${_longestAnswerCondition()}'
        : '';
    if (bankId != null) {
      final result = await db.rawQuery(
        'SELECT * FROM questions WHERE bank_id = ?$extra ORDER BY RANDOM() LIMIT ?',
        [bankId, limit],
      );
      return result.map((e) => Question.fromMap(e)).toList();
    }
    final where = extra.isEmpty ? '' : 'WHERE NOT ${_longestAnswerCondition()}';
    final result = await db.rawQuery(
      'SELECT * FROM questions $where ORDER BY RANDOM() LIMIT ?',
      [limit],
    );
    return result.map((e) => Question.fromMap(e)).toList();
  }

  Future<List<Question>> searchQuestions(
    String keyword, {
    int? limit,
    int? bankId,
  }) async {
    final db = await database;
    if (bankId != null) {
      final result = await db.query(
        'questions',
        where: '(content LIKE ? OR question_id LIKE ?) AND bank_id = ?',
        whereArgs: ['%$keyword%', '%$keyword%', bankId],
        limit: limit,
        orderBy: 'question_id ASC',
      );
      return result.map((e) => Question.fromMap(e)).toList();
    }
    final result = await db.query(
      'questions',
      where: 'content LIKE ? OR question_id LIKE ?',
      whereArgs: ['%$keyword%', '%$keyword%'],
      limit: limit,
      orderBy: 'question_id ASC',
    );
    return result.map((e) => Question.fromMap(e)).toList();
  }

  Future<Question?> getQuestionByIndex(
    int index, {
    String? sheetName,
    int? bankId,
    bool excludeLongestAnswer = false,
  }) async {
    final db = await database;
    final extra = excludeLongestAnswer
        ? ' AND NOT ${_longestAnswerCondition()}'
        : '';
    final where = extra.isEmpty ? '' : 'WHERE NOT ${_longestAnswerCondition()}';
    List<Map<String, dynamic>> result;
    if (sheetName != null && bankId != null) {
      result = await db.rawQuery(
        'SELECT * FROM questions WHERE sheet_name = ? AND bank_id = ?$extra ORDER BY question_id ASC LIMIT 1 OFFSET ?',
        [sheetName, bankId, index],
      );
    } else if (sheetName != null) {
      result = await db.rawQuery(
        'SELECT * FROM questions WHERE sheet_name = ?$extra ORDER BY question_id ASC LIMIT 1 OFFSET ?',
        [sheetName, index],
      );
    } else if (bankId != null) {
      result = await db.rawQuery(
        'SELECT * FROM questions WHERE bank_id = ?$extra ORDER BY question_id ASC LIMIT 1 OFFSET ?',
        [bankId, index],
      );
    } else {
      result = await db.rawQuery(
        'SELECT * FROM questions $where ORDER BY question_id ASC LIMIT 1 OFFSET ?',
        [index],
      );
    }
    if (result.isEmpty) return null;
    return Question.fromMap(result.first);
  }

  // ============ 合集列表 ============

  static const String defaultJudgeCorrectCollection = '判断题 · 答案正确';
  static const String defaultJudgeWrongCollection = '判断题 · 答案错误';

  static String _defaultJudgeCollectionOwner(bool answerIsCorrect) =>
      answerIsCorrect
      ? '__system_default_judge_correct__'
      : '__system_default_judge_wrong__';

  /// 统计默认题库中答案为“正确/错误”的判断题数量。
  Future<Map<bool, int>> getDefaultJudgeAnswerCounts() async {
    final bank = await getDefaultBank();
    if (bank?.id == null) return const {true: 0, false: 0};
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT UPPER(TRIM(answer)) AS normalized_answer, COUNT(*) AS count
      FROM questions
      WHERE bank_id = ? AND type = 'judge'
        AND UPPER(TRIM(answer)) IN ('A', 'B')
      GROUP BY UPPER(TRIM(answer))
      ''',
      [bank!.id],
    );
    var correct = 0;
    var wrong = 0;
    for (final row in result) {
      final count = (row['count'] as int?) ?? 0;
      if (row['normalized_answer'] == 'A') {
        correct = count;
      } else if (row['normalized_answer'] == 'B') {
        wrong = count;
      }
    }
    return {true: correct, false: wrong};
  }

  /// 将默认题库中指定答案的全部判断题创建（或同步）为一个系统合集。
  ///
  /// 系统合集使用独立的虚拟 owner，不会覆盖用户在题目详情页维护的关联题。
  /// 重复执行时先清理该系统合集再写入，因此新增/移除题目后可以安全同步。
  Future<int> syncDefaultJudgeCollection({
    required bool answerIsCorrect,
  }) async {
    final bank = await getDefaultBank();
    if (bank?.id == null) return 0;

    final db = await database;
    final bankId = bank!.id!;
    final owner = _defaultJudgeCollectionOwner(answerIsCorrect);
    final keyword = answerIsCorrect
        ? defaultJudgeCorrectCollection
        : defaultJudgeWrongCollection;
    final answer = answerIsCorrect ? 'A' : 'B';
    final rows = await db.rawQuery(
      '''
      SELECT question_id
      FROM questions
      WHERE bank_id = ? AND type = 'judge' AND UPPER(TRIM(answer)) = ?
      ORDER BY question_id ASC
      ''',
      [bankId, answer],
    );

    await db.transaction((txn) async {
      await txn.delete(
        'related_questions',
        where: 'bank_id = ? AND question_id = ?',
        whereArgs: [bankId, owner],
      );
      if (rows.isEmpty) return;

      final batch = txn.batch();
      final now = DateTime.now().toIso8601String();
      for (var index = 0; index < rows.length; index++) {
        batch.insert('related_questions', {
          'bank_id': bankId,
          'question_id': owner,
          'related_question_id': rows[index]['question_id'],
          'sort_order': index,
          'keywords': keyword,
          'created_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
    return rows.length;
  }

  /// 获取所有用户创建的合集关键词列表，按题目数量降序排列。
  /// 每个合集以关键词命名，统计该关键词下收录的题目数量（去重）。
  Future<List<CollectionInfo>> getCollectionKeywords() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT keywords AS keyword, COUNT(DISTINCT related_question_id) AS count
      FROM related_questions
      WHERE keywords IS NOT NULL AND keywords != ''
      GROUP BY keywords
      ORDER BY count DESC, keyword ASC
    ''');
    return result.map((row) {
      return CollectionInfo(
        keyword: row['keyword'] as String,
        questionCount: (row['count'] as int?) ?? 0,
      );
    }).toList();
  }

  /// 获取某个关键词合集下的所有题目（去重），按 question_id 升序排列。
  Future<List<Question>> getQuestionsByCollectionKeyword(String keyword) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT DISTINCT q.* FROM related_questions r
      INNER JOIN questions q ON q.question_id = r.related_question_id
      WHERE r.keywords = ?
      ORDER BY q.question_id ASC
    ''',
      [keyword],
    );
    return result.map((e) => Question.fromMap(e)).toList();
  }

  /// 删除指定合集的收录关系，但保留题库原题及其学习数据。
  Future<int> deleteCollectionByKeyword(String keyword) async {
    if (keyword.trim().isEmpty) return 0;
    final db = await database;
    return db.delete(
      'related_questions',
      where: 'keywords = ?',
      whereArgs: [keyword],
    );
  }

  // ============ 题库去重 ============

  /// 检索并合并题库中的重复题目（题干、选项ABCD、答案、题型完全相同）。
  /// 保留每组中数据最丰富的一道，迁移其余题目的学习记录/笔记/AI对话/合集引用后删除。
  /// 返回被删除的题目数量。
  Future<int> deduplicateQuestions({int? bankId}) async {
    final db = await database;
    // 1. 查出全部题目（仅需要的字段）
    final rows = bankId == null
        ? await db.rawQuery(
            'SELECT question_id, content, IFNULL(option_a,"") AS option_a, '
            'IFNULL(option_b,"") AS option_b, IFNULL(option_c,"") AS option_c, '
            'IFNULL(option_d,"") AS option_d, answer, type, IFNULL(reference_answer,"") AS reference_answer '
            'FROM questions',
          )
        : await db.rawQuery(
            'SELECT question_id, content, IFNULL(option_a,"") AS option_a, '
            'IFNULL(option_b,"") AS option_b, IFNULL(option_c,"") AS option_c, '
            'IFNULL(option_d,"") AS option_d, answer, type, IFNULL(reference_answer,"") AS reference_answer '
            'FROM questions WHERE bank_id = ?',
            [bankId],
          );

    // 2. 按签名分组
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final signature =
          '${row['content']}|${row['option_a']}|${row['option_b']}|${row['option_c']}|${row['option_d']}|${row['answer']}|${row['type']}';
      groups.putIfAbsent(signature, () => []).add(row);
    }

    final duplicateGroups = groups.values.where((g) => g.length > 1).toList();
    if (duplicateGroups.isEmpty) return 0;

    final allIds = duplicateGroups
        .expand((g) => g.map((r) => r['question_id'] as String))
        .toList();

    // 3. 批量获取每道候选题目的"数据丰富度"指标
    final notesSet = await getQuestionIdsWithNotes(allIds);
    final placeholders = allIds.map((_) => '?').join(',');
    final chatRows = await db.rawQuery(
      'SELECT question_id, COUNT(*) AS cnt FROM ai_chat_history WHERE question_id IN ($placeholders) GROUP BY question_id',
      allIds,
    );
    final chatCount = {
      for (final r in chatRows)
        r['question_id'] as String: (r['cnt'] as int?) ?? 0,
    };
    final relatedAsParentRows = await db.rawQuery(
      'SELECT question_id, COUNT(*) AS cnt FROM related_questions WHERE question_id IN ($placeholders) GROUP BY question_id',
      allIds,
    );
    final relatedAsParentCount = {
      for (final r in relatedAsParentRows)
        r['question_id'] as String: (r['cnt'] as int?) ?? 0,
    };
    final studyRows = await db.rawQuery(
      'SELECT question_id, practice_count, is_wrong, is_favorite, is_mastered, is_correct FROM study_records WHERE question_id IN ($placeholders)',
      allIds,
    );
    final studyMap = {for (final r in studyRows) r['question_id'] as String: r};

    int removed = 0;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      for (final group in duplicateGroups) {
        // 4. 评分选保留项
        final scored = group.map((row) {
          final qid = row['question_id'] as String;
          final study = studyMap[qid];
          final practiceCount = (study?['practice_count'] as int?) ?? 0;
          final hasWrong = ((study?['is_wrong'] as int?) ?? 0) == 1 ? 1 : 0;
          final hasFav = ((study?['is_favorite'] as int?) ?? 0) == 1 ? 2 : 0;
          final hasMaster = ((study?['is_mastered'] as int?) ?? 0) == 1 ? 1 : 0;
          final hasCorrect = ((study?['is_correct'] as int?) ?? 0) == 1 ? 1 : 0;
          final score =
              practiceCount * 1 +
              (notesSet.contains(qid) ? 5 : 0) +
              ((chatCount[qid] ?? 0) > 0 ? 3 : 0) +
              (relatedAsParentCount[qid] ?? 0) * 2 +
              hasWrong +
              hasFav +
              hasMaster +
              hasCorrect;
          return {'row': row, 'qid': qid, 'score': score};
        }).toList();
        scored.sort((a, b) {
          final cmp = (b['score'] as int).compareTo(a['score'] as int);
          if (cmp != 0) return cmp;
          // 同分取 question_id 较小者（更稳定保留靠前题号）
          return (a['qid'] as String).compareTo(b['qid'] as String);
        });
        final keepId = scored.first['qid'] as String;
        final keepRef = scored.first['row'] as Map<String, dynamic>;

        // 5. 迁移每个被删项
        for (final item in scored.skip(1)) {
          final dupId = item['qid'] as String;
          final dupRef = item['row'] as Map<String, dynamic>;

          // study_records 合并
          final keepStudy = studyMap[keepId];
          final dupStudy = studyMap[dupId];
          if (dupStudy != null) {
            if (keepStudy == null) {
              // 直接迁移：更新 question_id
              await txn.update(
                'study_records',
                {'question_id': keepId},
                where: 'question_id = ?',
                whereArgs: [dupId],
                conflictAlgorithm: ConflictAlgorithm.ignore,
              );
            } else {
              // 合并字段
              final merged = <String, Object>{
                'practice_count':
                    ((keepStudy['practice_count'] as int?) ?? 0) +
                    ((dupStudy['practice_count'] as int?) ?? 0),
                'is_wrong':
                    ((keepStudy['is_wrong'] as int?) ?? 0) == 1 ||
                        ((dupStudy['is_wrong'] as int?) ?? 0) == 1
                    ? 1
                    : 0,
                'is_favorite':
                    ((keepStudy['is_favorite'] as int?) ?? 0) == 1 ||
                        ((dupStudy['is_favorite'] as int?) ?? 0) == 1
                    ? 1
                    : 0,
                'is_mastered':
                    ((keepStudy['is_mastered'] as int?) ?? 0) == 1 ||
                        ((dupStudy['is_mastered'] as int?) ?? 0) == 1
                    ? 1
                    : 0,
                'is_correct':
                    ((keepStudy['is_correct'] as int?) ?? 0) == 1 ||
                        ((dupStudy['is_correct'] as int?) ?? 0) == 1
                    ? 1
                    : 0,
              };
              // 保留更晚的时间
              final keepLast = keepStudy['last_practice_at'] as String?;
              final dupLast = dupStudy['last_practice_at'] as String?;
              if (dupLast != null &&
                  (keepLast == null || dupLast.compareTo(keepLast) > 0)) {
                merged['last_practice_at'] = dupLast;
              }
              await txn.update(
                'study_records',
                merged,
                where: 'question_id = ?',
                whereArgs: [keepId],
              );
              await txn.delete(
                'study_records',
                where: 'question_id = ?',
                whereArgs: [dupId],
              );
            }
          }

          // notes 迁移：保留项无笔记则迁移
          if (notesSet.contains(dupId) && !notesSet.contains(keepId)) {
            await txn.update(
              'notes',
              {'question_id': keepId, 'updated_at': now},
              where: 'question_id = ?',
              whereArgs: [dupId],
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          } else {
            // 否则丢弃重复笔记
            await txn.delete(
              'notes',
              where: 'question_id = ?',
              whereArgs: [dupId],
            );
          }

          // ai_chat_history 迁移：保留项无记录则迁移
          if ((chatCount[dupId] ?? 0) > 0 && (chatCount[keepId] ?? 0) == 0) {
            await txn.update(
              'ai_chat_history',
              {'question_id': keepId, 'updated_at': now},
              where: 'question_id = ?',
              whereArgs: [dupId],
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          } else {
            await txn.delete(
              'ai_chat_history',
              where: 'question_id = ?',
              whereArgs: [dupId],
            );
          }

          // related_questions 迁移：
          // (a) dup 作为父（question_id=dupId）：改指向 keepId
          //   1) 删除会变成自引用的关系（dupId→keepId 更新后变 keepId→keepId）
          await txn.rawDelete(
            'DELETE FROM related_questions WHERE question_id = ? AND related_question_id = ?',
            [dupId, keepId],
          );
          //   2) 删除 keepId 已有的、与 dupId 子集重叠的关系，避免 UNIQUE 冲突
          await txn.rawDelete(
            'DELETE FROM related_questions WHERE question_id = ? AND related_question_id IN ('
            'SELECT related_question_id FROM related_questions WHERE question_id = ?'
            ')',
            [keepId, dupId],
          );
          //   3) 将 dupId 作为父的关系转移到 keepId
          await txn.rawUpdate(
            'UPDATE related_questions SET question_id = ? WHERE question_id = ?',
            [keepId, dupId],
          );
          // (b) dup 作为子（related_question_id=dupId）：改指向 keepId
          //   1) 删除会变成自引用的关系（keepId→dupId 更新后变 keepId→keepId）
          await txn.rawDelete(
            'DELETE FROM related_questions WHERE question_id = ? AND related_question_id = ?',
            [keepId, dupId],
          );
          //   2) 删除指向 keepId 的、与指向 dupId 的父题目重叠的关系，避免 UNIQUE 冲突
          await txn.rawDelete(
            'DELETE FROM related_questions WHERE related_question_id = ? AND question_id IN ('
            'SELECT question_id FROM related_questions WHERE related_question_id = ? AND question_id != ?'
            ')',
            [keepId, dupId, keepId],
          );
          //   3) 将 dupId 作为子的关系转移到 keepId
          await txn.rawUpdate(
            'UPDATE related_questions SET related_question_id = ? WHERE related_question_id = ?',
            [keepId, dupId],
          );

          // reference_answer 补充
          if ((keepRef['reference_answer'] as String).isEmpty &&
              (dupRef['reference_answer'] as String).isNotEmpty) {
            await txn.update(
              'questions',
              {'reference_answer': dupRef['reference_answer']},
              where: 'question_id = ?',
              whereArgs: [keepId],
            );
          }

          // 6. 删除重复题目
          await txn.delete(
            'questions',
            where: 'question_id = ?',
            whereArgs: [dupId],
          );
          removed++;
        }
      }
    });

    if (removed > 0 && bankId != null) {
      await updateBankQuestionCount(bankId);
    } else if (removed > 0) {
      // 全库去重：刷新所有题库计数
      final banks = await getAllBanks();
      for (final b in banks) {
        if (b.id != null) await updateBankQuestionCount(b.id!);
      }
    }
    return removed;
  }

  // ============ 学习记录 ============

  Future<void> upsertStudyRecord(StudyRecord record) async {
    final db = await database;
    await db.insert(
      'study_records',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<StudyRecord?> getStudyRecord(String questionId) async {
    final db = await database;
    final result = await db.query(
      'study_records',
      where: 'question_id = ?',
      whereArgs: [questionId],
    );
    if (result.isEmpty) return null;
    return StudyRecord.fromMap(result.first);
  }

  Future<List<Question>> getWrongQuestions({
    int limit = 50,
    int offset = 0,
    int? bankId,
    bool excludeLongestAnswer = false,
  }) async {
    final db = await database;
    final extra = excludeLongestAnswer
        ? ' AND NOT ${_longestAnswerCondition(alias: 'q')}'
        : '';
    if (bankId != null) {
      final result = await db.rawQuery(
        'SELECT q.* FROM questions q INNER JOIN study_records s ON q.question_id = s.question_id '
        'WHERE s.is_wrong = 1 AND q.bank_id = ?$extra ORDER BY s.last_practice_at DESC LIMIT ? OFFSET ?',
        [bankId, limit, offset],
      );
      return result.map((e) => Question.fromMap(e)).toList();
    }
    final result = await db.rawQuery(
      'SELECT q.* FROM questions q INNER JOIN study_records s ON q.question_id = s.question_id '
      'WHERE s.is_wrong = 1$extra ORDER BY s.last_practice_at DESC LIMIT ? OFFSET ?',
      [limit, offset],
    );
    return result.map((e) => Question.fromMap(e)).toList();
  }

  Future<int> getWrongQuestionCount({
    int? bankId,
    bool excludeLongestAnswer = false,
  }) async {
    final db = await database;
    final extra = excludeLongestAnswer
        ? ' AND NOT ${_longestAnswerCondition(alias: 'q')}'
        : '';
    if (bankId != null) {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM study_records s INNER JOIN questions q ON s.question_id = q.question_id '
        'WHERE s.is_wrong = 1 AND q.bank_id = ?$extra',
        [bankId],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    }
    final result = excludeLongestAnswer
        ? await db.rawQuery(
            'SELECT COUNT(*) as count FROM study_records s INNER JOIN questions q ON s.question_id = q.question_id '
            'WHERE s.is_wrong = 1$extra',
          )
        : await db.rawQuery(
            'SELECT COUNT(*) as count FROM study_records WHERE is_wrong = 1',
          );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Question>> getFavoriteQuestions({
    int limit = 50,
    int offset = 0,
    int? bankId,
    bool excludeLongestAnswer = false,
  }) async {
    final db = await database;
    final extra = excludeLongestAnswer
        ? ' AND NOT ${_longestAnswerCondition(alias: 'q')}'
        : '';
    if (bankId != null) {
      final result = await db.rawQuery(
        'SELECT q.* FROM questions q INNER JOIN study_records s ON q.question_id = s.question_id '
        'WHERE s.is_favorite = 1 AND q.bank_id = ?$extra ORDER BY s.last_practice_at DESC LIMIT ? OFFSET ?',
        [bankId, limit, offset],
      );
      return result.map((e) => Question.fromMap(e)).toList();
    }
    final result = await db.rawQuery(
      'SELECT q.* FROM questions q INNER JOIN study_records s ON q.question_id = s.question_id '
      'WHERE s.is_favorite = 1$extra ORDER BY s.last_practice_at DESC LIMIT ? OFFSET ?',
      [limit, offset],
    );
    return result.map((e) => Question.fromMap(e)).toList();
  }

  Future<int> getFavoriteQuestionCount({
    int? bankId,
    bool excludeLongestAnswer = false,
  }) async {
    final db = await database;
    final extra = excludeLongestAnswer
        ? ' AND NOT ${_longestAnswerCondition(alias: 'q')}'
        : '';
    if (bankId != null) {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM study_records s INNER JOIN questions q ON s.question_id = q.question_id '
        'WHERE s.is_favorite = 1 AND q.bank_id = ?$extra',
        [bankId],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    }
    final result = excludeLongestAnswer
        ? await db.rawQuery(
            'SELECT COUNT(*) as count FROM study_records s INNER JOIN questions q ON s.question_id = q.question_id '
            'WHERE s.is_favorite = 1$extra',
          )
        : await db.rawQuery(
            'SELECT COUNT(*) as count FROM study_records WHERE is_favorite = 1',
          );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getPracticedCount({
    int? bankId,
    bool excludeLongestAnswer = false,
  }) async {
    final db = await database;
    final extra = excludeLongestAnswer
        ? ' AND NOT ${_longestAnswerCondition(alias: 'q')}'
        : '';
    if (bankId != null) {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM study_records s INNER JOIN questions q ON s.question_id = q.question_id '
        'WHERE s.practice_count > 0 AND q.bank_id = ?$extra',
        [bankId],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    }
    final result = excludeLongestAnswer
        ? await db.rawQuery(
            'SELECT COUNT(*) as count FROM study_records s INNER JOIN questions q ON s.question_id = q.question_id '
            'WHERE s.practice_count > 0$extra',
          )
        : await db.rawQuery(
            'SELECT COUNT(*) as count FROM study_records WHERE practice_count > 0',
          );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getCorrectCount({
    int? bankId,
    bool excludeLongestAnswer = false,
  }) async {
    final db = await database;
    final extra = excludeLongestAnswer
        ? ' AND NOT ${_longestAnswerCondition(alias: 'q')}'
        : '';
    if (bankId != null) {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM study_records s INNER JOIN questions q ON s.question_id = q.question_id '
        'WHERE s.is_correct = 1 AND s.is_wrong = 0 AND q.bank_id = ?$extra',
        [bankId],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    }
    final result = excludeLongestAnswer
        ? await db.rawQuery(
            'SELECT COUNT(*) as count FROM study_records s INNER JOIN questions q ON s.question_id = q.question_id '
            'WHERE s.is_correct = 1 AND s.is_wrong = 0$extra',
          )
        : await db.rawQuery(
            'SELECT COUNT(*) as count FROM study_records WHERE is_correct = 1 AND is_wrong = 0',
          );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getMasteredCount({
    int? bankId,
    bool excludeLongestAnswer = false,
  }) async {
    final db = await database;
    final extra = excludeLongestAnswer
        ? ' AND NOT ${_longestAnswerCondition(alias: 'q')}'
        : '';
    if (bankId != null) {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM study_records s INNER JOIN questions q ON s.question_id = q.question_id '
        'WHERE s.is_mastered = 1 AND q.bank_id = ?$extra',
        [bankId],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    }
    final result = excludeLongestAnswer
        ? await db.rawQuery(
            'SELECT COUNT(*) as count FROM study_records s INNER JOIN questions q ON s.question_id = q.question_id '
            'WHERE s.is_mastered = 1$extra',
          )
        : await db.rawQuery(
            'SELECT COUNT(*) as count FROM study_records WHERE is_mastered = 1',
          );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> clearWrongRecords() async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE study_records SET is_wrong = 0 WHERE is_wrong = 1',
    );
  }

  Future<void> toggleFavorite(String questionId) async {
    final db = await database;
    final record = await getStudyRecord(questionId);
    if (record != null) {
      await db.update(
        'study_records',
        {'is_favorite': record.isFavorite == 1 ? 0 : 1},
        where: 'question_id = ?',
        whereArgs: [questionId],
      );
    } else {
      await db.insert(
        'study_records',
        StudyRecord(questionId: questionId, isFavorite: 1).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> toggleMastered(String questionId) async {
    final db = await database;
    final record = await getStudyRecord(questionId);
    if (record != null) {
      await db.update(
        'study_records',
        {'is_mastered': record.isMastered == 1 ? 0 : 1},
        where: 'question_id = ?',
        whereArgs: [questionId],
      );
    } else {
      await db.insert(
        'study_records',
        StudyRecord(questionId: questionId, isMastered: 1).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// 显式设置掌握状态，避免连续点击时 toggle 产生状态反转竞争。
  Future<void> setMastered(String questionId, bool mastered) async {
    final db = await database;
    final record = await getStudyRecord(questionId);
    if (record != null) {
      await db.update(
        'study_records',
        {'is_mastered': mastered ? 1 : 0},
        where: 'question_id = ?',
        whereArgs: [questionId],
      );
    } else if (mastered) {
      await db.insert(
        'study_records',
        StudyRecord(questionId: questionId, isMastered: 1).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  // ============ 进度 ============

  Future<void> saveProgress(
    String mode,
    String subMode,
    String? sheetName,
    int currentIndex,
    int totalCount,
    int correctCount, {
    int? bankId,
  }) async {
    final db = await database;
    String whereStr;
    List<Object?> whereArgs;
    if (bankId != null) {
      whereStr =
          'mode = ? AND sub_mode = ? AND (sheet_name = ? OR (? IS NULL AND sheet_name IS NULL)) AND bank_id = ?';
      whereArgs = [mode, subMode, sheetName, sheetName, bankId];
    } else {
      whereStr =
          'mode = ? AND sub_mode = ? AND (sheet_name = ? OR (? IS NULL AND sheet_name IS NULL)) AND bank_id IS NULL';
      whereArgs = [mode, subMode, sheetName, sheetName];
    }
    final existing = await db.query(
      'progress',
      where: whereStr,
      whereArgs: whereArgs,
    );
    final now = DateTime.now().toIso8601String();
    if (existing.isNotEmpty) {
      await db.update(
        'progress',
        {
          'current_index': currentIndex,
          'total_count': totalCount,
          'correct_count': correctCount,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      await db.insert('progress', {
        'mode': mode,
        'sub_mode': subMode,
        'sheet_name': sheetName,
        'current_index': currentIndex,
        'total_count': totalCount,
        'correct_count': correctCount,
        'updated_at': now,
        'bank_id': bankId,
      });
    }
  }

  Future<Map<String, dynamic>?> getProgress(
    String mode,
    String subMode, {
    String? sheetName,
    int? bankId,
  }) async {
    final db = await database;
    String whereStr;
    List<Object?> whereArgs;
    if (bankId != null) {
      whereStr =
          'mode = ? AND sub_mode = ? AND (sheet_name = ? OR (? IS NULL AND sheet_name IS NULL)) AND bank_id = ?';
      whereArgs = [mode, subMode, sheetName, sheetName, bankId];
    } else {
      whereStr =
          'mode = ? AND sub_mode = ? AND (sheet_name = ? OR (? IS NULL AND sheet_name IS NULL)) AND bank_id IS NULL';
      whereArgs = [mode, subMode, sheetName, sheetName];
    }
    final result = await db.query(
      'progress',
      where: whereStr,
      whereArgs: whereArgs,
    );
    if (result.isEmpty) return null;
    return result.first;
  }

  // ============ 数据清除 ============

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('questions');
    await db.delete('study_records');
    await db.delete('progress');
    await db.delete('ai_chat_history');
    await db.delete('question_banks');
  }

  // ============ AI 对话 ============

  Future<void> saveAiChatHistory(String questionId, String messagesJson) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final existing = await db.query(
      'ai_chat_history',
      where: 'question_id = ?',
      whereArgs: [questionId],
    );
    if (existing.isNotEmpty) {
      await db.update(
        'ai_chat_history',
        {'messages': messagesJson, 'updated_at': now},
        where: 'question_id = ?',
        whereArgs: [questionId],
      );
    } else {
      await db.insert('ai_chat_history', {
        'question_id': questionId,
        'messages': messagesJson,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  Future<String?> loadAiChatHistory(String questionId) async {
    final db = await database;
    final result = await db.query(
      'ai_chat_history',
      where: 'question_id = ?',
      whereArgs: [questionId],
    );
    if (result.isEmpty) return null;
    return result.first['messages'] as String?;
  }

  Future<void> deleteAiChatHistory(String questionId) async {
    final db = await database;
    await db.delete(
      'ai_chat_history',
      where: 'question_id = ?',
      whereArgs: [questionId],
    );
  }

  // ============ 模拟考试 ============

  Future<void> saveMockExamRecord(
    int correctCount,
    int totalCount,
    double score,
  ) async {
    final db = await database;
    await db.insert('mock_exam_records', {
      'correct_count': correctCount,
      'total_count': totalCount,
      'score': score,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getMockExamRecords({
    int limit = 20,
  }) async {
    final db = await database;
    return await db.query(
      'mock_exam_records',
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  Future<int> getMockExamCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM mock_exam_records',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<double> getMockExamAvgScore() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT AVG(score) as avg_score FROM mock_exam_records',
    );
    final avg = result.first['avg_score'];
    return avg != null ? (avg as num).toDouble() : 0.0;
  }

  Future<double> getMockExamMaxScore() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT MAX(score) as max_score FROM mock_exam_records',
    );
    final maxVal = result.first['max_score'];
    return maxVal != null ? (maxVal as num).toDouble() : 0.0;
  }

  // ============ 笔记 ============

  Future<void> saveNote(Note note) async {
    final db = await database;
    await db.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Note?> getNote(String questionId) async {
    final db = await database;
    final result = await db.query(
      'notes',
      where: 'question_id = ?',
      whereArgs: [questionId],
    );
    if (result.isEmpty) return null;
    return Note.fromMap(result.first);
  }

  Future<void> deleteNote(String questionId) async {
    final db = await database;
    await db.delete('notes', where: 'question_id = ?', whereArgs: [questionId]);
  }

  // ============ 背题标注 ============

  Future<MemorizeAnnotation?> getMemorizeAnnotation(String questionId) async {
    final db = await database;
    final result = await db.query(
      'memorize_annotations',
      where: 'question_id = ?',
      whereArgs: [questionId],
    );
    if (result.isEmpty) return null;
    return MemorizeAnnotation.fromMap(result.first);
  }

  Future<void> saveMemorizeAnnotation(MemorizeAnnotation annotation) async {
    final db = await database;
    await db.insert(
      'memorize_annotations',
      annotation.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteMemorizeAnnotation(String questionId) async {
    final db = await database;
    await db.delete(
      'memorize_annotations',
      where: 'question_id = ?',
      whereArgs: [questionId],
    );
  }

  // ============ 开发者配置 ============

  Future<String?> getDeveloperConfig(String key) async {
    final db = await database;
    final result = await db.query(
      'developer_config',
      where: 'config_key = ?',
      whereArgs: [key],
    );
    if (result.isEmpty) return null;
    return result.first['config_value'] as String?;
  }

  Future<void> setDeveloperConfig(String key, String value) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final existing = await db.query(
      'developer_config',
      where: 'config_key = ?',
      whereArgs: [key],
    );
    if (existing.isNotEmpty) {
      await db.update(
        'developer_config',
        {'config_value': value, 'updated_at': now},
        where: 'config_key = ?',
        whereArgs: [key],
      );
    } else {
      await db.insert('developer_config', {
        'config_key': key,
        'config_value': value,
        'updated_at': now,
      });
    }
  }
}
