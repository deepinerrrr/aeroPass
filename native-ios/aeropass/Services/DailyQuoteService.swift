import Foundation
import Combine

class DailyQuoteService: ObservableObject {
    static let shared = DailyQuoteService()
    
    @Published var quote: String = ""
    @Published var isLoading: Bool = false
    
    private var apiKey: String { KeychainStore.string(for: "daily_quote_api_key") }
    private var task: URLSessionDataTask?
    
    /// 已下线的固定标语，不再出现在 App 内（含接口万一返回同样内容）
    private static let retiredPhrases = ["保持专注", "通往蓝天的阶梯"]
    private let legacyPurgeFlag = "dailyQuoteLegacyPurged"

    private init() {
        purgeLegacyQuotesIfNeeded()
    }

    /// 早期版本把固定标语写过本地缓存，这里做一次性清理，避免旧文案继续显示
    private func purgeLegacyQuotesIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: legacyPurgeFlag) else { return }
        defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("dailyQuote_") }
            .forEach { defaults.removeObject(forKey: $0) }
        defaults.set(true, forKey: legacyPurgeFlag)
        quote = ""
    }

    private func isRetired(_ text: String) -> Bool {
        Self.retiredPhrases.contains { text.contains($0) }
    }
    
    func fetchQuote() {
        guard !isLoading else { return }
        guard !apiKey.isEmpty else { return }
        isLoading = true
        
        let today = formattedToday()
        if let cached = UserDefaults.standard.string(forKey: "dailyQuote_\(today)"), !isRetired(cached) {
            DispatchQueue.main.async { [weak self] in
                self?.quote = cached
                self?.isLoading = false
            }
            return
        }
        
        var components = URLComponents(string: "https://whyta.cn/api/tx/one")!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components.url else { isLoading = false; return }
        
        task = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isLoading = false
                guard error == nil, let data = data else { return }
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let result = json["result"] as? [String: Any],
                       let word = result["word"] as? String, !word.isEmpty, !self.isRetired(word) {
                        self.quote = word
                        UserDefaults.standard.set(word, forKey: "dailyQuote_\(self.formattedToday())")
                        return
                    }
                }
            }
        }
        task?.resume()
    }
    
    func fetchRandomQuote() {
        guard !isLoading else { return }
        guard !apiKey.isEmpty else { return }
        isLoading = true
        
        var components = URLComponents(string: "https://whyta.cn/api/tx/one")!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "rand", value: "1")
        ]
        guard let url = components.url else { isLoading = false; return }
        
        task = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isLoading = false
                guard error == nil, let data = data else { return }
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let result = json["result"] as? [String: Any],
                       let word = result["word"] as? String, !word.isEmpty, !self.isRetired(word) {
                        self.quote = word
                        return
                    }
                }
            }
        }
        task?.resume()
    }
    
    private func formattedToday() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }
}
