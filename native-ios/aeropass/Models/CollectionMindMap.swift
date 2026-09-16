import Foundation

struct CollectionMindMap: Codable, Hashable {
    struct Branch: Codable, Hashable {
        var title: String
        var children: [String]
    }
    var title: String
    var nodes: [Branch]

    static func parse(_ response: String, fallbackTitle: String) throws -> CollectionMindMap {
        guard let start = response.firstIndex(of: "{"), let end = response.lastIndex(of: "}"), start < end,
              let data = String(response[start...end]).data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let nodes = json["nodes"] as? [[String: Any]] else {
            throw AIStreamError.message("AI 返回的导图格式无法识别，请重新生成")
        }
        func clean(_ value: Any?) -> String {
            guard let text = value as? String else { return "" }
            let normalized = text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
            return String(normalized.prefix(42))
        }
        func isKnowledge(_ label: String) -> Bool {
            !label.isEmpty && !["易错", "误区", "陷阱", "答题技巧", "解题技巧", "常见错误", "容易混淆", "易混淆"].contains(where: { label.contains($0) })
        }
        let branches = nodes.compactMap { node -> Branch? in
            let title = clean(node["title"])
            guard isKnowledge(title) else { return nil }
            let children = (node["children"] as? [Any] ?? []).map(clean).filter(isKnowledge)
            return Branch(title: title, children: Array(children.prefix(2)))
        }
        guard !branches.isEmpty else { throw AIStreamError.message("AI 未返回有效知识点，请重新生成") }
        let title = clean(json["title"])
        return CollectionMindMap(title: title.isEmpty ? fallbackTitle : title, nodes: Array(branches.prefix(5)))
    }

    static let systemPrompt = """
    你是执照考试题库的知识架构师。把同一合集的题目归纳为简洁的知识思维导图，只梳理核心知识点。
    只能输出一个合法 JSON 对象，不要 Markdown、解释或代码块，不要输出思考过程。格式严格为：
    {"title":"合集核心知识","nodes":[{"title":"一级知识点","children":["核心规则","必要条件或结论"]}]}
    title 不超过16字；提炼2到5个一级知识点，每个知识点最多2个简短children；合并相同知识，用短语表达，只保留定义、规则、条件、数值和结论；不要整理易错点、误区、陷阱、答题技巧或复述题目；不要引用或推断题号；不得杜撰题目中没有的信息。
    """

    static func context(name: String, questions: [QuestionData]) -> String {
        func shorten(_ text: String, _ count: Int) -> String {
            String(text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ").prefix(count))
        }
        return "合集名称：\(name)\n题目数量：\(questions.count)\n\n" + questions.map { question in
            let correct = question.options.first { $0.key == question.correctAnswer }?.text ?? (question.isTrueFalse ? (question.correctAnswer == "A" ? "正确" : "错误") : "")
            return "题型：\(question.isTrueFalse ? "判断题" : "单选题")\n题干：\(shorten(question.content, 460))\n正确答案：\(question.correctAnswer)（\(shorten(correct, 160))）\n解析：\(shorten(question.referenceAnswer ?? "", 280))\n---"
        }.joined(separator: "\n")
    }
}

struct SavedCollectionMindMap: Codable, Hashable {
    var map: CollectionMindMap
    var fingerprints: [String: String]
    var provider: String
    var generatedAt: Date

    init(map: CollectionMindMap, questions: [QuestionData], provider: AIProvider) {
        self.map = map
        fingerprints = Dictionary(questions.map { ($0.questionId, $0.studyFingerprint) }, uniquingKeysWith: { first, _ in first })
        self.provider = provider.rawValue
        generatedAt = .now
    }

    func matches(_ questions: [QuestionData]) -> Bool {
        let current = Dictionary(questions.map { ($0.questionId, $0.studyFingerprint) }, uniquingKeysWith: { first, _ in first })
        return !fingerprints.isEmpty && fingerprints.allSatisfy { current[$0.key] == $0.value }
    }
}
