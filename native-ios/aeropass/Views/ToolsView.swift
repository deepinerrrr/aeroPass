import SwiftUI

struct ToolsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var qm = QuestionManager.shared
    @AppStorage("appThemeColor") private var themeColorName: String = AppTheme.blue.rawValue
    
    var themeColor: Color {
        AppTheme(rawValue: themeColorName)?.color ?? AppTheme.blue.color
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    Section("查找与归类") {
                        NavigationLink(destination: QuestionLibraryView()) {
                            toolLabel("全库搜索", "题干、题号、状态与筛选标注", "magnifyingglass", .blue)
                        }
                        NavigationLink(destination: CollectionsView()) {
                            toolLabel("我的合集", "管理题目分类与 AI 思维导图", "folder.fill", .purple)
                        }
                    }
                    Section("学习记录") {
                        NavigationLink(destination: StudyNotesView()) {
                            toolLabel("我的笔记", "查找打字、手写与混合笔记", "note.text", .teal)
                        }
                        NavigationLink(destination: AIChatHistoryView()) {
                            toolLabel("AI 对话历史", "恢复解析与继续追问", "bubble.left.and.bubble.right", .purple)
                        }
                        NavigationLink(destination: QuestionLibraryView(scope: .wrong)) {
                            toolLabel("错题本", "重点攻克薄弱环节", "xmark.circle.fill", .red)
                        }
                        NavigationLink(destination: QuestionLibraryView(scope: .favorite)) {
                            toolLabel("收藏题库", "随时复习重点题目", "star.fill", .orange)
                        }
                        NavigationLink(destination: StudyStatsView()) {
                            toolLabel("学习统计", "进度、正确率与模考趋势", "chart.xyaxis.line", .green)
                        }
                    }
                    Section("数据") {
                        NavigationLink(destination: QuestionBankManagementView()) {
                            toolLabel("题库管理", "导入、切换、筛选和删除题库", "tray.full.fill", .indigo)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color(.systemGroupedBackground))
                
                if colorScheme == .dark {
                    coneSpotlight(themeColor: themeColor, screenHeight: screenBounds().height)
                }
            }
            .navigationTitle("工具")
        }
    }

    private func toolLabel(_ title: String, _ subtitle: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 32, height: 32)
                .foregroundStyle(color)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title)).foregroundStyle(.primary)
                Text(LocalizedStringKey(subtitle)).font(.caption).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 4)
    }
}
