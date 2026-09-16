import Foundation
import Combine

struct ChatConversation: Identifiable, Codable {
    var id: String
    var title: String
    var question: QuestionData?
    var messages: [ChatMessage]
    var updatedAt: Date
}

@MainActor
final class ChatHistoryStore: ObservableObject {
    static let shared = ChatHistoryStore()
    @Published private(set) var conversations: [ChatConversation] = []
    @Published private(set) var storageError: String?
    private let url: URL
    private var storageWritable = true

    init(url: URL? = nil) {
        self.url = url ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Aeropass/chat-history.json")
        if let data = try? Data(contentsOf: self.url),
           let stored = try? JSONDecoder().decode([ChatConversation].self, from: data) {
            conversations = stored.map { conversation in
                var copy = conversation
                copy.messages = copy.messages.map { message in
                    var result = message; result.isStreaming = false; return result
                }
                return copy
            }
        } else if FileManager.default.fileExists(atPath: self.url.path) {
            storageWritable = false
            storageError = "对话存档无法读取，原文件已保留"
        }
    }

    static func key(for question: QuestionData?) -> String {
        guard let question else { return "general" }
        return "\(question.bankID?.uuidString ?? "builtin"):\(question.questionId)"
    }

    func conversation(for question: QuestionData?) -> ChatConversation? {
        conversations.first { $0.id == Self.key(for: question) && $0.question?.studyFingerprint == question?.studyFingerprint }
    }

    func save(messages: [ChatMessage], question: QuestionData?) {
        let saved = messages.filter { !$0.content.isEmpty }.map { message in
            var copy = message; copy.isStreaming = false; return copy
        }
        guard saved.contains(where: { $0.role == .user }) else { return }
        let id = Self.key(for: question)
        let conversation = ChatConversation(id: id,
            title: question?.content ?? saved.first(where: { $0.role == .user && !$0.isHidden })?.content ?? "AI 辅导答疑",
            question: question, messages: saved, updatedAt: .now)
        conversations.removeAll { $0.id == id }
        conversations.insert(conversation, at: 0)
        // Store full conversations; local history has no silent eviction.
        persist()
    }

    func delete(_ id: String) { conversations.removeAll { $0.id == id }; persist() }
    func clear() { storageWritable = true; conversations = []; persist() }
    func delete(bankID: UUID) { conversations.removeAll { $0.question?.bankID == bankID }; persist() }

    private func persist() {
        guard storageWritable else { storageError = "对话存档无法读取，已停止写入以保留原文件"; return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(conversations).write(to: url, options: .atomic)
            storageError = nil
        } catch { storageError = "对话历史保存失败，请检查本机可用空间" }
    }
}
