import Foundation

struct QuestionBank: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var source: String
    var createdAt: Date
    var isActive: Bool
    var questions: [QuestionData]

    var questionCount: Int { questions.count }
    var sheetNames: [String] {
        Array(Set(questions.compactMap(\.sheetName).filter { !$0.isEmpty })).sorted()
    }
}

struct StudyRecord: Codable, Hashable {
    var attempts: Int = 0
    var correctCount: Int = 0
    var isFavorite: Bool = false
    var isMastered: Bool = false
    var lastStudiedAt: Date?

    var isWrong: Bool { attempts > correctCount }
}

enum NoteMode: String, Codable, CaseIterable, Identifiable {
    case handwriting
    case typing
    case mixed

    var id: String { rawValue }
    var title: String {
        switch self {
        case .typing: return "打字"
        case .handwriting: return "手写"
        case .mixed: return "混合"
        }
    }
}

struct RichNote: Codable, Hashable {
    var questionID: String
    var text: String = ""
    var drawingData: Data = Data()
    var mode: NoteMode = .handwriting
    var updatedAt: Date = .now
}

struct QuestionAnnotation: Codable, Hashable {
    var questionID: String
    var drawingData: Data = Data()
    var highlightedRanges: [RangeRecord] = []
    var updatedAt: Date = .now
}

struct RangeRecord: Codable, Hashable, Identifiable {
    let id: UUID
    var location: Int
    var length: Int

    init(id: UUID = UUID(), location: Int, length: Int) {
        self.id = id
        self.location = location
        self.length = length
    }
}

struct QuestionCollection: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var questionIDs: [String]
    var createdAt: Date
    var bankID: UUID?

    init(id: UUID = UUID(), name: String, questionIDs: [String] = [], createdAt: Date = .now, bankID: UUID? = nil) {
        self.id = id
        self.name = name
        self.questionIDs = questionIDs
        self.createdAt = createdAt
        self.bankID = bankID
    }
}

struct ExamRecord: Identifiable, Codable, Hashable {
    let id: UUID
    var date: Date
    var total: Int
    var correct: Int

    var score: Int {
        guard total > 0 else { return 0 }
        return Int((Double(correct) / Double(total) * 100).rounded())
    }
}

struct LearningSnapshot: Codable {
    var activeBankID: UUID?
    var importedBanks: [QuestionBank] = []
    var records: [String: StudyRecord] = [:]
    var notes: [String: RichNote] = [:]
    var annotations: [String: QuestionAnnotation] = [:]
    var collections: [QuestionCollection] = []
    var relatedQuestionIDs: [String: [String]]?
    var collectionMindMaps: [String: SavedCollectionMindMap]?
    var examRecords: [ExamRecord] = []
    /// 按本地自然日保存实际练习过的题目 ID。可选字段用于兼容旧版存档。
    var dailyStudyQuestionIDs: [String: [String]]?
}
