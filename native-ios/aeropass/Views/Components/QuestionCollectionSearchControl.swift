import SwiftUI

/// 背题、刷题共用的题目搜索入口。结果在独立页面中展示，避免被翻页卡片裁切。
struct QuestionCollectionSearchControl: View {
    let themeColor: Color
    var initialQuery = ""

    @State private var isPresented = false

    var body: some View {
        Button { isPresented = true } label: {
            Label("搜索题目建合集", systemImage: "magnifyingglass")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .buttonStyle(.bordered)
        .tint(themeColor)
        .accessibilityLabel("搜索题目并建立合集")
        .sheet(isPresented: $isPresented) {
            QuestionCollectionSearchSheet(initialQuery: initialQuery, themeColor: themeColor)
        }
    }
}

struct QuestionCollectionSearchSheet: View {
    let initialQuery: String
    let themeColor: Color

    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = QuestionManager.shared
    @State private var query: String
    @State private var selectedQuestionIDs = Set<String>()
    @State private var results: [QuestionData] = []
    @State private var message: String?
    @State private var searchTask: Task<Void, Never>?

    init(initialQuery: String = "", themeColor: Color) {
        self.initialQuery = initialQuery
        self.themeColor = themeColor
        _query = State(initialValue: initialQuery.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var keyword: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var bankQuestions: [QuestionData] { manager.activeBank?.questions ?? [] }
    private var existingCollection: QuestionCollection? {
        manager.collections.first {
            $0.bankID == manager.activeBank?.id && $0.name.localizedCaseInsensitiveCompare(keyword) == .orderedSame
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if keyword.isEmpty {
                    ContentUnavailableView("搜索题目", systemImage: "magnifyingglass", description: Text("输入题目、选项或题号中的文字，再选择要加入合集的题目。"))
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: keyword)
                } else {
                    HStack {
                        Text("找到 \(results.count) 题 · 已选 \(selectedQuestionIDs.count) 题")
                        Spacer()
                        Button("全选") { selectedQuestionIDs.formUnion(results.map(\.questionId)) }
                        Button("清空") { selectedQuestionIDs.subtract(results.map(\.questionId)) }
                    }
                    .font(.caption)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    List(results) { question in
                        Button { toggle(question.questionId) } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: selectedQuestionIDs.contains(question.questionId) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedQuestionIDs.contains(question.questionId) ? themeColor : .secondary)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(question.content)
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.leading)
                                    Text("题号 \(question.questionId)")
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(selectedQuestionIDs.contains(question.questionId) ? "已选" : "未选")，题号 \(question.questionId)，\(question.content)")
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("搜索题目建合集")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "题目、选项或题号")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: createCollection) {
                    Group {
                        if existingCollection == nil {
                            Text("创建合集“\(keyword)” · \(selectedQuestionIDs.count) 题")
                        } else {
                            Text("加入合集“\(keyword)” · \(selectedQuestionIDs.count) 题")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(themeColor)
                .disabled(keyword.isEmpty || selectedQuestionIDs.isEmpty)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.regularMaterial)
            }
            .alert("无法建立合集", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("好", role: .cancel) { message = nil }
            } message: { Text(message ?? "") }
        }
        .onAppear { searchNow() }
        .onChange(of: query) { _, _ in scheduleSearch() }
        .onDisappear { searchTask?.cancel() }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            searchNow()
        }
    }

    private func searchNow() {
        let key = keyword
        guard !key.isEmpty else { results = []; selectedQuestionIDs = []; return }
        results = bankQuestions.filter { question in
            [question.questionId, question.content, question.optionA, question.optionB,
             question.optionC, question.optionD, question.referenceAnswer]
                .contains { $0?.localizedStandardContains(key) == true }
        }
        let validIDs = Set(bankQuestions.map(\.questionId))
        selectedQuestionIDs.formIntersection(validIDs)
        if let existingCollection { selectedQuestionIDs.formUnion(existingCollection.questionIDs) }
    }

    private func toggle(_ id: String) {
        if selectedQuestionIDs.contains(id) { selectedQuestionIDs.remove(id) }
        else { selectedQuestionIDs.insert(id) }
    }

    private func createCollection() {
        let validIDs = Set(bankQuestions.map(\.questionId))
        let ids = selectedQuestionIDs.intersection(validIDs)
        guard !keyword.isEmpty, !ids.isEmpty else { return }
        guard manager.createOrUpdateCollection(named: keyword, questionIDs: Array(ids)) != nil else {
            message = "合集未保存，请检查当前题库后重试。"
            return
        }
        dismiss()
    }
}
