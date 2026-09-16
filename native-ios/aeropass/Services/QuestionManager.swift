import Foundation
import Combine

/// 题库管理器 - 直接从 JSON 文件加载题库数据，并管理用户状态
@MainActor
class QuestionManager: ObservableObject {
    static let shared = QuestionManager()
    
    // JSON 数据结构
    private struct RawQuestion: Decodable {
        let questionId: String
        let question: String
        let answer: String
        let options: [String: String]?
        let sheet: String?
        let referenceAnswer: String?
        
        enum CodingKeys: String, CodingKey {
            case questionId = "question_id"
            case question
            case answer
            case options
            case sheet
            case referenceAnswer = "reference_answer"
        }
    }
    
    /// 内存中的题库数据
    @Published private(set) var questions: [QuestionData] = []
    @Published private(set) var banks: [QuestionBank] = []
    @Published private(set) var records: [String: StudyRecord] = [:]
    @Published private(set) var richNotes: [String: RichNote] = [:]
    @Published private(set) var annotations: [String: QuestionAnnotation] = [:]
    @Published private(set) var collections: [QuestionCollection] = []
    @Published private(set) var collectionMindMaps: [String: SavedCollectionMindMap] = [:]
    @Published private(set) var storageError: String?
    @Published private(set) var relatedQuestionIDs: [String: [String]] = [:]
    @Published private(set) var examRecords: [ExamRecord] = []
    @Published private(set) var dailyStudyQuestionIDs: [String: Set<String>] = [:]
    @Published var autoFilterLongestAnswer: Bool = false {
        didSet {
            defaults.set(autoFilterLongestAnswer, forKey: "qm_filter_longest")
            refreshActiveQuestions()
        }
    }
    
    /// 加载状态
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var loadError: String?
    
    // MARK: - UserDefaults Keys
    private var favoritesKey: String { bankStorageKey("qm_favorites") }
    private var masteredKey: String { bankStorageKey("qm_mastered") }
    private var wrongKey: String { bankStorageKey("qm_wrong") }
    private var notesKey: String { bankStorageKey("qm_notes") }
    private func bankStorageKey(_ key: String) -> String { "\(key)_\((activeBankID ?? defaultBankID).uuidString)" }
    private func stateKey(_ questionID: String) -> String { "\((activeBankID ?? defaultBankID).uuidString):\(questionID)" }
    func record(for questionID: String) -> StudyRecord { records[stateKey(questionID)] ?? StudyRecord() }
    private let defaultBankID = UUID(uuidString: "A3E0A38A-55C4-4C71-A17E-000000000001")!
    private var activeBankID: UUID?
    private let storageOverride: URL?
    private let defaults: UserDefaults
    private let chatHistory: ChatHistoryStore
    private var storageWritable = true
    private var storageURL: URL {
        if let storageOverride { return storageOverride }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = base.appendingPathComponent("Aeropass", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("learning-store.json")
    }
    
    init(storageURL: URL? = nil, bundledQuestions: [QuestionData]? = nil, defaults: UserDefaults = .standard, chatHistory: ChatHistoryStore? = nil) {
        storageOverride = storageURL
        self.defaults = defaults
        self.chatHistory = chatHistory ?? .shared
        autoFilterLongestAnswer = defaults.bool(forKey: "qm_filter_longest")
        if let bundledQuestions { installBundledQuestions(bundledQuestions) }
        else { loadQuestions() }
    }
    
    /// 从 JSON 文件加载题库
    func loadQuestions() {
        isLoading = true
        loadError = nil
        
        // 1. 优先从 Bundle 加载
        if let jsonUrl = Bundle.main.url(forResource: "题库数据", withExtension: "json"),
           let loaded = loadQuestions(from: jsonUrl) {
            installBundledQuestions(loaded)
            isLoading = false
            print("✅ 从 Bundle 加载 \(loaded.count) 道题目")
            return
        }
        
        loadError = "未内置题库，请在 App 中导入自己的 .xlsx 题库"
        isLoading = false
        print("❌ 无法加载题库")
    }

    private func installBundledQuestions(_ loaded: [QuestionData]) {
        let snapshot = loadSnapshot()
        records = snapshot.records
        richNotes = snapshot.notes
        annotations = snapshot.annotations
        collections = snapshot.collections.map { collection in
            var copy = collection
            if copy.bankID == nil { copy.bankID = snapshot.activeBankID ?? defaultBankID }
            return copy
        }
        collectionMindMaps = snapshot.collectionMindMaps ?? [:]
        relatedQuestionIDs = snapshot.relatedQuestionIDs ?? [:]
        examRecords = snapshot.examRecords
        if let storedActivity = snapshot.dailyStudyQuestionIDs {
            dailyStudyQuestionIDs = storedActivity.mapValues(Set.init)
        } else {
            // 旧版仅保存每题最后一次练习时间；迁移时至少保留仍可确定的日期记录。
            dailyStudyQuestionIDs = Dictionary(grouping: records.compactMap { questionID, record in
                record.lastStudiedAt.map { (dayKey(for: $0), questionID) }
            }, by: \.0).mapValues { Set($0.map(\.1)) }
        }

        var defaultBank = QuestionBank(
            id: defaultBankID,
            name: "默认题库",
            source: "内置",
            createdAt: .distantPast,
            isActive: false,
            questions: loaded.map { question in
                var copy = question
                copy.bankID = defaultBankID
                return copy
            }
        )
        activeBankID = snapshot.activeBankID
        banks = [defaultBank] + snapshot.importedBanks.filter { $0.id != defaultBankID }
        if !banks.contains(where: { $0.id == activeBankID }) {
            activeBankID = defaultBankID
        }
        for index in banks.indices {
            banks[index].isActive = banks[index].id == activeBankID
        }
        defaultBank.isActive = activeBankID == defaultBankID
        migrateBankScopedState()
        refreshActiveQuestions()
    }

    private func migratedStateKey(_ key: String) -> String {
        let prefix = key.split(separator: ":", maxSplits: 1).first.map(String.init) ?? ""
        return UUID(uuidString: prefix) == nil ? stateKey(key) : key
    }

    private func migrateBankScopedState() {
        guard storageWritable else { storageError = loadError; return }
        // Old snapshots used unqualified display IDs. Preserve them in the last active bank.
        records = Dictionary(records.map { (migratedStateKey($0.key), $0.value) }, uniquingKeysWith: { first, _ in first })
        richNotes = Dictionary(richNotes.map { (migratedStateKey($0.key), $0.value) }, uniquingKeysWith: { first, _ in first })
        annotations = Dictionary(annotations.map { (migratedStateKey($0.key), $0.value) }, uniquingKeysWith: { first, _ in first })
        relatedQuestionIDs = Dictionary(relatedQuestionIDs.map { (migratedStateKey($0.key), $0.value) }, uniquingKeysWith: { first, _ in first })
        for key in ["qm_favorites", "qm_mastered", "qm_wrong", "qm_notes"] {
            if let legacy = defaults.object(forKey: key) {
                if defaults.object(forKey: bankStorageKey(key)) == nil { defaults.set(legacy, forKey: bankStorageKey(key)) }
                defaults.removeObject(forKey: key)
            }
        }
        for key in ["memorizeLastIndex", "practice_seq_lastIndex", "practice_rand_lastIndex", "practice_wrong_lastIndex", "practice_fav_lastIndex"] {
            guard let old = defaults.object(forKey: key) else { continue }
            let new = key == "memorizeLastIndex" ? "memorize_\((activeBankID ?? defaultBankID).uuidString)" : "\(key)_\((activeBankID ?? defaultBankID).uuidString)"
            if defaults.object(forKey: new) == nil { defaults.set(old, forKey: new) }
            defaults.removeObject(forKey: key)
        }
        persist()
    }

    private func loadSnapshot() -> LearningSnapshot {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return LearningSnapshot() }
        do { return try JSONDecoder().decode(LearningSnapshot.self, from: Data(contentsOf: storageURL)) }
        catch {
            storageWritable = false
            loadError = "学习存档无法读取，原文件已保留，请先备份并检查存档"
            return LearningSnapshot()
        }
    }

    private func persist() {
        guard storageWritable else { storageError = "学习存档无法读取，已停止写入以保留原文件"; return }
        let snapshot = LearningSnapshot(
            activeBankID: activeBankID,
            importedBanks: banks.filter { $0.id != defaultBankID },
            records: records,
            notes: richNotes,
            annotations: annotations,
            collections: collections,
            relatedQuestionIDs: relatedQuestionIDs,
            collectionMindMaps: collectionMindMaps,
            examRecords: examRecords,
            dailyStudyQuestionIDs: dailyStudyQuestionIDs.mapValues { Array($0).sorted() }
        )
        do {
            try JSONEncoder().encode(snapshot).write(to: storageURL, options: .atomic)
            storageError = nil
            QuestionWidgetBridge.publish(banks: banks, defaults: defaults)
        } catch { storageError = "学习数据保存失败，请检查本机可用空间" }
    }

    private func refreshActiveQuestions() {
        guard let bank = banks.first(where: { $0.id == activeBankID }) else { return }
        questions = autoFilterLongestAnswer
            ? bank.questions.filter { !isCorrectAnswerLongest($0) }
            : bank.questions
    }

    var activeBank: QuestionBank? { banks.first(where: \.isActive) }

    func switchBank(_ id: UUID) {
        guard banks.contains(where: { $0.id == id }) else { return }
        activeBankID = id
        for index in banks.indices { banks[index].isActive = banks[index].id == id }
        refreshActiveQuestions()
        persist()
    }

    func addBank(name: String, questions: [QuestionData], source: String = "Excel") {
        let id = UUID()
        let normalized = questions.map { question in
            var copy = question
            copy.bankID = id
            return copy
        }
        banks.append(QuestionBank(id: id, name: name, source: source, createdAt: .now, isActive: false, questions: normalized))
        switchBank(id)
    }

    func deleteBank(_ id: UUID) {
        guard id != defaultBankID else { return }
        let removedCollections = collections.filter { $0.bankID == id }.map(\.id)
        removedCollections.forEach(deleteCollection)
        chatHistory.delete(bankID: id)
        let prefix = "\(id.uuidString):"
        records = records.filter { !$0.key.hasPrefix(prefix) }
        richNotes = richNotes.filter { !$0.key.hasPrefix(prefix) }
        annotations = annotations.filter { !$0.key.hasPrefix(prefix) }
        relatedQuestionIDs = relatedQuestionIDs.filter { !$0.key.hasPrefix(prefix) }
        for key in ["qm_favorites", "qm_mastered", "qm_wrong", "qm_notes"] { defaults.removeObject(forKey: "\(key)_\(id.uuidString)") }
        banks.removeAll { $0.id == id }
        if activeBankID == id { switchBank(defaultBankID) }
        persist()
    }

    func questions(inSheet sheetName: String?) -> [QuestionData] {
        let source = getAllQuestions()
        guard let sheetName, !sheetName.isEmpty else { return source }
        return source.filter { $0.sheetName == sheetName }
    }

    var longestAnswerCount: Int {
        activeBank?.questions.filter(isCorrectAnswerLongest).count ?? 0
    }

    func isCorrectAnswerLongest(_ question: QuestionData) -> Bool {
        guard let correct = question.options.first(where: { $0.key == question.correctAnswer }) else { return false }
        let maxLength = question.options.map { $0.text.count }.max() ?? 0
        return correct.text.count == maxLength && question.options.filter({ $0.text.count == maxLength }).count == 1
    }
    
    /// 从指定 URL 加载题目
    private func loadQuestions(from url: URL) -> [QuestionData]? {
        guard let data = try? Data(contentsOf: url) else {
            print("❌ 无法读取文件: \(url.path)")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            let rawQuestions = try decoder.decode([RawQuestion].self, from: data)
            
            let questions = rawQuestions.map { raw -> QuestionData in
                QuestionData(
                    questionId: raw.questionId.trimmingCharacters(in: .whitespacesAndNewlines),
                    content: raw.question.trimmingCharacters(in: .whitespacesAndNewlines),
                    correctAnswer: raw.answer.trimmingCharacters(in: .whitespacesAndNewlines),
                    optionA: raw.options?["A"]?.trimmingCharacters(in: .whitespacesAndNewlines),
                    optionB: raw.options?["B"]?.trimmingCharacters(in: .whitespacesAndNewlines),
                    optionC: raw.options?["C"]?.trimmingCharacters(in: .whitespacesAndNewlines),
                    optionD: raw.options?["D"]?.trimmingCharacters(in: .whitespacesAndNewlines),
                    referenceAnswer: raw.referenceAnswer,
                    type: raw.options?["C"] == nil && raw.options?["D"] == nil ? "judge" : "single",
                    sheetName: raw.sheet
                )
            }
            
            return questions
        } catch {
            print("❌ JSON 解析失败: \(error)")
            return nil
        }
    }
    
    /// 获取题目总数
    var totalCount: Int {
        questions.count
    }
    
    /// 获取所有题目（按 questionId 排序）
    func getAllQuestions() -> [QuestionData] {
        questions.sorted { $0.questionId < $1.questionId }
    }
    
    // MARK: - 收藏管理
    var favoriteIds: Set<String> {
        get { Set(defaults.stringArray(forKey: favoritesKey) ?? []) }
        set { defaults.set(Array(newValue), forKey: favoritesKey) }
    }
    
    func isFavorite(_ questionId: String) -> Bool {
        favoriteIds.contains(questionId)
    }
    
    func toggleFavorite(_ questionId: String) {
        var favs = favoriteIds
        if favs.contains(questionId) {
            favs.remove(questionId)
        } else {
            favs.insert(questionId)
        }
        favoriteIds = favs
        var record = records[stateKey(questionId)] ?? StudyRecord()
        record.isFavorite = favs.contains(questionId)
        records[stateKey(questionId)] = record
        persist()
        objectWillChange.send()
    }
    
    // MARK: - 已掌握管理
    var masteredIds: Set<String> {
        get { Set(defaults.stringArray(forKey: masteredKey) ?? []) }
        set { defaults.set(Array(newValue), forKey: masteredKey) }
    }
    
    func isMastered(_ questionId: String) -> Bool {
        masteredIds.contains(questionId)
    }
    
    func setMastered(_ questionId: String, mastered: Bool) {
        var ids = masteredIds
        if mastered {
            ids.insert(questionId)
        } else {
            ids.remove(questionId)
        }
        masteredIds = ids
        var record = records[stateKey(questionId)] ?? StudyRecord()
        record.isMastered = mastered
        if mastered {
            record.lastStudiedAt = .now
            insertStudyActivity(questionIDs: [questionId], at: .now)
        }
        records[stateKey(questionId)] = record
        persist()
        objectWillChange.send()
    }
    
    // MARK: - 错题管理
    var wrongIds: Set<String> {
        get { Set(defaults.stringArray(forKey: wrongKey) ?? []) }
        set { defaults.set(Array(newValue), forKey: wrongKey) }
    }
    
    func isWrong(_ questionId: String) -> Bool {
        wrongIds.contains(questionId)
    }
    
    func markWrong(_ questionId: String) {
        var ids = wrongIds
        ids.insert(questionId)
        wrongIds = ids
        persist()
        objectWillChange.send()
    }

    func recordAnswer(questionID: String, isCorrect: Bool) {
        var record = records[stateKey(questionID)] ?? StudyRecord()
        record.attempts += 1
        if isCorrect { record.correctCount += 1 } else { markWrong(questionID) }
        record.lastStudiedAt = .now
        records[stateKey(questionID)] = record
        insertStudyActivity(questionIDs: [questionID], at: .now)
        persist()
        objectWillChange.send()
    }

    // MARK: - 学习趋势

    func recordStudy(questionIDs: [String], at date: Date = .now) {
        guard !questionIDs.isEmpty else { return }
        insertStudyActivity(questionIDs: questionIDs, at: date)
        persist()
        objectWillChange.send()
    }

    func studyCount(on date: Date) -> Int {
        dailyStudyQuestionIDs[dayKey(for: date)]?.count ?? 0
    }

    private func insertStudyActivity(questionIDs: [String], at date: Date) {
        let key = dayKey(for: date)
        var studied = dailyStudyQuestionIDs[key] ?? []
        studied.formUnion(questionIDs.map(stateKey))
        dailyStudyQuestionIDs[key] = studied

        // 首页只展示近期趋势；保留一年数据足够跨季查看，同时控制存档体积。
        let retainedKeys = Set(dailyStudyQuestionIDs.keys.sorted().suffix(370))
        dailyStudyQuestionIDs = dailyStudyQuestionIDs.filter { retainedKeys.contains($0.key) }
    }

    private func dayKey(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
    
    // MARK: - 笔记管理
    var notes: [String: String] {
        get { defaults.dictionary(forKey: notesKey) as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: notesKey) }
    }
    
    func note(for questionId: String) -> String? {
        notes[questionId]
    }
    
    func setNote(_ questionId: String, note: String?) {
        var allNotes = notes
        if let note = note, !note.isEmpty {
            allNotes[questionId] = note
        } else {
            allNotes.removeValue(forKey: questionId)
        }
        self.notes = allNotes
        var rich = richNotes[stateKey(questionId)] ?? RichNote(questionID: questionId)
        rich.text = note ?? ""
        rich.updatedAt = .now
        richNotes[stateKey(questionId)] = rich
        persist()
        objectWillChange.send()
    }

    func richNote(for questionID: String) -> RichNote {
        richNotes[stateKey(questionID)] ?? RichNote(questionID: questionID, text: notes[questionID] ?? "")
    }

    func saveRichNote(_ note: RichNote) {
        var copy = note
        copy.updatedAt = .now
        richNotes[stateKey(note.questionID)] = copy
        var legacy = notes
        if copy.text.isEmpty { legacy.removeValue(forKey: note.questionID) } else { legacy[note.questionID] = copy.text }
        notes = legacy
        persist()
        objectWillChange.send()
    }

    func deleteNote(for questionID: String) {
        richNotes.removeValue(forKey: stateKey(questionID))
        var legacy = notes
        legacy.removeValue(forKey: questionID)
        notes = legacy
        persist()
        objectWillChange.send()
    }

    func annotation(for questionID: String) -> QuestionAnnotation {
        annotations[stateKey(questionID)] ?? QuestionAnnotation(questionID: questionID)
    }

    func saveAnnotation(_ annotation: QuestionAnnotation) {
        var copy = annotation
        copy.updatedAt = .now
        annotations[stateKey(annotation.questionID)] = copy
        persist()
        objectWillChange.send()
    }

    func collectionQuestions(_ id: UUID) -> [QuestionData] {
        guard let collection = collections.first(where: { $0.id == id }),
              let bank = banks.first(where: { $0.id == collection.bankID }) else { return [] }
        let byID = Dictionary(bank.questions.map { ($0.questionId, $0) }, uniquingKeysWith: { first, _ in first })
        return collection.questionIDs.compactMap { byID[$0] }
    }

    func addCollection(named name: String, questionIDs: [String] = []) {
        _ = createOrUpdateCollection(named: name, questionIDs: questionIDs)
    }

    @discardableResult
    func createOrUpdateCollection(named name: String, questionIDs: [String], bankID: UUID? = nil) -> UUID? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let owner = bankID ?? activeBankID
        guard !trimmed.isEmpty, let bank = banks.first(where: { $0.id == owner }) else { return nil }
        let valid = Set(bank.questions.map(\.questionId))
        let ids = questionIDs.filter { valid.contains($0) }
        if let existing = collections.first(where: {
            $0.bankID == owner && $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
        }) {
            addQuestions(ids, to: existing.id)
            return existing.id
        }
        let collection = QuestionCollection(name: trimmed, questionIDs: Array(Set(ids)).sorted(), bankID: owner)
        collections.append(collection)
        persist()
        return collection.id
    }

    func renameCollection(_ id: UUID, to name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = collections.firstIndex(where: { $0.id == id }),
              !collections.contains(where: { $0.id != id && $0.bankID == collections[index].bankID && $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) else { return false }
        collections[index].name = trimmed
        persist()
        return true
    }

    func addQuestions(_ ids: [String], to collectionID: UUID) {
        guard let index = collections.firstIndex(where: { $0.id == collectionID }),
              let bank = banks.first(where: { $0.id == collections[index].bankID }) else { return }
        let valid = Set(bank.questions.map(\.questionId))
        let updated = Array(Set(collections[index].questionIDs + ids.filter { valid.contains($0) })).sorted()
        guard updated != collections[index].questionIDs else { return }
        collections[index].questionIDs = updated
        collectionMindMaps.removeValue(forKey: collectionID.uuidString)
        persist()
    }

    func removeQuestions(_ ids: Set<String>, from collectionID: UUID) {
        guard let index = collections.firstIndex(where: { $0.id == collectionID }) else { return }
        collections[index].questionIDs.removeAll { ids.contains($0) }
        collectionMindMaps.removeValue(forKey: collectionID.uuidString)
        persist()
    }

    func toggleQuestion(_ questionID: String, in collectionID: UUID) {
        guard let collection = collections.first(where: { $0.id == collectionID }) else { return }
        if collection.questionIDs.contains(questionID) { removeQuestions([questionID], from: collectionID) }
        else { addQuestions([questionID], to: collectionID) }
    }

    func deleteCollection(_ id: UUID) {
        collections.removeAll { $0.id == id }
        collectionMindMaps.removeValue(forKey: id.uuidString)
        persist()
    }

    func defaultJudgeQuestions(answerIsCorrect: Bool) -> [QuestionData] {
        (banks.first { $0.id == defaultBankID }?.questions ?? []).filter {
            $0.isTrueFalse && $0.correctAnswer.uppercased() == (answerIsCorrect ? "A" : "B")
        }
    }

    @discardableResult
    func syncDefaultJudgeCollection(answerIsCorrect: Bool) -> UUID? {
        let questions = defaultJudgeQuestions(answerIsCorrect: answerIsCorrect)
        guard !questions.isEmpty else { return nil }
        let name = answerIsCorrect ? "判断题 · 答案正确" : "判断题 · 答案错误"
        guard let id = createOrUpdateCollection(named: name, questionIDs: [], bankID: defaultBankID),
              let index = collections.firstIndex(where: { $0.id == id }) else { return nil }
        let ids = Array(Set(questions.map(\.questionId))).sorted()
        if collections[index].questionIDs != ids {
            collections[index].questionIDs = ids
            collectionMindMaps.removeValue(forKey: id.uuidString)
            persist()
        }
        return id
    }

    func savedMindMap(for id: UUID) -> SavedCollectionMindMap? {
        guard let saved = collectionMindMaps[id.uuidString], saved.matches(collectionQuestions(id)) else { return nil }
        return saved
    }

    func saveMindMap(_ saved: SavedCollectionMindMap, for id: UUID) {
        guard collections.contains(where: { $0.id == id }), saved.matches(collectionQuestions(id)) else { return }
        collectionMindMaps[id.uuidString] = saved
        persist()
    }

    func clearWrongRecords() {
        wrongIds = []
        objectWillChange.send()
        persist()
    }

    func relatedQuestions(for questionID: String) -> [QuestionData] {
        let ids = Set(relatedQuestionIDs[stateKey(questionID)] ?? [])
        return (activeBank?.questions ?? []).filter { ids.contains($0.questionId) }
    }

    func saveRelatedQuestions(_ ids: [String], for questionID: String) {
        relatedQuestionIDs[stateKey(questionID)] = Array(Set(ids))
        persist()
        objectWillChange.send()
    }

    func saveExamRecord(total: Int, correct: Int) {
        examRecords.append(ExamRecord(id: UUID(), date: .now, total: total, correct: correct))
        if examRecords.count > 50 { examRecords.removeFirst(examRecords.count - 50) }
        persist()
    }
    
    // MARK: - 重置
    func resetAllLearningData() {
        storageWritable = true
        loadError = nil
        for key in defaults.dictionaryRepresentation().keys where
            ["qm_favorites", "qm_mastered", "qm_wrong", "qm_notes", "memorize_", "practice_seq_", "practice_rand_", "practice_wrong_", "practice_fav_"].contains(where: { key.hasPrefix($0) }) {
            defaults.removeObject(forKey: key)
        }
        records = [:]
        richNotes = [:]
        annotations = [:]
        collections = []
        relatedQuestionIDs = [:]
        collectionMindMaps = [:]
        chatHistory.clear()
        examRecords = []
        dailyStudyQuestionIDs = [:]
        persist()
        objectWillChange.send()
    }
}

/// 题目数据模型（不依赖 SwiftData）
struct QuestionData: Identifiable, Codable, Hashable {
    let id: String
    let questionId: String
    let content: String
    let correctAnswer: String
    
    var optionA: String?
    var optionB: String?
    var optionC: String?
    var optionD: String?
    var referenceAnswer: String?
    var type: String
    var sheetName: String?
    var bankID: UUID?
    
    /// 是否为判断题
    var isTrueFalse: Bool {
        return type == "judge" || optionA == nil || optionA?.isEmpty == true
            || ((optionC ?? "").isEmpty && (optionD ?? "").isEmpty && ["正确", "对"].contains(optionA ?? "") && ["错误", "错"].contains(optionB ?? ""))
    }
    
    /// 获取选项列表
    var options: [(key: String, text: String)] {
        var result: [(String, String)] = []
        if let a = optionA, !a.isEmpty { result.append(("A", a)) }
        if let b = optionB, !b.isEmpty { result.append(("B", b)) }
        if let c = optionC, !c.isEmpty { result.append(("C", c)) }
        if let d = optionD, !d.isEmpty { result.append(("D", d)) }
        return result
    }
    
    init(id: String = UUID().uuidString, questionId: String, content: String, correctAnswer: String, 
         optionA: String? = nil, optionB: String? = nil, optionC: String? = nil, optionD: String? = nil,
         referenceAnswer: String? = nil, type: String = "single", sheetName: String? = nil, bankID: UUID? = nil) {
        self.id = id
        self.questionId = questionId
        self.content = content
        self.correctAnswer = correctAnswer
        self.optionA = optionA
        self.optionB = optionB
        self.optionC = optionC
        self.optionD = optionD
        self.referenceAnswer = referenceAnswer
        self.type = type
        self.sheetName = sheetName
        self.bankID = bankID
    }
}

extension QuestionData {
    var studyFingerprint: String {
        [
            content,
            correctAnswer,
            optionA ?? "",
            optionB ?? "",
            optionC ?? "",
            optionD ?? ""
        ]
        .map { $0.normalizedForStudyFingerprint }
        .joined(separator: "|")
    }
}

extension Array where Element == QuestionData {
    func uniquedForStudy() -> [QuestionData] {
        var seen = Set<String>()
        return filter { question in
            seen.insert(question.studyFingerprint).inserted
        }
    }
}

private extension String {
    var normalizedForStudyFingerprint: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
            .lowercased()
    }
}
