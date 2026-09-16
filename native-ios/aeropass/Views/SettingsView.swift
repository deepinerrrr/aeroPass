import SwiftUI
import PhotosUI

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var qm = QuestionManager.shared
    @AppStorage("appThemeColor") private var appThemeRawValue: String = AppTheme.blue.rawValue
    @AppStorage("memorizeSwipeMode") private var memorizeSwipeMode: String = "horizontal"
    @AppStorage("practiceSwipeMode") private var practiceSwipeMode: String = "horizontal"
    @AppStorage("appAppearance") private var appAppearance: String = "system"
    
    @AppStorage("userNickname") private var userNickname: String = "预备飞行员"
    @AppStorage("userAvatarData") private var userAvatarData: Data?
    
    @StateObject private var quoteService = DailyQuoteService.shared
    
    @State private var showResetDataAlert = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isEditingNickname = false
    @State private var tempNickname = ""
    
    var themeColor: Color {
        AppTheme(rawValue: appThemeRawValue)?.color ?? AppTheme.blue.color
    }
    
    var currentTheme: AppTheme {
        AppTheme(rawValue: appThemeRawValue) ?? AppTheme.blue
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                contentView
                    .navigationTitle("个性化设置")
                
                if colorScheme == .dark {
                    coneSpotlight(themeColor: themeColor, screenHeight: screenBounds().height)
                }
            }
            .onAppear {
                quoteService.fetchQuote()
            }
        }
    }
    
    private var contentView: some View {
        List {
            // 个人资料卡片
            profileSection
            
            // 视觉外观与主题适配
            themeAndGestureSection
            
            // AI 辅导与服务、数据管理、关于应用
            serviceAndDataSections
        }
    }
    
    // MARK: - 子视图组件
    
    @ViewBuilder
    private var profileSection: some View {
        Section {
            HStack(spacing: 16) {
                // 头像上传/展示区
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    ZStack {
                        if let data = userAvatarData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 70, height: 70)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .frame(width: 70, height: 70)
                                .foregroundColor(themeColor.opacity(0.8))
                        }
                        
                        // 右下角加一个编辑小图标
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 24, height: 24)
                                .shadow(radius: 2)
                            
                            Image(systemName: "camera.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                        .offset(x: 22, y: 22)
                    }
                }
                .onChange(of: selectedPhotoItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            userAvatarData = data
                        }
                    }
                }
                
                // 昵称与简介
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        if isEditingNickname {
                            TextField("输入新昵称", text: $tempNickname)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(maxWidth: 150)
                                .onSubmit {
                                    if !tempNickname.trimmingCharacters(in: .whitespaces).isEmpty {
                                        userNickname = tempNickname
                                    }
                                    isEditingNickname = false
                                }
                            
                            Button(action: {
                                if !tempNickname.trimmingCharacters(in: .whitespaces).isEmpty {
                                    userNickname = tempNickname
                                }
                                isEditingNickname = false
                            }) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        } else {
                            Text(userNickname)
                                .font(.title3.bold())
                                .foregroundColor(.primary)
                            
                            Button(action: {
                                tempNickname = userNickname
                                isEditingNickname = true
                            }) {
                                Image(systemName: "pencil.line")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Text(quoteService.quote)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .onTapGesture {
                            quoteService.fetchRandomQuote()
                        }
                }
                Spacer()
            }
            .padding(.vertical, 8)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("刷题与背题切换手势方式")
                    .font(.subheadline.bold())
                
                HStack(spacing: 16) {
                    Button(action: {
                        setStudySwipeMode("horizontal")
                    }) {
                        VStack(spacing: 10) {
                            Image(systemName: "arrow.left.and.right.square.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(practiceSwipeMode == "horizontal" ? themeColor.gradient : LinearGradient(colors: [.secondary, .secondary.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            Text("左右滑动切换")
                                .font(.caption.bold())
                                .foregroundColor(practiceSwipeMode == "horizontal" ? themeColor : .primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(practiceSwipeMode == "horizontal" ? themeColor.opacity(0.1) : Color(.systemGray6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(practiceSwipeMode == "horizontal" ? themeColor.opacity(0.4) : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        setStudySwipeMode("vertical")
                    }) {
                        VStack(spacing: 10) {
                            Image(systemName: "arrow.up.and.down.square.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(practiceSwipeMode == "vertical" ? themeColor.gradient : LinearGradient(colors: [.secondary, .secondary.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            Text("上下分页切换")
                                .font(.caption.bold())
                                .foregroundColor(practiceSwipeMode == "vertical" ? themeColor : .primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(practiceSwipeMode == "vertical" ? themeColor.opacity(0.1) : Color(.systemGray6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(practiceSwipeMode == "vertical" ? themeColor.opacity(0.4) : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(Color(.secondarySystemGroupedBackground))
    }
    
    @ViewBuilder
    private var themeAndGestureSection: some View {
        Section(header: Text("视觉外观及手势配置")) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("主题色调适配")
                        .font(.subheadline.bold())
                    Spacer()
                    Text(currentTheme.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(themeColor.opacity(0.15))
                        .foregroundColor(themeColor)
                        .cornerRadius(6)
                }
                
                // 主题色精美卡片式网格
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(AppTheme.allCases) { theme in
                            Button(action: {
                                withAnimation(.spring()) {
                                    appThemeRawValue = theme.rawValue
                                }
                            }) {
                                VStack(spacing: 8) {
                                    Circle()
                                        .fill(theme.gradient)
                                        .frame(width: 44, height: 44)
                                        .shadow(color: theme.color.opacity(0.3), radius: 6, x: 0, y: 3)
                                        .overlay(
                                            Circle()
                                                .stroke(appThemeRawValue == theme.rawValue ? theme.color : Color.clear, lineWidth: 3)
                                        )
                                    
                                    Text(theme.rawValue)
                                        .font(.caption2.bold())
                                        .foregroundColor(appThemeRawValue == theme.rawValue ? theme.color : .secondary)
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(appThemeRawValue == theme.rawValue ? theme.color.opacity(0.12) : Color.clear)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding(.vertical, 8)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("外观模式")
                    .font(.subheadline.bold())
                
                Picker("外观模式", selection: $appAppearance) {
                    Label("日间", systemImage: "sun.max.fill").tag("light")
                    Label("夜间", systemImage: "moon.fill").tag("dark")
                    Label("跟随系统", systemImage: "circle.lefthalf.filled").tag("system")
                }
                .pickerStyle(.segmented)
                .tint(themeColor)
            }
            .padding(.vertical, 8)
        }
    }
    
    @ViewBuilder
    private var serviceAndDataSections: some View {
        // AI 辅导与服务设置
        Section(header: Text("服务与高级配置")) {
            NavigationLink(destination: AIConfigurationView()) {
                HStack {
                    Label("大模型 API 密钥配置", systemImage: "key.fill")
                        .foregroundColor(.primary)
                    Spacer()
                    Text("Qwen / DeepSeek")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        
        // 数据管理
        Section(header: Text("数据管理")) {
            // 题库信息
            HStack {
                Label("当前题库题目数", systemImage: "doc.text.fill")
                Spacer()
                Text("\(qm.totalCount) 道")
                    .font(.caption)
                    .foregroundColor(themeColor)
            }

            NavigationLink {
                HiddenMasteredQuestionsView(themeColor: themeColor)
            } label: {
                HStack {
                    Label("隐藏题目", systemImage: "eye.slash.fill")
                    Spacer()
                    Text("\(qm.getAllQuestions().filter { qm.isMastered($0.questionId) }.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            
            // 重置学习记录
            Button(role: .destructive, action: {
                showResetDataAlert = true
            }) {
                Label("重置所有学习记录", systemImage: "trash.fill")
            }
            .alert("重置确认", isPresented: $showResetDataAlert) {
                Button("取消", role: .cancel) { }
                Button("确认重置", role: .destructive) {
                    resetLearningData()
                }
            } message: {
                Text("此操作将清空您的所有做题记录、收藏和错题数据。此操作不可撤销，是否确认继续？")
            }
        }
        
        // 关于
        Section(header: Text("关于应用")) {
            HStack {
                Text("版本信息")
                Spacer()
                Text("1.6.0 Premium")
                    .foregroundColor(.secondary)
                    .font(.system(.body, design: .monospaced))
            }
        }
    }
    
}

struct HiddenMasteredQuestionsView: View {
    @StateObject private var qm = QuestionManager.shared
    let themeColor: Color

    private var hiddenQuestions: [QuestionData] {
        qm.getAllQuestions().filter { qm.isMastered($0.questionId) }
    }

    var body: some View {
        List(hiddenQuestions) { question in
            VStack(alignment: .leading, spacing: 10) {
                Text(question.content)
                    .font(.subheadline)
                    .lineLimit(3)

                Button {
                    qm.setMastered(question.questionId, mastered: false)
                } label: {
                    Label("重新显示", systemImage: "eye.fill")
                        .font(.caption.weight(.semibold))
                }
                .tint(themeColor)
            }
            .padding(.vertical, 4)
        }
        .overlay {
            if hiddenQuestions.isEmpty {
                ContentUnavailableView(
                    "没有隐藏题目",
                    systemImage: "eye",
                    description: Text("在背题界面标记“已掌握”的题目会显示在这里。")
                )
            }
        }
        .navigationTitle("隐藏题目")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension SettingsView {
    private func setStudySwipeMode(_ mode: String) {
        withAnimation {
            practiceSwipeMode = mode
            memorizeSwipeMode = mode
        }
    }

    private func resetLearningData() {
        qm.resetAllLearningData()
    }
    
    private func resetQuestionBank() {
        // 重新加载题库
        qm.loadQuestions()
    }
}
