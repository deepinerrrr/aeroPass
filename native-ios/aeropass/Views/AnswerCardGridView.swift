import SwiftUI

struct AnswerCardGridView: View {
    let totalCount: Int
    let currentIndex: Int
    var answeredIndices: Set<Int> = []
    var markedIndices: Set<Int> = []
    let onJump: (Int) -> Void
    
    @AppStorage("appThemeColor") private var themeColorName: String = AppTheme.blue.rawValue
    
    var themeColor: Color {
        AppTheme(rawValue: themeColorName)?.color ?? AppTheme.blue.color
    }
    
    private let columns = [
        GridItem(.adaptive(minimum: 44, maximum: 52), spacing: 8)
    ]
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                // Legend
                HStack(spacing: 16) {
                    legendItem(color: themeColor, label: "当前")
                    legendItem(color: .green.opacity(0.75), label: "已答")
                    legendItem(color: .orange.opacity(0.8), label: "标注")
                    legendItem(color: Color(UIColor.systemGray5), label: "未答")
                }
                .padding(.top, 8)
                
                // Grid
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(0..<totalCount, id: \.self) { index in
                        Button(action: { onJump(index) }) {
                            Text("\(index + 1)")
                                .font(.system(size: 14, weight: index == currentIndex ? .bold : .regular, design: .monospaced))
                                .foregroundColor(index == currentIndex ? .white : .primary)
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(backgroundColor(for: index))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(index == currentIndex ? themeColor : Color.clear, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                        .id(index)
                    }
                }
                .padding(.horizontal)
                }
                .padding(.bottom, 20)
            }
            .onAppear {
                DispatchQueue.main.async {
                    withAnimation { proxy.scrollTo(currentIndex, anchor: .center) }
                }
            }
        }
    }

    private func backgroundColor(for index: Int) -> Color {
        if index == currentIndex { return themeColor }
        if markedIndices.contains(index) { return .orange.opacity(0.8) }
        if answeredIndices.contains(index) { return .green.opacity(0.75) }
        return Color(UIColor.systemGray5)
    }
    
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 16, height: 16)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
