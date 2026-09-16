import Foundation
import Combine

@MainActor
class MemorizeViewModel: ObservableObject {
    @Published var currentIndex: Int = 0
    @Published var showAnswer: Bool = true
    @Published var questions: [QuestionData] = []
    @Published var masteredQuestions: [QuestionData] = []

    var progressKey = "memorizeLastIndex"
    private let qm = QuestionManager.shared
    private var allScopedQuestions: [QuestionData] = []

    init() {}

    func setup(questions: [QuestionData]) {
        let uniqueQuestions = questions.uniquedForStudy()
        allScopedQuestions = uniqueQuestions
        masteredQuestions = uniqueQuestions.filter { qm.isMastered($0.questionId) }
        self.questions = uniqueQuestions.filter { !qm.isMastered($0.questionId) }
        currentIndex = self.questions.isEmpty ? 0 : min(currentIndex, self.questions.count - 1)
    }

    var currentQuestion: QuestionData? {
        guard currentIndex >= 0 && currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    func toggleAnswer() {
        showAnswer.toggle()
    }

    func markMastered(_ isMastered: Bool) {
        guard let current = currentQuestion else { return }
        qm.setMastered(current.questionId, mastered: isMastered)
        guard isMastered, let index = questions.firstIndex(where: { $0.questionId == current.questionId }) else { return }
        masteredQuestions.append(current)
        questions.remove(at: index)
        currentIndex = questions.isEmpty ? 0 : min(index, questions.count - 1)
        saveProgress()
    }

    func restoreMastered(_ question: QuestionData) {
        qm.setMastered(question.questionId, mastered: false)
        masteredQuestions.removeAll { $0.questionId == question.questionId }
        guard !questions.contains(where: { $0.questionId == question.questionId }) else { return }
        let originalOrder = Dictionary(
            uniqueKeysWithValues: allScopedQuestions.enumerated().map { ($0.element.questionId, $0.offset) }
        )
        questions.append(question)
        questions.sort {
            originalOrder[$0.questionId, default: .max] < originalOrder[$1.questionId, default: .max]
        }
    }

    func toggleFavorite() {
        guard let current = currentQuestion else { return }
        qm.toggleFavorite(current.questionId)
    }

    func nextQuestion() {
        if currentIndex < questions.count - 1 {
            currentIndex += 1
            saveProgress()
        }
    }

    func previousQuestion() {
        if currentIndex > 0 {
            currentIndex -= 1
            saveProgress()
        }
    }

    func jumpTo(index: Int) {
        let safeIndex = max(0, min(index, questions.count - 1))
        if safeIndex != currentIndex {
            currentIndex = safeIndex
            saveProgress()
        }
    }

    func restoreProgress(lastIndex: Int) {
        let safeIndex = max(0, min(lastIndex, questions.count - 1))
        if safeIndex < questions.count {
            currentIndex = safeIndex
        }
    }

    func saveProgress() {
        UserDefaults.standard.set(currentIndex, forKey: progressKey)
    }
}
