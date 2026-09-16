import SwiftUI

struct AIChatView: View {
    let question: QuestionData?

    init(question: QuestionData? = nil) {
        self.question = question
    }

    @StateObject private var viewModel = AIChatViewModel()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @State private var showClearConfirmation = false
    @AppStorage("appThemeColor") private var themeColorName: String = AppTheme.blue.rawValue

    var themeColor: Color {
        AppTheme(rawValue: themeColorName)?.color ?? AppTheme.blue.color
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 对话内容区
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages.filter { !$0.isHidden }) { message in
                                MessageBubble(message: message, themeColor: themeColor)
                                    .id(message.id)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: message.role == .user ? .trailing : .leading).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                            }

                            if let error = viewModel.errorMessage {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(LocalizedStringKey(error)).foregroundStyle(.red)
                                    Button("重试回答") { viewModel.retryLastResponse() }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }
                            if let error = viewModel.storageError { Text(error).font(.caption).foregroundStyle(.red) }

                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        withAnimation(.easeOut(duration: 0.3)) {
                            if let last = viewModel.messages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: viewModel.messages.last?.content) { oldContent, newContent in
                        // Throttled auto-scroll during streaming
                        guard viewModel.isGenerating else { return }
                        let now = Date()
                        if now.timeIntervalSince(viewModel.lastScrollTime) > 0.5 {
                            viewModel.lastScrollTime = now
                            withAnimation(.easeOut(duration: 0.2)) {
                                if let last = viewModel.messages.last {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }

                Divider()

                // 底部输入区
                HStack(alignment: .bottom, spacing: 12) {
                    TextField("请描述你想了解的问题……", text: $viewModel.inputText, axis: .vertical)
                        .focused($isFocused)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                        .lineLimit(1...5)

                    if viewModel.isGenerating {
                        Button(action: { viewModel.stopGenerating() }) {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.red)
                        }
                    } else {
                        Button(action: {
                            let text = viewModel.inputText
                            viewModel.sendMessage(text)
                            isFocused = false
                        }) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : themeColor)
                        }
                        .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
            }
            .navigationTitle("AI 辅导答疑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("AI 模型", selection: $viewModel.provider) {
                            ForEach(AIProvider.allCases) { Text($0.name).tag($0) }
                        }.disabled(viewModel.isGenerating)
                        Button("重新回答", systemImage: "arrow.clockwise") { viewModel.retryLastResponse() }
                            .disabled(viewModel.isGenerating || !viewModel.messages.contains(where: { $0.role == .user }))
                        Button("清空对话", systemImage: "trash", role: .destructive) { showClearConfirmation = true }
                    } label: { Label(viewModel.provider.name, systemImage: "slider.horizontal.3") }
                }
            }
            .alert("清空对话？", isPresented: $showClearConfirmation) {
                Button("取消", role: .cancel) { }
                Button("清空", role: .destructive) { viewModel.clearHistory() }
            } message: { Text("当前对话历史将被删除。题目问答会重新生成解析。") }
            .onAppear {
                if let question = question {
                    viewModel.setup(question: question)
                } else {
                    viewModel.setupForGeneralChat()
                }
            }
            .onDisappear {
                viewModel.stopGenerating()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
    }
}

// MARK: - 消息气泡（含 Markdown 渲染）
struct MessageBubble: View {
    @State private var markdownHeight: CGFloat = 40
    let message: ChatMessage
    let themeColor: Color

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .user {
                Spacer(minLength: 16)
                userBubble
            } else {
                aiBubble
                Spacer(minLength: 16)
            }
        }
    }

    private var userBubble: some View {
        Text(message.content)
            .font(.body)
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(themeColor)
            .cornerRadius(18)
            .cornerRadius(4, corners: [.bottomRight])
            .textSelection(.enabled)
    }

    private var aiBubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            if message.content.isEmpty && message.isStreaming {
                Label("正在生成回答…", systemImage: "ellipsis.bubble").font(.caption).padding(14)
            }
            MarkdownWebView(markdownContent: message.content, themeColor: themeColor, contentHeight: $markdownHeight)
                .frame(height: markdownHeight)
                .padding(.horizontal, 4)
                .padding(.vertical, 6)

            if message.isStreaming {
                HStack(spacing: 4) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 5, height: 5)
                            .opacity(0.6)
                            .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.2), value: message.isStreaming)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(18)
        .cornerRadius(4, corners: [.bottomLeft])
        .textSelection(.enabled)
        .contextMenu {
            Button("复制回答", systemImage: "doc.on.doc") { UIPasteboard.general.string = message.content }
            ShareLink(item: message.content)
        }
    }
}

// MARK: - 圆角扩展
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
