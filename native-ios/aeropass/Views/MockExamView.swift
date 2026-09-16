import SwiftUI

struct MockExamView: View {
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var qm = QuestionManager.shared
    @StateObject private var viewModel = MockExamViewModel()
    @State private var showingAlert = false
    
    @AppStorage("appThemeColor") private var themeColorName: String = AppTheme.blue.rawValue
    
    var themeColor: Color {
        AppTheme(rawValue: themeColorName)?.color ?? AppTheme.blue.color
    }
    
    var body: some View {
        VStack {
            if viewModel.isFinished {
                ExamResultView(score: viewModel.score, totalCount: viewModel.questions.count) {
                    dismiss()
                }
            } else if let question = viewModel.currentQuestion {
                // 进度条
                ProgressView(value: Double(viewModel.currentIndex + 1), total: Double(viewModel.questions.count))
                    .progressViewStyle(LinearProgressViewStyle(tint: themeColor))
                    .padding(.horizontal)
                
                HStack {
                    Text("\(viewModel.currentIndex + 1) / \(viewModel.questions.count)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("已答: \(viewModel.selectedOptions.count)")
                        .font(.caption)
                        .foregroundColor(themeColor)
                }
                .padding(.horizontal)
                
                ScrollView {
                    QuestionCardView(
                        question: question,
                        showAnswer: false, // 考试中不显示正确答案
                        selectedOption: viewModel.selectedOptions[question.id],
                        onOptionSelected: { option in
                            viewModel.selectOption(option)
                        },
                        allowsCollectionSearch: false
                    )
                    .padding()
                }
                
                Spacer()
                
                // 底部工具栏
                HStack {
                    Button(action: { viewModel.previousQuestion() }) {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(viewModel.currentIndex > 0 ? themeColor : .gray.opacity(0.5))
                    }
                    .disabled(viewModel.currentIndex == 0)
                    
                    Spacer()
                    
                    Button(action: {
                        showingAlert = true
                    }) {
                        Text("交卷")
                            .bold()
                            .padding(.horizontal, 30)
                            .padding(.vertical, 10)
                            .background(themeColor)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                    }
                    
                    Spacer()
                    
                    Button(action: { viewModel.nextQuestion() }) {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(viewModel.currentIndex < viewModel.questions.count - 1 ? themeColor : .gray.opacity(0.5))
                    }
                    .disabled(viewModel.currentIndex == viewModel.questions.count - 1)
                }
                .padding()
            } else {
                ProgressView("正在生成试卷...")
            }
        }
        .navigationTitle("模拟考试")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            if viewModel.questions.isEmpty {
                let allQuestions = qm.getAllQuestions()
                viewModel.setup(allQuestions: allQuestions)
            }
        }
        .alert("确定要交卷吗？", isPresented: $showingAlert) {
            Button("继续考试", role: .cancel) { }
            Button("交卷", role: .destructive) {
                viewModel.finishExam()
            }
        } message: {
            Text("您已答 \(viewModel.selectedOptions.count) 题，还有 \(viewModel.questions.count - viewModel.selectedOptions.count) 题未作答。")
        }
    }
}

struct ExamResultView: View {
    let score: Int
    let totalCount: Int
    let onExit: () -> Void
    
    @AppStorage("appThemeColor") private var themeColorName: String = AppTheme.blue.rawValue
    
    var themeColor: Color {
        AppTheme(rawValue: themeColorName)?.color ?? AppTheme.blue.color
    }
    
    var body: some View {
        VStack(spacing: 30) {
            Text("模拟考试结束")
                .font(.largeTitle)
                .bold()
            
            ZStack {
                Circle()
                    .stroke(lineWidth: 20)
                    .opacity(0.3)
                    .foregroundColor(score >= 60 ? .green : .red)
                
                Text("\(score)")
                    .font(.system(size: 80, weight: .bold))
                    .foregroundColor(score >= 60 ? .green : .red)
            }
            .frame(width: 200, height: 200)
            
            Text("共 \(totalCount) 道题")
                .foregroundColor(.gray)
            
            Button(action: onExit) {
                Text("返回主页")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(themeColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }
}
