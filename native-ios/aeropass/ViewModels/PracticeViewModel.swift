import Foundation
import Combine

@MainActor
class PracticeViewModel: ObservableObject {
    @Published var currentIndex: Int = 0
    @Published var showAnswer: Bool = false
    @Published var selectedOption: String? = nil
    @Published var questions: [QuestionData] = []
    
    var scopeID: String?
    var mode: PracticeMode = .sequential
    private let qm = QuestionManager.shared
    private var autoAdvanceGeneration = 0
    
    init() {}
    
    func setup(questions: [QuestionData], mode: PracticeMode = .sequential) {
        self.questions = questions
            .uniquedForStudy()
            .filter { !qm.isMastered($0.questionId) }
        self.mode = mode
        currentIndex = 0

        let savedIndex = UserDefaults.standard.integer(forKey: progressKey)
        if savedIndex > 0 && savedIndex < self.questions.count {
            currentIndex = savedIndex
        }
    }
    
    private var progressKey: String {
        let suffix = scopeID.map { "_\($0)" } ?? ""
        switch mode {
        case .sequential: return "practice_seq_lastIndex" + suffix
        case .random: return "practice_rand_lastIndex" + suffix
        case .wrongbook: return "practice_wrong_lastIndex" + suffix
        case .favorites: return "practice_fav_lastIndex" + suffix
        }
    }
    
    var currentQuestion: QuestionData? {
        guard currentIndex >= 0 && currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }
    
    func selectOption(_ option: String) {
        guard !showAnswer, let current = currentQuestion else { return }
        
        selectedOption = option
        showAnswer = true
        
        let isCorrect = (option == current.correctAnswer)
        qm.recordAnswer(questionID: current.questionId, isCorrect: isCorrect)
        
        if isCorrect {
            autoAdvanceGeneration += 1
            let generation = autoAdvanceGeneration
            let questionID = current.questionId
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                guard generation == self.autoAdvanceGeneration,
                      self.currentQuestion?.questionId == questionID else { return }
                self.nextQuestion(automatically: true)
            }
        }
    }

    func markCurrentQuestionMastered() {
        autoAdvanceGeneration += 1
        guard let current = currentQuestion,
              let index = questions.firstIndex(where: { $0.questionId == current.questionId }) else { return }
        qm.setMastered(current.questionId, mastered: true)
        questions.remove(at: index)
        currentIndex = questions.isEmpty ? 0 : min(index, questions.count - 1)
        resetState()
        saveProgress()
    }

    func nextQuestion(automatically: Bool = false) {
        if !automatically { autoAdvanceGeneration += 1 }
        if currentIndex < questions.count - 1 {
            currentIndex += 1
            resetState()
            saveProgress()
        }
    }

    func previousQuestion() {
        autoAdvanceGeneration += 1
        if currentIndex > 0 {
            currentIndex -= 1
            resetState()
            saveProgress()
        }
    }
    
    private func resetState() {
        showAnswer = false
        selectedOption = nil
    }
    
    func resetStateForVerticalPaging() {
        showAnswer = false
        selectedOption = nil
    }
    
    func jumpTo(index: Int) {
        autoAdvanceGeneration += 1
        let safeIndex = max(0, min(index, questions.count - 1))
        if safeIndex != currentIndex {
            currentIndex = safeIndex
            resetState()
            saveProgress()
        }
    }
    
    func toggleFavorite() {
        guard let current = currentQuestion else { return }
        qm.toggleFavorite(current.questionId)
    }
    
    func saveProgress() {
        UserDefaults.standard.set(currentIndex, forKey: progressKey)
    }
}
