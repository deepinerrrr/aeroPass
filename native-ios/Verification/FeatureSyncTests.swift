import Foundation

@main
struct FeatureSyncTests {
    @MainActor static func main() async throws {
        var passed = 0
        func check(_ condition: Bool, _ name: String) {
            precondition(condition, "FAILED: \(name)")
            passed += 1
            print("PASS \(name)")
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("aeropass-sync-tests-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let suite = "aeropass-sync-tests-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let history = ChatHistoryStore(url: root.appendingPathComponent("chat.json"))
        let question = QuestionData(questionId: "101", content: "标准大气海平面温度为多少？", correctAnswer: "C", optionA: "0℃", optionB: "10℃", optionC: "15℃", optionD: "25℃", sheetName: "气象")
        let judge = QuestionData(questionId: "102", content: "地球自转方向为自西向东。", correctAnswer: "A", optionA: "正确", optionB: "错误", type: "judge")
        let oldCollection = QuestionCollection(name: "旧合集", questionIDs: ["101"])
        let old = LearningSnapshot(records: ["101": StudyRecord(attempts: 2, correctCount: 1)], notes: ["101": RichNote(questionID: "101", text: "旧笔记")], collections: [oldCollection])
        let url = root.appendingPathComponent("learning.json")
        try JSONEncoder().encode(old).write(to: url)
        defaults.set(["101"], forKey: "qm_favorites")
        defaults.set(3, forKey: "memorizeLastIndex")
        let manager = QuestionManager(storageURL: url, bundledQuestions: [question, judge], defaults: defaults, chatHistory: history)
        let bankA = manager.activeBank!.id
        check(manager.isFavorite("101"), "legacy favorites migrate")
        check(manager.record(for: "101").attempts == 2, "legacy records migrate")
        check(manager.richNote(for: "101").text == "旧笔记", "legacy notes migrate")
        check(manager.collectionQuestions(oldCollection.id).count == 1, "legacy collection bank assignment")
        check(defaults.integer(forKey: "memorize_\(bankA.uuidString)") == 3, "legacy progress migrate")
        check(judge.isTrueFalse, "judge options detected")
        let collectionID = manager.createOrUpdateCollection(named: " 气象 ", questionIDs: ["101", "101", "invalid"])!
        check(manager.collectionQuestions(collectionID).count == 1, "collection IDs validate and deduplicate")
        let mergedID = manager.createOrUpdateCollection(named: "气象", questionIDs: ["102"])!
        check(mergedID == collectionID && manager.collectionQuestions(collectionID).count == 2, "same-name collection merges")
        check(!manager.renameCollection(collectionID, to: "旧合集"), "rename collision rejected")
        check(manager.renameCollection(collectionID, to: "天气"), "rename succeeds")
        check(!manager.renameCollection(collectionID, to: "  "), "empty rename rejected")
        let map = try CollectionMindMap.parse("```json\n{\"title\":\"核心知识\",\"nodes\":[{\"title\":\"标准大气\",\"children\":[\"海平面15℃\",\"易错点\",\"气温直减率\"]},{\"title\":\"答题技巧\",\"children\":[]}]}\n```", fallbackTitle: "天气")
        check(map.nodes.count == 1 && map.nodes[0].children.count == 2, "fenced JSON filters non-knowledge labels")
        do { _ = try CollectionMindMap.parse("broken", fallbackTitle: "天气"); preconditionFailure() } catch { check(true, "invalid map rejected") }
        let saved = SavedCollectionMindMap(map: map, questions: manager.collectionQuestions(collectionID), provider: .qwen)
        manager.saveMindMap(saved, for: collectionID)
        check(manager.savedMindMap(for: collectionID) != nil, "mind map persists")
        manager.removeQuestions(["102"], from: collectionID)
        check(manager.savedMindMap(for: collectionID) == nil && manager.collectionQuestions(collectionID).count == 1, "membership change invalidates cache")
        check(manager.activeBank!.questions.count == 2 && manager.isFavorite("101"), "removing membership preserves originals and state")
        manager.saveMindMap(SavedCollectionMindMap(map: map, questions: manager.collectionQuestions(collectionID), provider: .deepseek), for: collectionID)
        let reloaded = QuestionManager(storageURL: url, bundledQuestions: [question, judge], defaults: defaults, chatHistory: history)
        check(reloaded.savedMindMap(for: collectionID)?.provider == "deepseek", "mind map survives restart")
        check(manager.syncDefaultJudgeCollection(answerIsCorrect: true) != nil, "default judge collection created")
        let beforeCount = manager.collections.count
        _ = manager.syncDefaultJudgeCollection(answerIsCorrect: true)
        check(manager.collections.count == beforeCount, "judge synchronization idempotent")
        let context = CollectionMindMap.context(name: "天气", questions: [question])
        check(!context.contains("101") && context.contains("15℃"), "AI context omits question number and preserves facts")
        check((AIService.requestBody(messages: [["role": "user", "content": "测试"]], provider: .qwen)["enable_thinking"] as? Bool) == false, "Qwen thinking disabled")
        check((AIService.requestBody(messages: [], provider: .deepseek)["thinking"] as? [String: String])?["type"] == "disabled", "DeepSeek thinking disabled")
        var parser = AIEventParser()
        _ = try parser.consume(": keepalive")
        _ = try parser.consume("data: {\"choices\":[{\"delta\":{\"reasoning_content\":\"隐藏推理\"}}]}")
        check(try parser.consume("") == nil, "reasoning content excluded")
        _ = try parser.consume("data: {\"choices\":[{\"delta\":")
        _ = try parser.consume("data: {\"content\":\"你好航空✈️\"}}]}")
        if case .content(let content) = try parser.consume("") { check(content == "你好航空✈️", "multiline SSE parsed") } else { preconditionFailure() }
        _ = try parser.consume("data:[DONE]")
        if case .done = try parser.consume("") { check(true, "DONE handled once") } else { preconditionFailure() }
        check(try parser.finish() == nil, "no duplicate terminal event")
        var scopedQuestion = question; scopedQuestion.bankID = bankA
        let messages = [ChatMessage(role: .user, content: "解析", isHidden: true), ChatMessage(role: .assistant, content: "已经输出的回答", isStreaming: true)]
        history.save(messages: messages, question: scopedQuestion)
        let restored = ChatHistoryStore(url: root.appendingPathComponent("chat.json"))
        check(restored.conversation(for: scopedQuestion)?.messages.last?.isStreaming == false, "interrupted history restores as completed")
        check(restored.conversation(for: scopedQuestion)?.messages.first?.isHidden == true, "hidden question context preserved")
        manager.addBank(name: "另一题库", questions: [QuestionData(questionId: "101", content: "不同题目", correctAnswer: "A", optionA: "正确", optionB: "错误", type: "judge")])
        let bankB = manager.activeBank!.id
        check(!manager.isFavorite("101") && manager.record(for: "101").attempts == 0 && manager.richNote(for: "101").text.isEmpty, "same display ID isolated across banks")
        manager.toggleFavorite("101")
        manager.setNote("101", note: "另一题库笔记")
        manager.recordAnswer(questionID: "101", isCorrect: false)
        let collectionB = manager.createOrUpdateCollection(named: "天气", questionIDs: ["101"])!
        check(collectionB != collectionID && manager.collectionQuestions(collectionID).first?.content == question.content, "collections retain bank ownership")
        manager.clearWrongRecords()
        check(!manager.isWrong("101") && manager.record(for: "101").attempts == 1, "clear wrong tags preserves attempts")
        manager.switchBank(bankA)
        check(manager.isFavorite("101") && manager.richNote(for: "101").text == "旧笔记", "switch bank restores correct state")
        manager.deleteCollection(collectionID)
        check(manager.collectionMindMaps[collectionID.uuidString] == nil && manager.activeBank!.questions.count == 2, "delete collection clears cache only")
        var another = scopedQuestion; another.bankID = bankB
        check(restored.conversation(for: another) == nil, "AI history isolated across banks")
        let vm = AIChatViewModel(history: restored)
        vm.setup(question: scopedQuestion); vm.setup(question: scopedQuestion)
        check(vm.messages.count == 2 && !vm.isGenerating, "view reappearing does not duplicate chat or resend")
        manager.deleteBank(bankB)
        check(manager.collections.allSatisfy { $0.bankID != bankB }, "delete bank clears associated collections")
        let fixture = FixtureAIService()
        let chat = AIChatViewModel(history: restored, service: fixture)
        chat.setupForGeneralChat()
        chat.sendMessage("解释标准大气")
        chat.sendMessage("不应重复发送")
        try await Task.sleep(nanoseconds: 30_000_000)
        check(chat.isGenerating && chat.messages.last?.content == "第一段", "chat displays incremental output")
        check(fixture.callCount == 1, "duplicate send blocked while streaming")
        chat.stopGenerating()
        check(!chat.isGenerating && chat.messages.last?.content == "第一段", "stop preserves partial output")
        let stopCount = chat.messages.count
        try await Task.sleep(nanoseconds: 120_000_000)
        check(chat.messages.count == stopCount && chat.messages.last?.content == "第一段", "late cancelled callbacks ignored")
        let partial = AIChatViewModel(history: restored, service: fixture)
        partial.setupForGeneralChat()
        check(partial.messages.last?.content == "第一段" && !partial.isGenerating, "partial response survives reopening")
        fixture.fail = true
        chat.retryLastResponse()
        try await Task.sleep(nanoseconds: 130_000_000)
        check(chat.errorMessage != nil && !chat.isGenerating, "generation error permits retry")
        fixture.fail = false
        chat.retryLastResponse()
        try await Task.sleep(nanoseconds: 130_000_000)
        check(chat.errorMessage == nil && chat.messages.last?.content == "第一段第二段", "retry replaces failed response")
        check(!fixture.lastMessages.contains { $0["content"]?.contains("模拟错误") == true || $0["content"]?.isEmpty == true }, "errors and empty placeholders excluded from API history")
        let markdown = MarkdownToHTMLConverter.convert("## 解析\n\n**重点**\n\n| 选项 | 结论 |\n|---|---|\n| C | 正确 |")
        check(markdown.contains("<h2>解析</h2>"), "multiline Markdown headings rendered")
        check(markdown.contains("<table>") && markdown.contains("<strong>重点</strong>"), "Markdown tables and emphasis rendered")
        let failedQuestion = QuestionData(questionId: "failed", content: "未成功的问题", correctAnswer: "A")
        restored.save(messages: [ChatMessage(role: .user, content: "请解析", isHidden: true)], question: failedQuestion)
        let failed = AIChatViewModel(history: restored, service: fixture)
        failed.setup(question: failedQuestion)
        check(failed.errorMessage != nil && !failed.isGenerating, "failed hidden analysis reopens with retry guidance")
        let brokenURL = root.appendingPathComponent("broken-learning.json")
        let brokenData = Data("invalid snapshot".utf8)
        try brokenData.write(to: brokenURL)
        let brokenManager = QuestionManager(storageURL: brokenURL, bundledQuestions: [question], defaults: defaults, chatHistory: history)
        brokenManager.addCollection(named: "保护测试")
        check(try Data(contentsOf: brokenURL) == brokenData && brokenManager.storageError != nil, "unreadable learning snapshot never overwritten")
        let brokenChatURL = root.appendingPathComponent("broken-chat.json")
        try brokenData.write(to: brokenChatURL)
        let brokenChat = ChatHistoryStore(url: brokenChatURL)
        brokenChat.save(messages: messages, question: scopedQuestion)
        check(try Data(contentsOf: brokenChatURL) == brokenData && brokenChat.storageError != nil, "unreadable chat snapshot never overwritten")
        check(CollectionMindMap.context(name: "判断", questions: [QuestionData(questionId: "103", content: "判断事实", correctAnswer: "B", type: "judge")]).contains("错误"), "judge AI context includes semantic answer")
        manager.setNote("101", note: "可删除笔记")
        manager.deleteNote(for: "101")
        check(manager.richNote(for: "101").text.isEmpty && manager.note(for: "101") == nil && manager.activeBank!.questions.count == 2, "delete note clears legacy and rich content without deleting original")
        print("RESULT \(passed) checks passed")
    }
}

@MainActor
final class FixtureAIService: AIResponding {
    var callCount = 0
    var fail = false
    var lastMessages: [[String: String]] = []
    func respond(messages: [[String: String]], provider: AIProvider, onContent: @MainActor (String) -> Void) async throws {
        callCount += 1
        lastMessages = messages
        if fail { throw AIStreamError.message("模拟错误") }
        onContent("第一段")
        // Deliberately deliver after cancellation to exercise the generation identity guard.
        try? await Task.sleep(nanoseconds: 80_000_000)
        onContent("第二段")
    }
}
