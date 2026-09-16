import Charts
import Combine
import PencilKit
import SwiftUI
import UniformTypeIdentifiers

struct QuestionBankManagementView: View {
    @StateObject private var manager = QuestionManager.shared
    @State private var isImporterPresented = false
    @State private var pendingURL: URL?
    @State private var bankName = ""
    @State private var isNamingBank = false
    @State private var isImporting = false
    @State private var importMessage: String?
    @State private var bankToDelete: QuestionBank?

    @AppStorage("appThemeColor") private var themeColorName: String = AppTheme.blue.rawValue

    private var themeColor: Color {
        AppTheme(rawValue: themeColorName)?.color ?? AppTheme.blue.color
    }

    private var importResultPresented: Binding<Bool> {
        Binding(get: { importMessage != nil }, set: { if !$0 { importMessage = nil } })
    }

    private var deletePresented: Binding<Bool> {
        Binding(get: { bankToDelete != nil }, set: { if !$0 { bankToDelete = nil } })
    }

    var body: some View {
        bankList
            .navigationTitle("题库管理")
            .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [UTType(filenameExtension: "xlsx") ?? .data], onCompletion: handleFileResult)
            .alert("题库名称", isPresented: $isNamingBank) {
                TextField("例如：新版执照题库", text: $bankName)
                Button("取消", role: .cancel) { pendingURL = nil }
                Button("导入") { importPendingWorkbook() }
            } message: {
                Text("导入完成后会自动切换到新题库。")
            }
            .alert("导入结果", isPresented: importResultPresented) {
                Button("好") { importMessage = nil }
            } message: { Text(importMessage ?? "") }
            .alert("删除题库？", isPresented: deletePresented, presenting: bankToDelete) { bank in
                Button("取消", role: .cancel) { bankToDelete = nil }
                Button("删除", role: .destructive) { manager.deleteBank(bank.id); bankToDelete = nil }
            } message: { bank in
                Text("将删除“\(bank.name)”及其中的导入题目。")
            }
    }

    private var bankList: some View {
        List {
            Section {
                Button { isImporterPresented = true } label: {
                    Label("从 Excel 导入题库", systemImage: "square.and.arrow.down")
                }
                .disabled(isImporting)
                if isImporting {
                    HStack { ProgressView(); Text("正在解析工作簿…") }
                }
            } footer: {
                Text("支持 .xlsx。A 列题干、B 列答案、C 列题号，D–G 列依次为选项 A–D；D、E 必填。答案填写 A/B/C/D 或正确/错误，题号必须唯一。例：标准海平面温度？｜C｜101｜0℃｜10℃｜15℃｜25℃。判断题：地球自转方向为自西向东。｜A｜102｜正确｜错误。所有行校验通过后才导入，每个工作表保留为分类。")
            }

            Section("高级筛选") {
                Toggle("隐藏“正确答案为唯一最长选项”的题目", isOn: $manager.autoFilterLongestAnswer)
                LabeledContent("当前题库", value: "\(manager.activeBank?.questionCount ?? 0) 题")
                LabeledContent("符合筛选特征", value: "\(manager.longestAnswerCount) 题")
                LabeledContent("实际学习题量", value: "\(manager.totalCount) 题")
            }

            Section {
                NavigationLink {
                    HiddenMasteredQuestionsView(themeColor: themeColor)
                } label: {
                    HStack {
                        Label("已掌握（已隐藏）题目", systemImage: "checkmark.seal.fill")
                        Spacer()
                        Text("\(manager.masteredIds.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("已掌握题目")
            } footer: {
                Text("标记“已掌握”的题目会从刷题与背题中暂时隐藏，可在这里重新显示。")
            }

            Section("题库") {
                ForEach(manager.banks) { bank in
                    HStack(spacing: 12) {
                        Image(systemName: bank.isActive ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(bank.isActive ? .accentColor : .secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(bank.name).foregroundStyle(.primary)
                            Text("\(bank.questionCount) 题 · \(bank.sheetNames.count) 个分类 · \(bank.source)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { manager.switchBank(bank.id) }
                    .swipeActions {
                        if bank.source != "内置" {
                            Button("删除", role: .destructive) { bankToDelete = bank }
                        }
                    }
                }
            }
        }
    }

    private func handleFileResult(_ result: Result<URL, Error>) {
        if case .success(let url) = result {
            pendingURL = url
            bankName = url.deletingPathExtension().lastPathComponent
            isNamingBank = true
        }
    }

    private func importPendingWorkbook() {
        guard let url = pendingURL else { return }
        let name = bankName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        isImporting = true
        Task {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                let questions = try ExcelQuestionImporter().parse(url: url)
                await MainActor.run {
                    manager.addBank(name: name, questions: questions)
                    importMessage = "成功导入 \(questions.count) 道题目"
                }
            } catch {
                await MainActor.run { importMessage = error.localizedDescription }
            }
            await MainActor.run { isImporting = false; pendingURL = nil }
        }
    }
}

struct StudyStatsView: View {
    @StateObject private var manager = QuestionManager.shared

    private var practiced: Int { manager.records.values.filter { $0.attempts > 0 }.count }
    private var correct: Int { manager.records.values.reduce(0) { $0 + $1.correctCount } }
    private var attempts: Int { manager.records.values.reduce(0) { $0 + $1.attempts } }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow {
                        statCard("已练", value: practiced, icon: "checkmark.circle", color: .blue)
                        statCard("错题", value: manager.wrongIds.count, icon: "xmark.circle", color: .red)
                    }
                    GridRow {
                        statCard("已掌握", value: manager.masteredIds.count, icon: "brain", color: .green)
                        statCard("收藏", value: manager.favoriteIds.count, icon: "star", color: .orange)
                    }
                }

                GroupBox("学习进度") {
                    VStack(spacing: 14) {
                        progressRow("题库完成度", value: manager.totalCount == 0 ? 0 : Double(practiced) / Double(manager.totalCount))
                        progressRow("累计正确率", value: attempts == 0 ? 0 : Double(correct) / Double(attempts))
                        progressRow("掌握率", value: manager.totalCount == 0 ? 0 : Double(manager.masteredIds.count) / Double(manager.totalCount))
                    }.padding(.top, 8)
                }

                GroupBox("模拟考试趋势") {
                    if manager.examRecords.isEmpty {
                        ContentUnavailableView("暂无考试记录", systemImage: "chart.xyaxis.line")
                            .frame(height: 180)
                    } else {
                        Chart(manager.examRecords.suffix(12)) { item in
                            LineMark(x: .value("日期", item.date), y: .value("分数", item.score))
                            PointMark(x: .value("日期", item.date), y: .value("分数", item.score))
                        }
                        .chartYScale(domain: 0...100)
                        .frame(height: 210)
                        .padding(.top, 8)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("学习统计")
    }

    private func statCard(_ title: String, value: Int, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).foregroundStyle(color).font(.title2)
            Text("\(value)").font(.title.bold())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private func progressRow(_ title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { Text(title); Spacer(); Text(value, format: .percent.precision(.fractionLength(0))).foregroundStyle(.secondary) }
            ProgressView(value: value)
        }
    }
}

struct QuestionLibraryView: View {
    enum Scope: String, CaseIterable { case all = "全部", wrong = "错题", favorite = "收藏", mastered = "掌握", filtered = "被筛选" }
    @StateObject private var manager = QuestionManager.shared
    @State private var query = ""
    @State private var scope: Scope
    @State private var showClearWrong = false

    init(scope: Scope = .all) { _scope = State(initialValue: scope) }

    private var results: [QuestionData] {
        let source = manager.activeBank?.questions ?? manager.getAllQuestions()
        return source.filter { question in
            let scopeMatch: Bool
            switch scope {
            case .all: scopeMatch = true
            case .wrong: scopeMatch = manager.isWrong(question.questionId)
            case .favorite: scopeMatch = manager.isFavorite(question.questionId)
            case .mastered: scopeMatch = manager.isMastered(question.questionId)
            case .filtered: scopeMatch = manager.isCorrectAnswerLongest(question)
            }
            return scopeMatch && (query.isEmpty || question.content.localizedCaseInsensitiveContains(query) || question.questionId.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        List(results) { question in
            NavigationLink { QuestionDetailNativeView(question: question) } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(question.content).lineLimit(2)
                    HStack {
                        Text("题号 \(question.questionId)")
                        if let sheet = question.sheetName { Text(sheet) }
                        if manager.isWrong(question.questionId) { Label("错题", systemImage: "xmark.circle.fill").foregroundStyle(.red) }
                        if manager.isFavorite(question.questionId) { Image(systemName: "star.fill").foregroundStyle(.yellow) }
                    }.font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(scope == .wrong ? "错题本" : scope == .favorite ? "收藏题库" : "题目搜索")
        .toolbar {
            if scope == .wrong { ToolbarItem(placement: .topBarTrailing) { Button("清空错题") { showClearWrong = true }.disabled(manager.wrongIds.isEmpty) } }
        }
        .alert("清空错题标记？", isPresented: $showClearWrong) {
            Button("取消", role: .cancel) { }
            Button("清空", role: .destructive) { manager.clearWrongRecords() }
        } message: { Text("清空当前题库的错题标记，练习次数和正确率记录会保留。") }
        .searchable(text: $query, prompt: "搜索题干或题号")
        .searchScopes($scope) { ForEach(Scope.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
        .overlay { if results.isEmpty { ContentUnavailableView.search(text: query) } }
    }
}

struct QuestionDetailNativeView: View {
    let question: QuestionData
    @StateObject private var manager = QuestionManager.shared
    @State private var showNote = false
    @State private var showCollections = false
    @State private var showAIChat = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(question.content).font(.title3.weight(.semibold))
                ForEach(question.options, id: \.key) { option in
                    Label { Text(option.text) } icon: {
                        Image(systemName: option.key == question.correctAnswer ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(option.key == question.correctAnswer ? .green : .secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(option.key == question.correctAnswer ? Color.green.opacity(0.1) : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }
                if question.isTrueFalse {
                    Label("正确答案：\(question.correctAnswer == "A" ? "正确" : "错误")", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                }
                Button { showAIChat = true } label: { Label("AI 解析与答疑", systemImage: "sparkles") }
                    .buttonStyle(.borderedProminent)
                if let reference = question.referenceAnswer, !reference.isEmpty {
                    GroupBox("参考解析") { Text(reference).frame(maxWidth: .infinity, alignment: .leading) }
                }
            }.padding()
        }
        .navigationTitle("题目 \(question.questionId)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { manager.toggleFavorite(question.questionId) } label: { Image(systemName: manager.isFavorite(question.questionId) ? "star.fill" : "star") }
                Button { showCollections = true } label: { Image(systemName: "folder.badge.plus") }
                Button { showNote = true } label: { Image(systemName: "note.text.badge.plus") }
            }
        }
        .sheet(isPresented: $showAIChat) { AIChatView(question: question) }
        .sheet(isPresented: $showNote) { RichNoteEditorView(question: question) }
        .sheet(isPresented: $showCollections) { CollectionPickerView(questionID: question.questionId) }
    }
}

struct CollectionPickerView: View {
    let questionID: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = QuestionManager.shared
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("新建集合", text: $newName)
                        Button("添加") { manager.addCollection(named: newName, questionIDs: [questionID]); newName = "" }
                            .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                Section("选择集合") {
                    ForEach(manager.collections.filter { $0.bankID == manager.activeBank?.id }) { collection in
                        Button { manager.toggleQuestion(questionID, in: collection.id) } label: {
                            HStack {
                                Text(collection.name).foregroundStyle(.primary)
                                Spacer()
                                if collection.questionIDs.contains(questionID) { Image(systemName: "checkmark").foregroundStyle(.tint) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("搜索归类")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}

struct RelatedQuestionOrganizerView: View {
    let anchorQuestion: QuestionData
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = QuestionManager.shared
    @State private var query = ""
    @State private var selection = Set<String>()
    @State private var newCollectionName = ""
    @State private var selectedCollectionID: UUID?

    private var matches: [QuestionData] {
        let candidates = (manager.activeBank?.questions ?? []).filter { $0.questionId != anchorQuestion.questionId }
        guard !query.isEmpty else { return Array(candidates.prefix(40)) }
        return candidates.filter { $0.content.localizedCaseInsensitiveContains(query) || $0.questionId.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("当前题目") {
                    Text(anchorQuestion.content).lineLimit(3)
                    Text("题号 \(anchorQuestion.questionId)").font(.caption).foregroundStyle(.secondary)
                }
                Section("归类到") {
                    Picker("已有集合", selection: $selectedCollectionID) {
                        Text("仅保存为关联题").tag(UUID?.none)
                        ForEach(manager.collections.filter { $0.bankID == manager.activeBank?.id }) { Text($0.name).tag(Optional($0.id)) }
                    }
                    if selectedCollectionID == nil {
                        TextField("可选：同时新建集合", text: $newCollectionName)
                    }
                }
                Section("关联题目（已选 \(selection.count)）") {
                    ForEach(matches) { question in
                        Button { toggle(question.questionId) } label: {
                            HStack(alignment: .top) {
                                Image(systemName: selection.contains(question.questionId) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selection.contains(question.questionId) ? .accentColor : .secondary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(question.content).lineLimit(2).foregroundStyle(.primary)
                                    Text(question.questionId).font(.caption.monospaced()).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "搜索题干或题号")
            .navigationTitle("搜索并归类")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") { commit(); dismiss() }
                        .disabled(selection.count <= 1)
                }
            }
        }
        .onAppear {
            selection = Set(manager.relatedQuestionIDs[anchorQuestion.questionId] ?? [])
            selection.insert(anchorQuestion.questionId)
        }
    }

    private func toggle(_ id: String) {
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }

    private func commit() {
        manager.saveRelatedQuestions(
            Array(selection.filter { $0 != anchorQuestion.questionId }),
            for: anchorQuestion.questionId
        )
        if let id = selectedCollectionID {
            for questionID in selection {
                guard manager.collections.first(where: { $0.id == id })?.questionIDs.contains(questionID) != true else { continue }
                manager.toggleQuestion(questionID, in: id)
            }
        } else if !newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            manager.addCollection(named: newCollectionName, questionIDs: Array(selection))
        }
    }
}

struct RichNoteEditorView: View {
    let question: QuestionData
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = QuestionManager.shared
    @State private var note: RichNote
    @StateObject private var drawingController = PencilCanvasController()
    @State private var showClearDrawing = false
    @State private var showDeleteNote = false

    init(question: QuestionData) {
        self.question = question
        _note = State(initialValue: QuestionManager.shared.richNote(for: question.questionId))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("笔记方式", selection: $note.mode) {
                    ForEach(NoteMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding()

                if note.mode != .handwriting {
                    TextEditor(text: $note.text)
                        .padding(10)
                        .frame(minHeight: note.mode == .mixed ? 180 : 360)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal)
                }
                if note.mode != .typing {
                    HStack {
                        Button("撤销上一笔") { drawingController.undo() }.disabled(!drawingController.canUndo)
                        Spacer()
                        Button("清空手写", role: .destructive) { showClearDrawing = true }.disabled(!drawingController.hasDrawing)
                    }.font(.callout).padding(.horizontal)
                    PencilCanvas(drawingData: $note.drawingData, controller: drawingController)
                        .frame(minHeight: note.mode == .mixed ? 260 : 500)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.separator))
                        .padding()
                }
                if let error = manager.storageError { Text(error).font(.caption).foregroundStyle(.red).padding() }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("题目笔记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .bottomBar) { Button("删除笔记", role: .destructive) { showDeleteNote = true } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { drawingController.syncDrawing(); manager.saveRichNote(note); if manager.storageError == nil { dismiss() } }.bold() }
            }
            .alert("清空手写笔记？", isPresented: $showClearDrawing) {
                Button("取消", role: .cancel) { }
                Button("清空", role: .destructive) { drawingController.clear() }
            } message: { Text("文字笔记会保留，点击保存后生效。") }
            .alert("删除笔记？", isPresented: $showDeleteNote) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) { manager.deleteNote(for: question.questionId); if manager.storageError == nil { dismiss() } }
            } message: { Text("将删除这道题的文字和手写笔记，原题与涂画标注会保留。") }
        }
    }
}

@MainActor
final class PencilCanvasController: ObservableObject {
    @Published private(set) var canUndo = false
    @Published private(set) var hasDrawing = false

    fileprivate weak var canvas: PKCanvasView?
    fileprivate var publishDrawing: ((Data) -> Void)?

    fileprivate func attach(_ canvas: PKCanvasView, publishDrawing: @escaping (Data) -> Void) {
        self.canvas = canvas
        self.publishDrawing = publishDrawing
        refreshState(from: canvas)
    }

    func undo() {
        guard let canvas, canvas.undoManager?.canUndo == true else { return }
        canvas.undoManager?.undo()
        publishCurrentDrawing(from: canvas)
    }

    func clear() {
        guard let canvas else { return }
        canvas.drawing = PKDrawing()
        canvas.undoManager?.removeAllActions()
        publishCurrentDrawing(from: canvas)
    }

    func syncDrawing() {
        guard let canvas else { return }
        publishCurrentDrawing(from: canvas)
    }

    fileprivate func publishCurrentDrawing(from canvas: PKCanvasView) {
        let data = canvas.drawing.strokes.isEmpty ? Data() : canvas.drawing.dataRepresentation()
        publishDrawing?(data)
        refreshState(from: canvas)
    }

    fileprivate func refreshState(from canvas: PKCanvasView) {
        canUndo = canvas.undoManager?.canUndo == true
        hasDrawing = !canvas.drawing.strokes.isEmpty
    }
}

struct PencilCanvas: UIViewRepresentable {
    @Binding var drawingData: Data
    var isInteractive = true
    var controller: PencilCanvasController?

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.drawingPolicy = .anyInput
        canvas.isOpaque = false
        canvas.backgroundColor = .clear
        canvas.isUserInteractionEnabled = isInteractive
        if drawingData.isEmpty {
            canvas.drawing = PKDrawing()
        } else if let drawing = try? PKDrawing(data: drawingData) {
            canvas.drawing = drawing
        }
        context.coordinator.canvas = canvas
        controller?.attach(canvas) { data in
            context.coordinator.updateDrawingData(data)
        }
        DispatchQueue.main.async {
            let picker = PKToolPicker()
            picker.setVisible(isInteractive, forFirstResponder: canvas)
            picker.addObserver(canvas)
            if isInteractive { canvas.becomeFirstResponder() }
            context.coordinator.toolPicker = picker
        }
        return canvas
    }
    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        canvas.isUserInteractionEnabled = isInteractive
        controller?.attach(canvas) { data in
            context.coordinator.updateDrawingData(data)
        }

        let currentData = canvas.drawing.strokes.isEmpty ? Data() : canvas.drawing.dataRepresentation()
        if currentData != drawingData {
            if drawingData.isEmpty {
                canvas.drawing = PKDrawing()
            } else if let drawing = try? PKDrawing(data: drawingData) {
                canvas.drawing = drawing
            }
            // 切换题目属于程序化载入，上一题的笔迹不应留在撤销栈里
            canvas.undoManager?.removeAllActions()
        }

        if isInteractive {
            context.coordinator.toolPicker?.setVisible(true, forFirstResponder: canvas)
            if !canvas.isFirstResponder { canvas.becomeFirstResponder() }
        } else {
            context.coordinator.toolPicker?.setVisible(false, forFirstResponder: canvas)
            if canvas.isFirstResponder { canvas.resignFirstResponder() }
        }
        controller?.refreshState(from: canvas)
    }

    static func dismantleUIView(_ canvas: PKCanvasView, coordinator: Coordinator) {
        coordinator.toolPicker?.setVisible(false, forFirstResponder: canvas)
        coordinator.toolPicker?.removeObserver(canvas)
        coordinator.toolPicker = nil
        if canvas.isFirstResponder { canvas.resignFirstResponder() }
        canvas.isUserInteractionEnabled = false
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PencilCanvas
        weak var canvas: PKCanvasView?
        var toolPicker: PKToolPicker?
        init(parent: PencilCanvas) { self.parent = parent }
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let data = canvasView.drawing.strokes.isEmpty ? Data() : canvasView.drawing.dataRepresentation()
            updateDrawingData(data)
            parent.controller?.refreshState(from: canvasView)
        }

        func updateDrawingData(_ data: Data) {
            guard parent.drawingData != data else { return }
            parent.drawingData = data
        }
    }
}
