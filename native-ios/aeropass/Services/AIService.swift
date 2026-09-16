import Foundation

enum AIProvider: String, CaseIterable, Identifiable {
    case qwen
    case deepseek

    var id: String { rawValue }
    var name: String { self == .qwen ? "Qwen" : "DeepSeek" }
    var keychainKey: String { "\(rawValue)_api_key" }
    var baseURL: URL {
        switch self {
        case .qwen: return URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions")!
        case .deepseek: return URL(string: "https://api.deepseek.com/chat/completions")!
        }
    }
    var model: String {
        switch self {
        case .qwen: return UserDefaults.standard.string(forKey: "qwenModelName") ?? "qwen3.6-flash"
        case .deepseek: return UserDefaults.standard.string(forKey: "deepseekModelName") ?? "deepseek-v4-flash"
        }
    }
    var applicationURL: URL {
        switch self {
        case .qwen: return URL(string: "https://bailian.console.aliyun.com/?tab=model#/api-key")!
        case .deepseek: return URL(string: "https://platform.deepseek.com/api_keys")!
        }
    }
}

/// Each caller owns its Task; cancelling chat never cancels a mind-map request.
@MainActor
protocol AIResponding {
    func respond(messages: [[String: String]], provider: AIProvider, onContent: @MainActor (String) -> Void) async throws
}

@MainActor
struct AIService: AIResponding {
    static let shared = AIService()

    static var selectedProvider: AIProvider {
        AIProvider(rawValue: UserDefaults.standard.string(forKey: "currentAIModel") ?? "qwen") ?? .qwen
    }

    static func requestBody(messages: [[String: String]], provider: AIProvider) -> [String: Any] {
        var finalMessages = messages
        if finalMessages.first?["role"] != "system" {
            let configured = UserDefaults.standard.string(forKey: "aiSystemPrompt")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            finalMessages.insert(["role": "system", "content": configured.isEmpty
                ? "你是航空执照考试的专业辅导老师。请用 Markdown 给出题目解析、知识拓展与通俗解释，尊重参考答案，不得杜撰。不要输出思考过程，直接给出答案。"
                : configured + "\n不要输出思考过程，直接给出答案。"], at: 0)
        }
        var body: [String: Any] = [
            "model": provider.model, "messages": finalMessages, "stream": true,
            "temperature": min(1.5, max(0, UserDefaults.standard.object(forKey: "aiTemperature") as? Double ?? 0.7)),
            "max_tokens": min(8192, max(256, UserDefaults.standard.object(forKey: "aiMaxTokens") as? Int ?? 2000))
        ]
        switch provider {
        case .qwen: body["enable_thinking"] = false
        case .deepseek: body["thinking"] = ["type": "disabled"]
        }
        return body
    }

    func respond(messages: [[String: String]], provider: AIProvider,
                 onContent: @MainActor (String) -> Void) async throws {
        var key = KeychainStore.string(for: provider.keychainKey)
        if provider == .qwen, key.isEmpty,
           let legacy = UserDefaults.standard.string(forKey: "customApiKey"), !legacy.isEmpty {
            if KeychainStore.set(legacy, for: provider.keychainKey) {
                UserDefaults.standard.removeObject(forKey: "customApiKey")
            }
            key = legacy
        }
        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIStreamError.message("请先在设置中配置 \(provider.name) API Key")
        }
        var request = URLRequest(url: provider.baseURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 300
        request.httpBody = try JSONSerialization.data(withJSONObject: Self.requestBody(messages: messages, provider: provider))
        try await receive(request: request, onContent: onContent)
    }

    /// The transport is independently verifiable against a local SSE fixture server.
    func receive(request: URLRequest, onContent: @MainActor (String) -> Void) async throws {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 300
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIStreamError.message("无法识别 AI 服务响应") }
        guard (200...299).contains(http.statusCode) else {
            // Avoid echoing server request dumps, which can contain credentials.
            switch http.statusCode {
            case 401, 403: throw AIStreamError.message("AI 服务鉴权失败（\(http.statusCode)），请检查当前模型的 API Key")
            case 429: throw AIStreamError.message("AI 请求过于频繁或额度不足（429），请稍后重试")
            default: throw AIStreamError.message("AI 服务请求失败（\(http.statusCode)），请检查模型配置或稍后重试")
            }
        }
        guard http.value(forHTTPHeaderField: "Content-Type")?.contains("text/event-stream") == true else {
            throw AIStreamError.message("AI 服务未返回流式响应，请检查模型配置")
        }
        var parser = AIEventParser()
        var receivedContent = false
        // Preserve empty SSE separator lines. AsyncBytes.lines drops empty lines.
        // Decode only a complete line so split UTF-8 code points cannot be lost.
        var lineBytes = Data()
        var previousWasCR = false
        for try await byte in bytes {
            try Task.checkCancellation()
            if byte == 10 && previousWasCR { previousWasCR = false; continue }
            previousWasCR = byte == 13
            guard byte == 10 || byte == 13 else {
                lineBytes.append(byte)
                guard lineBytes.count <= 2_000_000 else { throw AIStreamError.message("AI 流式数据过大，请重试") }
                continue
            }
            guard let decoded = String(data: lineBytes, encoding: .utf8) else { throw AIStreamError.message("AI 流式字符编码异常，请重试") }
            lineBytes.removeAll(keepingCapacity: true)
            let line = decoded.hasPrefix("\u{FEFF}") ? String(decoded.dropFirst()) : decoded
            if let event = try parser.consume(line) {
                switch event {
                case .content(let content): receivedContent = true; onContent(content)
                case .done:
                    guard receivedContent else { throw AIStreamError.message("AI 未返回回答，请重试") }
                    return
                }
            }
        }
        if !lineBytes.isEmpty {
            guard let line = String(data: lineBytes, encoding: .utf8) else { throw AIStreamError.message("AI 流式字符编码异常，请重试") }
            _ = try parser.consume(line)
        }
        if let event = try parser.finish(), case .content(let content) = event {
            receivedContent = true
            onContent(content)
        }
        guard receivedContent else { throw AIStreamError.message("AI 未返回回答，请重试") }
    }
}

enum AIStreamError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

/// SSE framing keeps multi-line data together and ignores reasoning_content.
struct AIEventParser {
    enum Event: Equatable { case content(String), done }
    private var dataLines: [String] = []
    mutating func consume(_ line: String) throws -> Event? {
        if line.isEmpty { return try finish() }
        guard line.hasPrefix("data:") else { return nil }
        var data = String(line.dropFirst(5))
        if data.first == " " { data.removeFirst() }
        dataLines.append(data)
        return nil
    }
    mutating func finish() throws -> Event? {
        guard !dataLines.isEmpty else { return nil }
        let text = dataLines.joined(separator: "\n")
        dataLines.removeAll()
        if text.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]" { return .done }
        guard let data = text.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIStreamError.message("AI 流式数据格式异常，请重试")
        }
        if json["error"] != nil { throw AIStreamError.message("AI 服务返回错误，请检查配置后重试") }
        guard let choices = json["choices"] as? [[String: Any]],
              let delta = choices.first?["delta"] as? [String: Any],
              let content = delta["content"] as? String, !content.isEmpty else { return nil }
        return .content(content)
    }
}
