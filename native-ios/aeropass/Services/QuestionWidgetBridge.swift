import Foundation
import WidgetKit

struct WidgetQuestionSnapshot: Codable {
    let bankID: String
    let questionID: String
    let content: String
    let kind: String
}

enum QuestionWidgetBridge {
    static let groupID = "group.langlai.aeropass"
    static let storageKey = "widgetQuestions.v1"
    static let widgetKind = "AeropassQuestionWidget"

    static func publish(banks: [QuestionBank], defaults: UserDefaults) {
        guard let sharedDefaults = UserDefaults(suiteName: groupID) else { return }
        let candidates = banks.flatMap { bank in
            let favorites = Set(defaults.stringArray(forKey: "qm_favorites_\(bank.id.uuidString)") ?? [])
            let wrong = Set(defaults.stringArray(forKey: "qm_wrong_\(bank.id.uuidString)") ?? [])
            return bank.questions.compactMap { question -> WidgetQuestionSnapshot? in
                let isFavorite = favorites.contains(question.questionId)
                let isWrong = wrong.contains(question.questionId)
                guard isFavorite || isWrong else { return nil }
                let kind = isFavorite && isWrong ? "收藏 · 错题" : (isFavorite ? "收藏" : "错题")
                return WidgetQuestionSnapshot(bankID: bank.id.uuidString, questionID: question.questionId,
                                              content: question.content, kind: kind)
            }
        }
        if let data = try? JSONEncoder().encode(candidates) {
            guard sharedDefaults.data(forKey: storageKey) != data else { return }
            sharedDefaults.set(data, forKey: storageKey)
            WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        }
    }
}
