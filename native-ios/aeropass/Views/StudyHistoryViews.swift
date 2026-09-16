import SwiftUI

struct AIChatHistoryView: View {
    @StateObject private var store = ChatHistoryStore.shared
    @State private var query = ""
    @State private var selectedConversation: ChatConversation?
    @State private var showClear = false
    private var results: [ChatConversation] {
        store.conversations.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.messages.contains { $0.content.localizedCaseInsensitiveContains(query) } }
    }
    var body: some View {
        List {
            ForEach(results) { conversation in
                Button { selectedConversation = conversation } label: {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(conversation.title).lineLimit(2).foregroundStyle(.primary)
                        Text(conversation.messages.last(where: { !$0.isHidden })?.content ?? String(localized: "尚未生成回答")).font(.caption).lineLimit(2).foregroundStyle(.secondary)
                        Text(conversation.updatedAt, format: .dateTime.month().day().hour().minute()).font(.caption2).foregroundStyle(.secondary)
                    }
                }.swipeActions { Button("删除", role: .destructive) { store.delete(conversation.id) } }
            }
            if let error = store.storageError { Text(error).foregroundStyle(.red) }
        }
        .navigationTitle("AI 对话历史")
        .searchable(text: $query, prompt: "搜索问题或回答")
        .overlay { if results.isEmpty { ContentUnavailableView("暂无对话历史", systemImage: "bubble.left.and.bubble.right", description: Text("AI 问答会自动保存，方便恢复和继续追问。")) } }
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("清空", role: .destructive) { showClear = true }.disabled(store.conversations.isEmpty) } }
        .alert("清空全部 AI 对话？", isPresented: $showClear) {
            Button("取消", role: .cancel) { }
            Button("清空", role: .destructive) { store.clear() }
        } message: { Text("本机保存的对话历史将被删除。") }
        .sheet(item: $selectedConversation) { conversation in AIChatView(question: conversation.question) }
    }
}

struct StudyNotesView: View {
    @StateObject private var manager = QuestionManager.shared
    @State private var query = ""
    private var questions: [QuestionData] {
        (manager.activeBank?.questions ?? []).filter { question in
            let note = manager.richNote(for: question.questionId)
            return (!note.text.isEmpty || !note.drawingData.isEmpty) &&
                (query.isEmpty || question.content.localizedCaseInsensitiveContains(query) || note.text.localizedCaseInsensitiveContains(query))
        }.sorted { manager.richNote(for: $0.questionId).updatedAt > manager.richNote(for: $1.questionId).updatedAt }
    }
    var body: some View {
        List(questions) { question in
            NavigationLink { QuestionDetailNativeView(question: question) } label: {
                VStack(alignment: .leading, spacing: 7) {
                    Text(question.content).lineLimit(2)
                    let note = manager.richNote(for: question.questionId)
                    if !note.text.isEmpty { Text(note.text).lineLimit(2).font(.caption).foregroundStyle(.secondary) }
                    if !note.drawingData.isEmpty { Label("含手写笔记", systemImage: "pencil.tip").font(.caption).foregroundStyle(.tint) }
                }
            }
        }
        .navigationTitle("我的笔记")
        .searchable(text: $query, prompt: "搜索题目或笔记")
        .overlay { if questions.isEmpty { ContentUnavailableView("暂无匹配的笔记", systemImage: "note.text", description: Text("可从题目详情或学习卡片记录打字、手写和混合笔记。")) } }
    }
}
