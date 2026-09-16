import Foundation
import Combine

@MainActor
final class AIChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText = ""
    @Published private(set) var isGenerating = false
    @Published var provider = AIService.selectedProvider
    @Published private(set) var errorMessage: String?
    @Published private(set) var storageError: String?
    var currentQuestion: QuestionData?
    var lastScrollTime: Date = .distantPast
    private var generationTask: Task<Void, Never>?
    private var generationID: UUID?
    private var didSetup = false
    private var lastCheckpoint: Date = .distantPast
    private let history: ChatHistoryStore
    private let service: any AIResponding

    init(history: ChatHistoryStore? = nil, service: (any AIResponding)? = nil) {
        self.history = history ?? .shared
        self.service = service ?? AIService.shared
    }

    func setup(question: QuestionData) {
        guard !didSetup else { return }
        didSetup = true
        currentQuestion = question
        if let saved = history.conversation(for: question), !saved.messages.isEmpty {
            messages = saved.messages
            if messages.last?.role == .user { errorMessage = "尚未生成回答，请点击重试回答" }
        } else { sendInitialAnalysis() }
    }

    func setupForGeneralChat() {
        guard !didSetup else { return }
        didSetup = true
        messages = history.conversation(for: nil)?.messages ?? [ChatMessage(role: .assistant,
            content: "你好！我是你的 AI 辅导助手✈️\n\n你可以问我关于航空执照考试的问题。")]
        if messages.last?.role == .user { errorMessage = "尚未生成回答，请点击重试回答" }
    }

    private func sendInitialAnalysis() {
        guard let question = currentQuestion else { return }
        let options = question.options.map { "\($0.key). \($0.text)" }.joined(separator: "\n")
        sendMessage("""
        请解析以下航空执照考试题目：
        【题干】\(question.content)
        【选项】\(options.isEmpty ? "判断题：A=正确，B=错误" : options)
        【正确答案】\(question.correctAnswer)
        【参考解析】\(question.referenceAnswer ?? "无")
        请按“题目解析、知识拓展、通俗解释”三部分回答，每部分都需有实质内容。解释正确答案并分析其他选项，给出相关知识和生活类比、记忆方法。参考答案即为正确答案，不要输出思考过程。
        """, isHiddenUserMessage: true)
    }

    func sendMessage(_ text: String, isHiddenUserMessage: Bool = false) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isGenerating else { return }
        // An empty failed placeholder should never be sent back to the API.
        messages.removeAll { $0.role == .assistant && $0.content.isEmpty }
        messages.append(ChatMessage(role: .user, content: trimmed, isHidden: isHiddenUserMessage))
        inputText = ""
        generateResponse()
    }

    func retryLastResponse() {
        guard !isGenerating, messages.contains(where: { $0.role == .user }) else { return }
        if messages.last?.role == .assistant { messages.removeLast() }
        generateResponse()
    }

    private func generateResponse() {
        errorMessage = nil
        let apiMessages = messages.filter { !$0.content.isEmpty }.map { ["role": $0.role.rawValue, "content": $0.content] }
        let assistant = ChatMessage(role: .assistant, content: "", isStreaming: true)
        messages.append(assistant)
        let token = UUID()
        generationID = token
        isGenerating = true
        let selectedProvider = provider
        generationTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.service.respond(messages: apiMessages, provider: selectedProvider) { [weak self] delta in
                    guard let self, self.generationID == token,
                          let index = self.messages.firstIndex(where: { $0.id == assistant.id }) else { return }
                    self.messages[index].content += delta
                    if Date().timeIntervalSince(self.lastCheckpoint) > 1 {
                        self.lastCheckpoint = .now
                        self.saveHistory()
                    }
                }
            } catch {
                if self.generationID == token, !Task.isCancelled {
                    self.errorMessage = error.localizedDescription
                }
            }
            guard self.generationID == token else { return }
            if let index = self.messages.firstIndex(where: { $0.id == assistant.id }) { self.messages[index].isStreaming = false }
            self.isGenerating = false
            self.generationTask = nil
            self.generationID = nil
            self.saveHistory()
        }
    }

    func stopGenerating() {
        generationID = nil
        generationTask?.cancel()
        generationTask = nil
        messages = messages.map { message in var copy = message; copy.isStreaming = false; return copy }
        isGenerating = false
        saveHistory()
    }

    func clearHistory() {
        stopGenerating()
        history.delete(ChatHistoryStore.key(for: currentQuestion))
        messages = []
        errorMessage = nil
        if currentQuestion != nil { sendInitialAnalysis() }
        else { messages = [ChatMessage(role: .assistant, content: "你好！你可以开始新的航空知识问答。") ] }
    }

    private func saveHistory() {
        history.save(messages: messages, question: currentQuestion)
        storageError = history.storageError
    }
}
