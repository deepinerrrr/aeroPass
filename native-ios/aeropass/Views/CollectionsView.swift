import SwiftUI

struct CollectionsView: View {
    @StateObject private var manager = QuestionManager.shared
    @State private var query = ""
    @State private var name = ""
    @State private var renameTarget: QuestionCollection?
    @State private var deleteTarget: QuestionCollection?
    @State private var showCreate = false
    @State private var message: String?
    @State private var sortByCount = true

    private var results: [QuestionCollection] {
        manager.collections.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
            .sorted { a, b in
                if sortByCount && a.questionIDs.count != b.questionIDs.count { return a.questionIDs.count > b.questionIDs.count }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
    }

    var body: some View {
        List {
            Section("默认题库判断题") {
                judgeButton(true)
                judgeButton(false)
            }
            Section("我的合集 · \(results.count)") {
                ForEach(results) { collection in
                    NavigationLink { CollectionQuestionsView(collectionID: collection.id) } label: {
                        HStack {
                            Image(systemName: "folder.fill").foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(collection.name)
                                Text(manager.banks.first { $0.id == collection.bankID }?.name ?? "题库已移除")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(manager.collectionQuestions(collection.id).count) 题").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions {
                        Button("删除", role: .destructive) { deleteTarget = collection }
                        Button("重命名") { name = collection.name; renameTarget = collection }.tint(.orange)
                    }
                    .contextMenu {
                        Button("重命名", systemImage: "pencil") { name = collection.name; renameTarget = collection }
                        Button("删除合集", systemImage: "trash", role: .destructive) { deleteTarget = collection }
                    }
                }
                if results.isEmpty {
                    ContentUnavailableView(query.isEmpty ? "暂无合集" : "没有匹配的合集", systemImage: "folder",
                        description: Text("新建合集后可按关键词批量添加题目，也可从题目卡片收录。"))
                }
            }
            if let error = manager.storageError { Text(error).foregroundStyle(.red) }
        }
        .navigationTitle("我的合集")
        .searchable(text: $query, prompt: "搜索合集名称")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Toggle("按题量排序", isOn: $sortByCount)
                } label: { Image(systemName: "arrow.up.arrow.down") }.accessibilityLabel("合集排序")
                Button { name = ""; showCreate = true } label: { Image(systemName: "plus") }.accessibilityLabel("新建合集")
            }
        }
        .alert("新建合集", isPresented: $showCreate) {
            TextField("合集名称", text: $name)
            Button("取消", role: .cancel) { }
            Button("新建") {
                if manager.createOrUpdateCollection(named: name, questionIDs: []) == nil { message = "请输入有效的合集名称" }
            }
        } message: { Text("同一题库的同名合集会合并。") }
        .alert("重命名合集", isPresented: Binding(get: { renameTarget != nil }, set: { if !$0 { renameTarget = nil } })) {
            TextField("合集名称", text: $name)
            Button("取消", role: .cancel) { renameTarget = nil }
            Button("保存") {
                if let target = renameTarget, !manager.renameCollection(target.id, to: name) { message = "名称不能为空，也不能与同一题库的其他合集重名" }
                renameTarget = nil
            }
        }
        .alert("删除合集？", isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } })) {
            Button("取消", role: .cancel) { deleteTarget = nil }
            Button("删除", role: .destructive) { if let target = deleteTarget { manager.deleteCollection(target.id) }; deleteTarget = nil }
        } message: { Text("将删除合集及保存的思维导图，题库原题、笔记和学习记录会保留。") }
        .alert("提示", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("好") { message = nil }
        } message: { Text(message ?? "") }
    }

    private func judgeButton(_ correct: Bool) -> some View {
        let count = manager.defaultJudgeQuestions(answerIsCorrect: correct).count
        return Button {
            if manager.syncDefaultJudgeCollection(answerIsCorrect: correct) != nil { message = "已同步 \(count) 道判断题到合集" }
        } label: {
            LabeledContent(correct ? "判断题 · 答案正确" : "判断题 · 答案错误", value: "\(count) 题")
        }.disabled(count == 0)
    }
}

struct CollectionQuestionsView: View {
    let collectionID: UUID
    @StateObject private var manager = QuestionManager.shared
    @State private var query = ""
    @State private var showAdd = false
    @State private var selected = Set<String>()
    @State private var isManaging = false
    @State private var showRemove = false

    private var collection: QuestionCollection? { manager.collections.first { $0.id == collectionID } }
    private var questions: [QuestionData] { manager.collectionQuestions(collectionID) }
    private var results: [QuestionData] {
        questions.filter { query.isEmpty || $0.content.localizedCaseInsensitiveContains(query) || $0.questionId.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List {
            if !questions.isEmpty {
                Section {
                    NavigationLink {
                        MindMapQuestionSelectionView(collectionID: collectionID)
                    } label: { Label("选择题目生成思维导图", systemImage: "sparkles") }
                    if manager.savedMindMap(for: collectionID) != nil {
                        NavigationLink { CollectionMindMapView(collectionID: collectionID, questions: questions) } label: {
                            Label("查看已保存的思维导图", systemImage: "point.3.connected.trianglepath.dotted")
                        }
                    }
                    NavigationLink { MemorizeView(initialQuestions: questions, scopeID: collectionID.uuidString) } label: { Label("背诵合集", systemImage: "book") }
                    NavigationLink { PracticeView(mode: .sequential, initialQuestions: questions, scopeID: collectionID.uuidString) } label: { Label("练习合集", systemImage: "pencil.and.list.clipboard") }
                }
            }
            Section("\(questions.count) 道题目") {
                ForEach(results) { question in
                    if isManaging {
                        Button { if !selected.insert(question.questionId).inserted { selected.remove(question.questionId) } } label: {
                            HStack {
                                Image(systemName: selected.contains(question.questionId) ? "checkmark.circle.fill" : "circle")
                                questionLabel(question)
                            }
                        }.foregroundStyle(.primary)
                    } else {
                        NavigationLink { QuestionDetailNativeView(question: question) } label: { questionLabel(question) }
                            .swipeActions { Button("移出合集", role: .destructive) { manager.removeQuestions([question.questionId], from: collectionID) } }
                    }
                }
                if results.isEmpty {
                    ContentUnavailableView(questions.isEmpty ? "该合集暂无题目" : "没有匹配的题目", systemImage: "doc.text.magnifyingglass",
                        description: Text("点击右上角加号，搜索并收录题目。"))
                }
            }
        }
        .navigationTitle(collection?.name ?? "合集")
        .searchable(text: $query, prompt: "搜索合集内题干或题号")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(isManaging ? "完成" : "管理") { isManaging.toggle(); selected = [] }.disabled(questions.isEmpty)
                Button { showAdd = true } label: { Image(systemName: "plus") }.accessibilityLabel("添加题目")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isManaging {
                HStack {
                    Button(selected.isSuperset(of: results.map(\.questionId)) && !results.isEmpty ? "取消全选" : "全选") {
                        let visible = Set(results.map(\.questionId))
                        if selected.isSuperset(of: visible) { selected.subtract(visible) } else { selected.formUnion(visible) }
                    }
                    Spacer()
                    Button("移出所选（\(selected.count)）", role: .destructive) { showRemove = true }.disabled(selected.isEmpty)
                }.padding().background(.bar)
            }
        }
        .alert("移出所选题目？", isPresented: $showRemove) {
            Button("取消", role: .cancel) { }
            Button("移出", role: .destructive) { manager.removeQuestions(selected, from: collectionID); selected = [] }
        } message: { Text("只取消合集收录，题库原题和学习记录会保留。保存的导图将失效，可重新生成。") }
        .sheet(isPresented: $showAdd) { CollectionQuestionEditorView(collectionID: collectionID) }
        .onAppear {
            // Existing study services resolve state in the active bank.
            if let bankID = collection?.bankID, bankID != manager.activeBank?.id { manager.switchBank(bankID) }
        }
    }

    private func questionLabel(_ question: QuestionData) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(question.content).lineLimit(3)
            HStack {
                Text("题号 \(question.questionId)")
                if manager.isFavorite(question.questionId) { Image(systemName: "star.fill").foregroundStyle(.orange) }
                if manager.isMastered(question.questionId) { Text("已掌握").foregroundStyle(.green) }
            }.font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct CollectionQuestionEditorView: View {
    let collectionID: UUID
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = QuestionManager.shared
    @State private var query = ""
    @State private var selected = Set<String>()
    private var collection: QuestionCollection? { manager.collections.first { $0.id == collectionID } }
    private var results: [QuestionData] {
        (manager.banks.first { $0.id == collection?.bankID }?.questions ?? []).filter {
            collection?.questionIDs.contains($0.questionId) != true &&
            (query.isEmpty || $0.content.localizedCaseInsensitiveContains(query) || $0.questionId.localizedCaseInsensitiveContains(query))
        }
    }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("全选搜索结果（\(results.count)）") { selected.formUnion(results.map(\.questionId)) }.disabled(results.isEmpty)
                    Button("取消全部选择") { selected = [] }.disabled(selected.isEmpty)
                }
                ForEach(results) { question in
                    Button { if !selected.insert(question.questionId).inserted { selected.remove(question.questionId) } } label: {
                        HStack {
                            Image(systemName: selected.contains(question.questionId) ? "checkmark.circle.fill" : "circle").foregroundStyle(.tint)
                            VStack(alignment: .leading) { Text(question.content).lineLimit(3); Text(question.questionId).font(.caption).foregroundStyle(.secondary) }
                        }.foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("添加题目")
            .searchable(text: $query, prompt: "按关键词或题号搜索")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("添加（\(selected.count)）") { manager.addQuestions(Array(selected), to: collectionID); dismiss() }.disabled(selected.isEmpty)
                }
            }
            .overlay { if results.isEmpty { ContentUnavailableView.search(text: query) } }
        }
    }
}
