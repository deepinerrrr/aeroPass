import Foundation
import Combine

@MainActor
class MockExamViewModel: ObservableObject {
    @Published var currentIndex: Int = 0
    @Published var selectedOptions: [String: String] = [:] // Question ID to selected Option
    @Published var isFinished: Bool = false
    @Published var score: Int = 0
    
    var questions: [QuestionData] = []
    private let qm = QuestionManager.shared
    
    init() {}
    
    func setup(allQuestions: [QuestionData]) {
        // 随机抽取 300 题，不够则全选
        let count = min(300, allQuestions.count)
        self.questions = Array(allQuestions.shuffled().prefix(count))
        self.currentIndex = 0
        self.selectedOptions.removeAll()
        self.isFinished = false
        self.score = 0
    }
    
    var currentQuestion: QuestionData? {
        guard currentIndex >= 0 && currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }
    
    func selectOption(_ option: String) {
        guard let current = currentQuestion else { return }
        selectedOptions[current.id] = option
        
        // 自动跳转下一题
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.nextQuestion()
        }
    }
    
    func nextQuestion() {
        if currentIndex < questions.count - 1 {
            currentIndex += 1
        }
    }
    
    func previousQuestion() {
        if currentIndex > 0 {
            currentIndex -= 1
        }
    }
    
    func finishExam() {
        var correctCount = 0
        for question in questions {
            if let selected = selectedOptions[question.id], selected == question.correctAnswer {
                correctCount += 1
            } else if selectedOptions[question.id] != nil {
                // 答错了的加入错题本
                qm.markWrong(question.questionId)
            }
        }
        
        // 计算得分，满分100，按比例折算
        if questions.count > 0 {
            self.score = Int((Double(correctCount) / Double(questions.count)) * 100)
        }
        qm.saveExamRecord(total: questions.count, correct: correctCount)
        qm.recordStudy(
            questionIDs: questions.compactMap { question in
                selectedOptions[question.id] == nil ? nil : question.questionId
            }
        )
        
        isFinished = true
    }
}
