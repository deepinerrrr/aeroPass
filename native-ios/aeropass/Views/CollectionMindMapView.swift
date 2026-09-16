import SwiftUI
import Combine

struct MindMapQuestionSelectionView: View {
    let collectionID: UUID
    @StateObject private var manager = QuestionManager.shared
    @State private var selected = Set<String>()
    @State private var query = ""
    @State private var didSetup = false
    private var questions: [QuestionData] { manager.collectionQuestions(collectionID) }
    private var results: [QuestionData] {
        questions.filter { query.isEmpty || $0.content.localizedCaseInsensitiveContains(query) || $0.questionId.localizedCaseInsensitiveContains(query) }
    }
    var body: some View {
        List {
            Section {
                LabeledContent("已选择", value: "\(selected.count) / \(questions.count)")
                Button(selected.count == questions.count ? "取消全选" : "全选") {
                    selected = selected.count == questions.count ? [] : Set(questions.map(\.questionId))
                }
            } footer: {
                Text("仅将所选题目的内容用于 AI 分析，题目编号不会发送。生成结果会保存在当前合集。")
            }
            ForEach(results) { question in
                Button { if !selected.insert(question.questionId).inserted { selected.remove(question.questionId) } } label: {
                    HStack(alignment: .top) {
                        Image(systemName: selected.contains(question.questionId) ? "checkmark.circle.fill" : "circle").foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(question.content)
                            Text(question.isTrueFalse ? "判断题" : "单选题").font(.caption).foregroundStyle(.secondary)
                        }.foregroundStyle(.primary)
                    }.padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("选择导图题目")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "搜索题目")
        .safeAreaInset(edge: .bottom) {
            NavigationLink {
                CollectionMindMapView(collectionID: collectionID,
                    questions: questions.filter { selected.contains($0.questionId) }, generateImmediately: true)
            } label: { Label("生成思维导图（\(selected.count)）", systemImage: "sparkles").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).disabled(selected.isEmpty).padding().background(.bar)
        }
        .onAppear {
            guard !didSetup else { return }; didSetup = true
            selected = Set(questions.map(\.questionId))
        }
    }
}

@MainActor
final class CollectionMindMapViewModel: ObservableObject {
    @Published private(set) var saved: SavedCollectionMindMap?
    @Published private(set) var isGenerating = false
    @Published private(set) var receivedCharacters = 0
    @Published private(set) var errorMessage: String?
    private var task: Task<Void, Never>?
    private var generationID: UUID?
    private let manager = QuestionManager.shared

    func restore(_ id: UUID) { saved = manager.savedMindMap(for: id) }

    func generate(collectionID: UUID, questions: [QuestionData]) {
        guard !isGenerating, !questions.isEmpty,
              let collection = manager.collections.first(where: { $0.id == collectionID }) else { return }
        let context = CollectionMindMap.context(name: collection.name, questions: questions)
        guard context.utf8.count <= 90_000 else {
            errorMessage = "所选题目内容过多，请返回选择页减少题目后生成"; return
        }
        let provider = AIService.selectedProvider
        let token = UUID()
        generationID = token
        isGenerating = true
        receivedCharacters = 0
        errorMessage = nil
        // Keep the existing successful map visible until a replacement succeeds.
        task = Task { [weak self] in
            guard let self else { return }
            var response = ""
            do {
                try await AIService.shared.respond(messages: [
                    ["role": "system", "content": CollectionMindMap.systemPrompt],
                    ["role": "user", "content": context]
                ], provider: provider) { [weak self] delta in
                    guard let self, self.generationID == token else { return }
                    response += delta
                    self.receivedCharacters = response.count
                }
                try Task.checkCancellation()
                let map = try CollectionMindMap.parse(response, fallbackTitle: collection.name)
                guard self.generationID == token else { return }
                let saved = SavedCollectionMindMap(map: map, questions: questions, provider: provider)
                guard saved.matches(self.manager.collectionQuestions(collectionID)) else {
                    throw AIStreamError.message("合集题目已变化，请重新选择题目生成")
                }
                self.manager.saveMindMap(saved, for: collectionID)
                self.saved = saved
                self.errorMessage = self.manager.storageError
            } catch {
                if self.generationID == token, !Task.isCancelled { self.errorMessage = error.localizedDescription }
            }
            guard self.generationID == token else { return }
            self.isGenerating = false; self.task = nil; self.generationID = nil
        }
    }
    func stop() {
        generationID = nil; task?.cancel(); task = nil; isGenerating = false
    }
}

struct CollectionMindMapView: View {
    let collectionID: UUID
    let questions: [QuestionData]
    var generateImmediately = false
    @StateObject private var model = CollectionMindMapViewModel()
    @State private var didSetup = false
    @State private var zoomRequest = MindMapZoomRequest()
    @State private var zoom = 1.0

    private var sourceQuestions: [QuestionData] {
        guard !generateImmediately, let saved = model.saved else { return questions }
        return questions.filter { saved.fingerprints[$0.questionId] != nil }
    }
    var body: some View {
        VStack(spacing: 0) {
            if model.isGenerating {
                HStack {
                    ProgressView()
                    Text("正在整理知识点… 已接收 \(model.receivedCharacters) 字").font(.caption)
                    Spacer()
                    Button("停止") { model.stop() }
                }.padding().background(.bar)
            }
            if let error = model.errorMessage {
                VStack(spacing: 8) {
                    Text(error).font(.callout).foregroundStyle(.red)
                    if !model.isGenerating { Button("重试生成") { generate() } }
                    NavigationLink("检查 AI 配置") { AIConfigurationView() }
                }.padding()
            }
            if let saved = model.saved {
                ZoomableMindMap(map: saved.map, request: zoomRequest, zoom: $zoom)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack {
                    Text("\(saved.fingerprints.count) 题 · \(saved.provider == "qwen" ? "Qwen" : "DeepSeek")")
                    Spacer()
                    Text("双指缩放 · 拖动查看")
                }.font(.caption).foregroundStyle(.secondary).padding(.horizontal).padding(.vertical, 8)
            } else if !model.isGenerating && model.errorMessage == nil {
                ContentUnavailableView("尚未生成思维导图", systemImage: "point.3.connected.trianglepath.dotted",
                    description: Text("根据选中的题目提炼核心知识点。"))
                Button("生成思维导图") { generate() }.buttonStyle(.borderedProminent).padding()
            } else { Spacer() }
            if model.saved != nil {
                HStack(spacing: 22) {
                    Button { zoomRequest = MindMapZoomRequest(factor: 0.8) } label: { Image(systemName: "minus.magnifyingglass") }.accessibilityLabel("缩小导图")
                    Text("\(Int(zoom * 100))%").monospacedDigit().frame(width: 52)
                    Button { zoomRequest = MindMapZoomRequest(factor: 1.25) } label: { Image(systemName: "plus.magnifyingglass") }.accessibilityLabel("放大导图")
                    Spacer()
                    Button("复位") { zoomRequest = MindMapZoomRequest(factor: 0) }
                }.padding().background(.bar)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("合集思维导图")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("重新生成", systemImage: "arrow.clockwise") { generate() }.disabled(model.isGenerating)
                    NavigationLink("重新选择题目") { MindMapQuestionSelectionView(collectionID: collectionID) }
                    if let map = model.saved?.map {
                        ShareLink(item: ([map.title] + map.nodes.map { "\($0.title)\n" + $0.children.map { "• \($0)" }.joined(separator: "\n") }).joined(separator: "\n\n"))
                    }
                } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel("导图操作")
            }
        }
        .task {
            guard !didSetup else { return }; didSetup = true
            model.restore(collectionID)
            if generateImmediately { generate() }
        }
        .onDisappear { model.stop() }
    }
    private func generate() { model.generate(collectionID: collectionID, questions: sourceQuestions) }
}
