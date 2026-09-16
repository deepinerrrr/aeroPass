import SwiftUI

struct QuestionCardView: View {
    let question: QuestionData
    let showAnswer: Bool
    let selectedOption: String?
    let onOptionSelected: ((String) -> Void)?
    var allowsCollectionSearch = true
    
    @AppStorage("appThemeColor") private var themeColorName: String = AppTheme.blue.rawValue
    @StateObject private var qm = QuestionManager.shared
    @State private var selectedSearchText: SearchSelection?
    
    var themeColor: Color {
        AppTheme(rawValue: themeColorName)?.color ?? AppTheme.blue.color
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            questionHeader
            
            // 2. 选项列表
            if question.isTrueFalse {
                VStack(spacing: 12) {
                    OptionRow(text: "正确", value: "正确", correctAnswer: question.correctAnswer, showAnswer: showAnswer, selectedOption: selectedOption, themeColor: themeColor, action: onOptionSelected)
                    OptionRow(text: "错误", value: "错误", correctAnswer: question.correctAnswer, showAnswer: showAnswer, selectedOption: selectedOption, themeColor: themeColor, action: onOptionSelected)
                }
            } else {
                VStack(spacing: 12) {
                    if let a = question.optionA { OptionRow(text: "A. \(a)", value: "A", correctAnswer: question.correctAnswer, showAnswer: showAnswer, selectedOption: selectedOption, themeColor: themeColor, action: onOptionSelected) }
                    if let b = question.optionB { OptionRow(text: "B. \(b)", value: "B", correctAnswer: question.correctAnswer, showAnswer: showAnswer, selectedOption: selectedOption, themeColor: themeColor, action: onOptionSelected) }
                    if let c = question.optionC { OptionRow(text: "C. \(c)", value: "C", correctAnswer: question.correctAnswer, showAnswer: showAnswer, selectedOption: selectedOption, themeColor: themeColor, action: onOptionSelected) }
                    if let d = question.optionD { OptionRow(text: "D. \(d)", value: "D", correctAnswer: question.correctAnswer, showAnswer: showAnswer, selectedOption: selectedOption, themeColor: themeColor, action: onOptionSelected) }
                }
            }
        }
        .padding(22)
        .background {
            QuestionCardBackground(
                isFavorite: qm.isFavorite(question.questionId),
                cornerRadius: 24
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 15, x: 0, y: 6)
        .animation(.spring(response: 0.32, dampingFraction: 0.6), value: qm.isFavorite(question.questionId))
        .sheet(item: $selectedSearchText) { selection in
            QuestionCollectionSearchSheet(initialQuery: selection.value, themeColor: themeColor)
        }
    }

    @ViewBuilder
    private var questionHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                questionTypeBadge
                Spacer(minLength: 8)
                statusIcons
                if allowsCollectionSearch {
                    QuestionCollectionSearchControl(themeColor: themeColor)
                }
            }
            questionText
        }
        .padding(.bottom, 6)
    }

    private var questionTypeBadge: some View {
        Text(question.isTrueFalse ? "判断题" : "单选题")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(question.isTrueFalse ? Color.green.gradient : themeColor.gradient)
            .cornerRadius(6)
            .shadow(color: (question.isTrueFalse ? Color.green : themeColor).opacity(0.2), radius: 4)
    }

    private var questionText: some View {
        Group {
            if allowsCollectionSearch {
                SelectableQuestionText(text: question.content, font: .preferredFont(forTextStyle: .headline)) {
                    selectedSearchText = SearchSelection(value: $0)
                }
            } else {
                Text(question.content)
                    .font(.headline)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var statusIcons: some View {
        HStack(spacing: 8) {
            if let note = qm.note(for: question.questionId), !note.isEmpty {
                Image(systemName: "note.text")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
                    .shadow(color: .orange.opacity(0.3), radius: 3)
            }

            if qm.isFavorite(question.questionId) {
                Image(systemName: "star.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.yellow)
                    .shadow(color: .yellow.opacity(0.5), radius: 4)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel("已收藏")
            }
        }
    }
}

/// 一道题固定占满一个翻页视口：短卡片严格居中，长卡片从顶部开始并可完整滚动。
struct CenteredScrollableQuestionPage<Content: View>: View {
    var scrollingEnabled = true
    let content: Content

    init(scrollingEnabled: Bool = true, @ViewBuilder content: () -> Content) {
        self.scrollingEnabled = scrollingEnabled
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                content
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .frame(minHeight: geometry.size.height, alignment: .center)
            }
            .scrollDisabled(!scrollingEnabled)
        }
    }
}

/// 背题和刷题共用的收藏卡片底色。收藏后只在右上角给出轻柔黄光，
/// 保留正文区域的系统背景与对比度。
struct QuestionCardBackground: View {
    let isFavorite: Bool
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
            .overlay {
                if isFavorite {
                    RadialGradient(
                        colors: [
                            Color.yellow.opacity(0.24),
                            Color.yellow.opacity(0.10),
                            Color.yellow.opacity(0)
                        ],
                        center: .topTrailing,
                        startRadius: 0,
                        endRadius: 210
                    )
                }
            }
    }
}

// MARK: - 精致选项按钮行
struct OptionRow: View {
    let text: String
    let value: String
    let correctAnswer: String
    let showAnswer: Bool
    let selectedOption: String?
    let themeColor: Color
    let action: ((String) -> Void)?
    
    var body: some View {
        Button(action: {
            action?(value)
        }) {
            HStack(alignment: .top, spacing: 12) {
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)
                
                // 答案揭晓时的对错图标
                if showAnswer {
                    if isCorrect {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.green)
                            .padding(.top, 1)
                            .transition(.scale.combined(with: .opacity))
                    } else if isSelected {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.red)
                            .padding(.top, 1)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(backgroundColor)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(borderColor, lineWidth: 1.5)
            )
        }
        .disabled(showAnswer)
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showAnswer)
    }
    
    private var isCorrect: Bool { value == correctAnswer }
    private var isSelected: Bool { value == selectedOption }
    
    // 背景色的高保真视觉渲染，融入主题色调
    private var backgroundColor: Color {
        guard showAnswer else {
            return isSelected ? themeColor.opacity(0.08) : Color(.systemGray6).opacity(0.6)
        }
        if isCorrect { return Color.green.opacity(0.1) }
        if isSelected && !isCorrect { return Color.red.opacity(0.1) }
        return Color(.systemGray6).opacity(0.4)
    }
    
    // 边框色彩控制
    private var borderColor: Color {
        guard showAnswer else {
            return isSelected ? themeColor.opacity(0.4) : Color.clear
        }
        if isCorrect { return Color.green.opacity(0.6) }
        if isSelected && !isCorrect { return Color.red.opacity(0.6) }
        return Color.clear
    }
    
    // 文本颜色
    private var textColor: Color {
        guard showAnswer else {
            return isSelected ? themeColor : .primary
        }
        if isCorrect { return .green }
        if isSelected && !isCorrect { return .red }
        return .secondary
    }
}
