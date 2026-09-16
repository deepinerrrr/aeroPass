import SwiftUI

struct ContentView: View {
    @StateObject private var qm = QuestionManager.shared
    @State private var widgetDestination: WidgetQuestionDestination?
    @AppStorage("appThemeColor") private var appThemeRawValue: String = AppTheme.blue.rawValue
    @AppStorage("appAppearance") private var appAppearance: String = "system"
    
    var themeColor: Color {
        AppTheme(rawValue: appThemeRawValue)?.color ?? AppTheme.blue.color
    }
    
    var preferredColorScheme: ColorScheme? {
        switch appAppearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
    
    var body: some View {
        Group {
            if qm.isLoading {
                importView
            } else {
                mainTabView
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .onOpenURL(perform: openWidgetQuestion)
        .sheet(item: $widgetDestination) { destination in
            WidgetQuestionDetail(question: destination.question)
        }
    }

    private func openWidgetQuestion(_ url: URL) {
        guard url.scheme == "aeropass", url.host == "question",
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let bankText = parts.queryItems?.first(where: { $0.name == "bank" })?.value,
              let bankID = UUID(uuidString: bankText),
              let questionID = parts.queryItems?.first(where: { $0.name == "id" })?.value,
              let bank = qm.banks.first(where: { $0.id == bankID }),
              let question = bank.questions.first(where: { $0.questionId == questionID }) else { return }
        if qm.activeBank?.id != bankID { qm.switchBank(bankID) }
        widgetDestination = WidgetQuestionDestination(question: question)
    }
    
    private var importView: some View {
        VStack(spacing: 20) {
            Image(systemName: "airplane.circle.fill")
                .resizable()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
            
            Text("Aeropass 航空执照题库")
                .font(.title)
                .bold()
            
            ProgressView().padding()
            Text("加载题库中...")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
    
    private var mainTabView: some View {
        TabView {
            HomeView()
                .tabItem { Label("首页", systemImage: "house.fill") }
            ToolsView()
                .tabItem { Label("工具", systemImage: "briefcase.fill") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
        }
        .tint(themeColor)
        .onAppear {
            print("✅ 应用已加载，当前题库: \(qm.totalCount) 道题")
        }
    }
}

private struct WidgetQuestionDestination: Identifiable {
    let id = UUID()
    let question: QuestionData
}

private struct WidgetQuestionDetail: View {
    let question: QuestionData
    @Environment(\.dismiss) private var dismiss
    @State private var showAnswer = false
    @State private var selectedOption: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                QuestionCardView(question: question, showAnswer: showAnswer,
                                 selectedOption: selectedOption, onOptionSelected: { option in
                                     selectedOption = option
                                     showAnswer = true
                                 })
                    .padding()
                Button(showAnswer ? "隐藏答案" : "查看答案") { showAnswer.toggle() }
                    .buttonStyle(.borderedProminent)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("题目详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}

struct ConeSpotlightView: View {
    let themeColor: Color
    let screenHeight: CGFloat
    
    var body: some View {
        coneSpotlight(themeColor: themeColor, screenHeight: screenHeight)
    }
}

/// iOS 26+ compatible screen size helper (replaces deprecated UIScreen.main)
func screenBounds() -> CGRect {
    if #available(iOS 26.0, *) {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        return windowScene?.screen.bounds ?? CGRect(x: 0, y: 0, width: 393, height: 852)
    } else {
        return UIScreen.main.bounds
    }
}

func coneSpotlight(themeColor: Color, screenHeight: CGFloat) -> some View {
    ZStack {
        RadialGradient(
            gradient: Gradient(stops: [
                .init(color: themeColor.opacity(0.55), location: 0),
                .init(color: themeColor.opacity(0.30), location: 0.15),
                .init(color: themeColor.opacity(0.12), location: 0.40),
                .init(color: themeColor.opacity(0.03), location: 0.70),
                .init(color: .clear, location: 1)
            ]),
            center: UnitPoint(x: 0.5, y: -0.15),
            startRadius: 2,
            endRadius: screenHeight * 0.75
        )
        .blur(radius: 1)
        .allowsHitTesting(false)
        
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: 0.55),
                .init(color: themeColor.opacity(0.02), location: 0.70),
                .init(color: themeColor.opacity(0.06), location: 0.85),
                .init(color: themeColor.opacity(0.12), location: 1)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .blur(radius: 12)
        .allowsHitTesting(false)
    }
    .ignoresSafeArea()
    .allowsHitTesting(false)
}
