import SwiftUI
import WidgetKit

private struct QuestionItem: Codable {
    let bankID: String
    let questionID: String
    let content: String
    let kind: String
}

private struct QuestionEntry: TimelineEntry {
    let date: Date
    let question: QuestionItem?
}

private struct QuestionProvider: TimelineProvider {
    private let groupID = "group.langlai.aeropass"
    private let storageKey = "widgetQuestions.v1"

    func placeholder(in context: Context) -> QuestionEntry {
        QuestionEntry(date: .now, question: QuestionItem(bankID: "", questionID: "", content: "点击打开今天的练习题目", kind: "收藏 · 错题"))
    }

    func getSnapshot(in context: Context, completion: @escaping (QuestionEntry) -> Void) {
        completion(QuestionEntry(date: .now, question: readQuestions().randomElement()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuestionEntry>) -> Void) {
        let questions = readQuestions()
        let now = Date()
        let order = questions.shuffled()
        let entries = (0..<6).map { offset in
            QuestionEntry(date: Calendar.current.date(byAdding: .hour, value: offset * 2, to: now) ?? now,
                          question: order.isEmpty ? nil : order[offset % order.count])
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func readQuestions() -> [QuestionItem] {
        guard let data = UserDefaults(suiteName: groupID)?.data(forKey: storageKey),
              let questions = try? JSONDecoder().decode([QuestionItem].self, from: data) else { return [] }
        return questions
    }
}

private struct QuestionWidgetView: View {
    let entry: QuestionEntry

    private var destination: URL? {
        guard let question = entry.question, !question.bankID.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "aeropass"
        components.host = "question"
        components.queryItems = [
            URLQueryItem(name: "bank", value: question.bankID),
            URLQueryItem(name: "id", value: question.questionID)
        ]
        return components.url
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: "airplane.circle.fill")
                    .foregroundStyle(.blue)
                Text("aeroPass")
                    .font(.caption.weight(.bold))
                Spacer()
                if let question = entry.question {
                    Text(LocalizedStringKey(question.kind))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            if let question = entry.question {
                Text(question.content)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                HStack {
                    Text("题号 \(question.questionID)")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    Text("收藏一道题或完成一道错题")
                        .font(.subheadline.weight(.semibold))
                    Text("题目会显示在这里")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
        .padding(15)
        .containerBackground(.background, for: .widget)
        .widgetURL(destination)
    }
}

@main
struct AeropassQuestionWidget: Widget {
    let kind = "AeropassQuestionWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuestionProvider()) { entry in
            QuestionWidgetView(entry: entry)
        }
        .configurationDisplayName("收藏与错题")
        .description("随机复习一道收藏或错题，点击直达题目卡片。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
