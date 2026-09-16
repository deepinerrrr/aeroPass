import Foundation

@main struct StreamTransportTests {
    @MainActor static func main() async throws {
        func request(_ path: String) -> URLRequest { URLRequest(url: URL(string: "http://127.0.0.1:18764/\(path)")!) }
        var output = ""
        try await AIService.shared.receive(request: request("split")) { output += $0 }
        precondition(output == "你好航空✈️，海平面温度15℃。")
        print("PASS split UTF-8 Chinese and emoji survives actual network packets")
        precondition(!output.contains("推理")); print("PASS reasoning excluded on transport")
        var tail = ""
        try await AIService.shared.receive(request: request("eof")) { tail += $0 }
        precondition(tail == output); print("PASS EOF without newline flushes final content")
        for path in ["unauthorized", "empty", "malformed"] {
            do { try await AIService.shared.receive(request: request(path)) { _ in }; preconditionFailure(path) }
            catch { print("PASS \(path) returns actionable error") }
        }
        let slow = Task { @MainActor in
            try await AIService.shared.receive(request: request("slow")) { _ in }
        }
        try await Task.sleep(nanoseconds: 150_000_000)
        slow.cancel()
        do { try await slow.value; preconditionFailure("cancelled request completed") }
        catch { print("PASS cancellation stops request") }
        var other = ""
        try await AIService.shared.receive(request: request("split")) { other += $0 }
        precondition(other == output); print("PASS cancellation does not affect another request")
        print("RESULT 8 transport checks passed")
    }
}
