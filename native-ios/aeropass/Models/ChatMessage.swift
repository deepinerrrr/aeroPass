import Foundation

struct ChatMessage: Identifiable, Equatable, Codable {
    var id: String = UUID().uuidString
    var role: Role
    var content: String
    var isStreaming: Bool = false
    var isHidden: Bool = false  // 系统初始化消息，不显示在对话列表中

    enum Role: String, Codable {
        case user
        case assistant
    }
}
