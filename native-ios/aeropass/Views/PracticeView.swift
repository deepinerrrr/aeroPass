import SwiftUI

enum PracticeMode {
    case sequential
    case random
    case wrongbook
    case favorites
}

struct PracticeView: View {
    let mode: PracticeMode
    var initialQuestions: [QuestionData]? = nil
    var scopeID: String? = nil
    @State private var didSetup = false
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @StateObject private var viewModel = PracticeViewModel()
    @StateObject private var qm = QuestionManager.shared
    @StateObject private var drawingController = PencilCanvasController()
    @State private var showAIChat = false

    @State private var sliderValue: Double = 0.0
    @State private var cardOffset: CGSize = .zero
    @State private var dragGeneration = 0
    @State private var isCardTransitioning = false
    
    @State private var showFavoriteAnimation: Bool = false
    @State private var favoriteScale: CGFloat = 0.0
    @State private var favoriteParticles: [PracticeHeartParticle] = []
    @State private var isFavoriteAction: Bool = false
    
    @State private var scrollPageID: Int? = nil
    @State private var showAnswerCard: Bool = false
    
    @State private var showNoteSheet: Bool = false
    @State private var noteText: String = ""
    @State private var isDrawingMode = false
    @State private var annotationData = Data()

    @AppStorage("appThemeColor") private var themeColorName: String = AppTheme.blue.rawValue
    @AppStorage("practiceSwipeMode") private var practiceSwipeMode: String = "horizontal"
    
    var themeColor: Color {
        AppTheme(rawValue: themeColorName)?.color ?? AppTheme.blue.color
    }
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            if !viewModel.questions.isEmpty {
                Group {
                    if practiceSwipeMode == "vertical" {
                        verticalPagingContent
                    } else {
                        horizontalSwipeContent
                    }
                }
            } else {
                ContentUnavailableView(
                    "当前题库已全部掌握",
                    systemImage: "checkmark.seal.fill",
                    description: Text("可前往“工具 › 题库管理 › 已掌握题目”或“设置 › 隐藏题目”重新显示。")
                )
                .foregroundStyle(themeColor)
            }
            
            favoriteAnimationOverlay
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar { practiceToolbar }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !viewModel.questions.isEmpty && !isDrawingMode {
                bottomDock
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if !viewModel.questions.isEmpty && isDrawingMode {
                // 涂画画笔组件（PKToolPicker）默认悬浮在底部，
                // 自定义工具条移到顶部，避免与画笔选择组件重叠。
                drawingToolbar
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            guard !didSetup else { return }
            didSetup = true
            setupViewModel()
            syncSlider()
            scrollPageID = viewModel.currentIndex
            loadCurrentAnnotation()
        }
        .onDisappear { saveCurrentAnnotation() }
        .onChange(of: viewModel.currentQuestion?.questionId) { oldID, newID in
            if let oldID {
                saveAnnotation(annotationData, for: oldID)
            }
            annotationData = newID.map { qm.annotation(for: $0).drawingData } ?? Data()
        }
        .onChange(of: viewModel.currentIndex) { _, newIndex in
            sliderValue = Double(newIndex)
        }
        .sheet(isPresented: $showAIChat) {
            if let q = viewModel.currentQuestion {
                AIChatView(question: q)
            }
        }
        .sheet(isPresented: $showNoteSheet) {
            if let question = viewModel.currentQuestion {
                RichNoteEditorView(question: question)
            }
        }
        .sheet(isPresented: $showAnswerCard) {
            NavigationStack {
                AnswerCardGridView(
                    totalCount: viewModel.questions.count,
                    currentIndex: viewModel.currentIndex,
                    answeredIndices: Set(viewModel.questions.enumerated().compactMap { qm.record(for: $0.element.questionId).attempts > 0 ? $0.offset : nil }),
                    markedIndices: Set(viewModel.questions.enumerated().compactMap {
                        let note = qm.richNote(for: $0.element.questionId)
                        return (!note.text.isEmpty || !note.drawingData.isEmpty) ? $0.offset : nil
                    }),
                    onJump: { index in
                        showAnswerCard = false
                        viewModel.jumpTo(index: index)
                    }
                )
                .navigationTitle("答题卡")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { showAnswerCard = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .onChange(of: viewModel.currentIndex) { _, _ in
            if showNoteSheet { loadNoteText() }
        }
    }
    
    @ToolbarContentBuilder
    private var practiceToolbar: some ToolbarContent {
        if !viewModel.questions.isEmpty {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 7) {
                    Text("\(viewModel.currentIndex + 1)")
                    ProgressView(
                        value: Double(viewModel.currentIndex + 1),
                        total: Double(max(1, viewModel.questions.count))
                    )
                    .progressViewStyle(.linear)
                    .tint(themeColor)
                    .frame(width: 104)
                    Text("\(viewModel.questions.count)")
                }
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("题目进度")
                .accessibilityValue("第 \(viewModel.currentIndex + 1) 题，共 \(viewModel.questions.count) 题")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    guard viewModel.currentQuestion != nil, !isDrawingMode else { return }
                    triggerFavoriteAnimation()
                } label: {
                    Image(systemName: viewModel.currentQuestion.map { qm.isFavorite($0.questionId) } == true ? "star.fill" : "star")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(viewModel.currentQuestion.map { qm.isFavorite($0.questionId) } == true ? Color.yellow : themeColor)
                }
                .disabled(isDrawingMode)
                .accessibilityLabel(viewModel.currentQuestion.map { qm.isFavorite($0.questionId) } == true ? "取消收藏" : "收藏题目")
            }
        }
    }

    private var bottomDock: some View {
        dockContent
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 6)
    }

    private var dockContent: some View {
        HStack(spacing: 14) {
            dockButton(title: "答题卡", systemImage: "square.grid.2x2") {
                saveCurrentAnnotation()
                showAnswerCard = true
            }
            dockButton(
                title: "涂画",
                systemImage: isDrawingMode ? "pencil.tip.crop.circle.badge.minus" : "pencil.tip.crop.circle",
                isSelected: isDrawingMode
            ) { toggleDrawingMode() }
            dockButton(title: "AI", systemImage: "sparkles") {
                saveCurrentAnnotation()
                showAIChat = true
            }
            dockButton(
                title: "笔记",
                systemImage: hasCurrentNote ? "note.text" : "note.text.badge.plus"
            ) {
                saveCurrentAnnotation()
                showNoteSheet = true
            }
        }
        .frame(maxWidth: 430)
    }

    private var drawingToolbar: some View {
        HStack(spacing: 10) {
            Label("涂画中", systemImage: "pencil.and.outline")
                .font(.caption.weight(.semibold))
                .foregroundStyle(themeColor)
            Spacer()
            Button { drawingController.undo() } label: {
                Image(systemName: "arrow.uturn.backward").frame(width: 34, height: 34)
            }
            .disabled(!drawingController.canUndo)
            .accessibilityLabel("撤销上一笔")
            Button(role: .destructive) {
                drawingController.clear()
                annotationData = Data()
            } label: {
                Image(systemName: "trash").frame(width: 34, height: 34)
            }
            .disabled(!drawingController.hasDrawing)
            .accessibilityLabel("清空涂画")
            Button { toggleDrawingMode() } label: {
                Label("退出涂画", systemImage: "pencil.slash").font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(themeColor)
            .accessibilityHint("关闭涂画模式并恢复题卡滑动")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(themeColor.opacity(0.16), lineWidth: 0.5))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func dockButton(
        title: String,
        systemImage: String,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(isSelected ? themeColor : Color.primary)
                .frame(width: 50, height: 50)
                .background {
                    Circle().fill(isSelected ? themeColor.opacity(0.14) : Color(.systemBackground).opacity(0.42))
                }
                .background(.regularMaterial, in: Circle())
                .overlay(Circle().stroke(themeColor.opacity(isSelected ? 0.26 : 0.10), lineWidth: 0.8))
                .shadow(color: Color.black.opacity(0.10), radius: 12, x: 0, y: 5)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "已开启" : "")
    }

    private var hasCurrentNote: Bool {
        guard let question = viewModel.currentQuestion else { return false }
        let note = qm.richNote(for: question.questionId)
        return !note.text.isEmpty || !note.drawingData.isEmpty
    }

    private func toggleDrawingMode() {
        if isDrawingMode {
            drawingController.syncDrawing()
            saveCurrentAnnotation()
        } else {
            loadCurrentAnnotation()
        }
        let animation: Animation = reduceMotion
            ? .easeOut(duration: 0.18)
            : .interactiveSpring(response: 0.32, dampingFraction: 0.9, blendDuration: 0.08)
        withAnimation(animation) { isDrawingMode.toggle() }
    }

    private func markCurrentQuestionMastered() {
        saveCurrentAnnotation()
        withAnimation(.easeOut(duration: 0.2)) { viewModel.markCurrentQuestionMastered() }
        scrollPageID = viewModel.questions.isEmpty ? nil : viewModel.currentIndex
        cardOffset = .zero
    }

    private func loadCurrentAnnotation() {
        annotationData = viewModel.currentQuestion.map { qm.annotation(for: $0.questionId).drawingData } ?? Data()
    }

    private func saveCurrentAnnotation() {
        guard let questionID = viewModel.currentQuestion?.questionId else { return }
        saveAnnotation(annotationData, for: questionID)
    }

    private func saveAnnotation(_ data: Data, for questionID: String) {
        let current = qm.annotation(for: questionID)
        guard current.drawingData != data else { return }
        var updated = current
        updated.drawingData = data
        qm.saveAnnotation(updated)
    }

    private var topHeader: some View {
        VStack(spacing: 8) {
            Text(titleForMode)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            HStack(spacing: 8) {
                Text("第 \(viewModel.currentIndex + 1) 题")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize()
                QuestionProgressBar(
                    value: $sliderValue,
                    maximum: Double(max(0, viewModel.questions.count - 1)),
                    tint: themeColor
                )
                .onChange(of: sliderValue) { _, newValue in
                    let index = Int(newValue.rounded())
                    if index != viewModel.currentIndex { viewModel.jumpTo(index: index) }
                }
                Text("共 \(viewModel.questions.count) 题")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
            .padding(.horizontal, 10)
        }
        .padding(.bottom, 8)
        .background(Color(.secondarySystemGroupedBackground).opacity(0.6))
    }
    
    private var horizontalSwipeContent: some View {
        GeometryReader { geo in
            if let question = viewModel.currentQuestion {
                ZStack {
                    if cardOffset.width < 0, viewModel.currentIndex < viewModel.questions.count - 1 {
                        practiceCardPage(
                            question: viewModel.questions[viewModel.currentIndex + 1],
                            isCurrent: false
                        )
                        .offset(x: geo.size.width + cardOffset.width)
                        .allowsHitTesting(false)
                    }

                    if cardOffset.width > 0, viewModel.currentIndex > 0 {
                        practiceCardPage(
                            question: viewModel.questions[viewModel.currentIndex - 1],
                            isCurrent: false
                        )
                        .offset(x: -geo.size.width + cardOffset.width)
                        .allowsHitTesting(false)
                    }

                    practiceCardPage(question: question, isCurrent: true)
                        .offset(x: cardOffset.width)
                        .scaleEffect(reduceMotion ? 1 : 1 - min(abs(cardOffset.width) / max(geo.size.width, 1), 1) * 0.018)
                        .rotationEffect(.degrees(reduceMotion ? 0 : Double(cardOffset.width / max(geo.size.width, 1)) * 1.4), anchor: .bottom)
                }
                .contentShape(Rectangle())
                .clipped()
                .simultaneousGesture(horizontalQuestionGesture(containerWidth: geo.size.width), including: isDrawingMode ? .none : .all)
            }
        }
    }

    private func horizontalQuestionGesture(containerWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !isDrawingMode, !isCardTransitioning else { return }
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let canMove = value.translation.width < 0
                    ? viewModel.currentIndex < viewModel.questions.count - 1
                    : viewModel.currentIndex > 0
                cardOffset = CGSize(
                    width: canMove ? value.translation.width : rubberBand(value.translation.width, dimension: containerWidth),
                    height: 0
                )
            }
            .onEnded { value in
                guard !isDrawingMode, !isCardTransitioning else { return }
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    resetCardOffset()
                    return
                }
                let projectedX = value.predictedEndTranslation.width
                let forward = projectedX < 0 || (projectedX == 0 && value.translation.width < 0)
                let shouldMove = abs(value.translation.width) > containerWidth * 0.24
                    || abs(projectedX) > containerWidth * 0.46
                let canMove = forward
                    ? viewModel.currentIndex < viewModel.questions.count - 1
                    : viewModel.currentIndex > 0
                if shouldMove && canMove {
                    completeHorizontalTransition(forward: forward, containerWidth: containerWidth)
                } else {
                    resetCardOffset()
                }
            }
    }

    private func rubberBand(_ translation: CGFloat, dimension: CGFloat) -> CGFloat {
        let safeDimension = max(dimension, 1)
        return (translation * safeDimension * 0.55) / (safeDimension + 0.55 * abs(translation))
    }

    private func completeHorizontalTransition(forward: Bool, containerWidth: CGFloat) {
        guard !isCardTransitioning else { return }
        isCardTransitioning = true
        dragGeneration += 1
        let generation = dragGeneration
        let animation: Animation = reduceMotion
            ? .easeOut(duration: 0.18)
            : .interactiveSpring(response: 0.34, dampingFraction: 0.82, blendDuration: 0.1)
        withAnimation(animation) {
            cardOffset = CGSize(width: forward ? -containerWidth : containerWidth, height: 0)
        } completion: {
            guard generation == dragGeneration else {
                isCardTransitioning = false
                return
            }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                if forward { viewModel.nextQuestion() } else { viewModel.previousQuestion() }
                cardOffset = .zero
            }
            isCardTransitioning = false
        }
    }

    private func resetCardOffset() {
        dragGeneration += 1
        let animation: Animation = reduceMotion
            ? .easeOut(duration: 0.16)
            : .interactiveSpring(response: 0.36, dampingFraction: 0.9, blendDuration: 0.1)
        withAnimation(animation) { cardOffset = .zero }
    }

    private func practiceCardPage(question: QuestionData, isCurrent: Bool) -> some View {
        CenteredScrollableQuestionPage(scrollingEnabled: !(isDrawingMode && isCurrent)) {
            practiceCardSurface(question: question, isCurrent: isCurrent)
        }
        .id(question.id)
    }

    private func practiceCardSurface(question: QuestionData, isCurrent: Bool) -> some View {
        QuestionCardView(
            question: question,
            showAnswer: isCurrent ? viewModel.showAnswer : false,
            selectedOption: isCurrent ? viewModel.selectedOption : nil,
            onOptionSelected: isCurrent ? { option in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    viewModel.selectOption(option)
                }
            } : nil
        )
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .highPriorityGesture(TapGesture(count: 2).onEnded {
            guard isCurrent, !isDrawingMode else { return }
            triggerFavoriteAnimation()
        })
        .overlay {
            if isCurrent && (isDrawingMode || !annotationData.isEmpty) {
                PencilCanvas(
                    drawingData: $annotationData,
                    isInteractive: isDrawingMode,
                    controller: isDrawingMode ? drawingController : nil
                )
                    .background(Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .allowsHitTesting(isDrawingMode)
                    .transition(.opacity)
                    .accessibilityLabel("当前题目涂画区域")
            }
        }
    }
    
    private var verticalPagingContent: some View {
        GeometryReader { geo in
            if let question = viewModel.currentQuestion {
                ZStack {
                    if cardOffset.height < 0,
                       viewModel.currentIndex < viewModel.questions.count - 1 {
                        questionCardPage(
                            question: viewModel.questions[viewModel.currentIndex + 1],
                            index: viewModel.currentIndex + 1
                        )
                        .offset(y: geo.size.height + cardOffset.height)
                        .allowsHitTesting(false)
                    }

                    if cardOffset.height > 0, viewModel.currentIndex > 0 {
                        questionCardPage(
                            question: viewModel.questions[viewModel.currentIndex - 1],
                            index: viewModel.currentIndex - 1
                        )
                        .offset(y: -geo.size.height + cardOffset.height)
                        .allowsHitTesting(false)
                    }

                    questionCardPage(question: question, index: viewModel.currentIndex)
                        .offset(y: cardOffset.height)
                        .scaleEffect(
                            reduceMotion
                                ? 1
                                : 1 - min(abs(cardOffset.height) / max(geo.size.height, 1), 1) * 0.014
                        )
                }
                .contentShape(Rectangle())
                .clipped()
                .simultaneousGesture(
                    verticalQuestionGesture(containerHeight: geo.size.height),
                    including: isDrawingMode ? .none : .all
                )
            }
        }
    }

    private func verticalQuestionGesture(containerHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { value in
                guard !isDrawingMode, !isCardTransitioning else { return }
                guard abs(value.translation.height) > abs(value.translation.width) else { return }
                let canMove = value.translation.height < 0
                    ? viewModel.currentIndex < viewModel.questions.count - 1
                    : viewModel.currentIndex > 0
                cardOffset = CGSize(
                    width: 0,
                    height: canMove
                        ? value.translation.height
                        : rubberBand(value.translation.height, dimension: containerHeight)
                )
            }
            .onEnded { value in
                guard !isDrawingMode, !isCardTransitioning else { return }
                guard abs(value.translation.height) > abs(value.translation.width) else {
                    resetCardOffset()
                    return
                }

                let projectedY = value.predictedEndTranslation.height
                let forward = projectedY < 0 || (projectedY == 0 && value.translation.height < 0)
                let shouldMove = abs(value.translation.height) > containerHeight * 0.20
                    || abs(projectedY) > containerHeight * 0.38
                let canMove = forward
                    ? viewModel.currentIndex < viewModel.questions.count - 1
                    : viewModel.currentIndex > 0
                if shouldMove && canMove {
                    completeVerticalTransition(forward: forward, containerHeight: containerHeight)
                } else {
                    resetCardOffset()
                }
            }
    }

    private func completeVerticalTransition(forward: Bool, containerHeight: CGFloat) {
        guard !isCardTransitioning else { return }
        isCardTransitioning = true
        dragGeneration += 1
        let generation = dragGeneration
        let animation: Animation = reduceMotion
            ? .easeOut(duration: 0.18)
            : .interactiveSpring(response: 0.34, dampingFraction: 0.84, blendDuration: 0.1)
        withAnimation(animation) {
            cardOffset = CGSize(width: 0, height: forward ? -containerHeight : containerHeight)
        } completion: {
            guard generation == dragGeneration else {
                isCardTransitioning = false
                return
            }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                if forward { viewModel.nextQuestion() } else { viewModel.previousQuestion() }
                scrollPageID = viewModel.currentIndex
                cardOffset = .zero
            }
            syncSlider()
            isCardTransitioning = false
        }
    }
    
    private func questionCardPage(question: QuestionData, index: Int) -> some View {
        CenteredScrollableQuestionPage(scrollingEnabled: !isDrawingMode) {
            practiceCardSurface(question: question, isCurrent: index == viewModel.currentIndex)
        }
    }
    
    private var bottomBar: some View {
        HStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.previousQuestion()
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.title3.bold())
                    .foregroundColor(viewModel.currentIndex > 0 ? themeColor : .secondary.opacity(0.4))
                    .frame(width: 44, height: 44)
            }
            .disabled(viewModel.currentIndex == 0)
            
            Spacer()
            
            Button(action: { showAnswerCard = true }) {
                Image(systemName: "square.grid.2x2")
                    .font(.title3)
                    .foregroundColor(themeColor)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("答题卡")
            
            Spacer()
            
            Button(action: { showNoteSheet = true }) {
                Image(systemName: (viewModel.currentQuestion.map {
                    let note = qm.richNote(for: $0.questionId)
                    return !note.text.isEmpty || !note.drawingData.isEmpty
                } == true) ? "note.text" : "note.text.badge.plus")
                    .font(.title3)
                    .foregroundColor((viewModel.currentQuestion.map { qm.note(for: $0.questionId)?.isEmpty == false } == true) ? .orange : themeColor)
                    .frame(width: 44, height: 44)
            }
            
            Spacer()
            
            Button(action: { showAIChat = true }) {
                AIProviderLogoPair()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground), in: Capsule())
                    .overlay(Capsule().stroke(themeColor.opacity(0.2), lineWidth: 1))
            }
            .accessibilityLabel("DeepSeek 与 Qwen AI 助手")
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.nextQuestion()
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.title3.bold())
                    .foregroundColor(viewModel.currentIndex < viewModel.questions.count - 1 ? themeColor : .secondary.opacity(0.4))
                    .frame(width: 44, height: 44)
            }
            .disabled(viewModel.currentIndex == viewModel.questions.count - 1)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: -4)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
    
    private var favoriteAnimationOverlay: some View {
        ZStack {
            if showFavoriteAnimation {
                ForEach(favoriteParticles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .scaleEffect(particle.scale)
                        .opacity(particle.opacity)
                        .position(particle.position)
                        .blur(radius: 1.5)
                }
                
                Image(systemName: isFavoriteAction ? "star.fill" : "star.slash.fill")
                    .font(.system(size: 72))
                    .foregroundColor(isFavoriteAction ? .yellow : .gray)
                    .scaleEffect(favoriteScale)
                    .opacity(favoriteScale > 0.2 ? 1.0 : 0.0)
                    .shadow(color: isFavoriteAction ? .yellow.opacity(0.6) : .gray.opacity(0.4), radius: 25)
            }
        }
        .allowsHitTesting(false)
    }
    
    private func setupViewModel() {
        let allQuestions = initialQuestions ?? qm.getAllQuestions()
        viewModel.scopeID = scopeID ?? qm.activeBank?.id.uuidString
        print("📋 PracticeView 加载题目数: \(allQuestions.count)")
        
        var targetQuestions = allQuestions
        
        switch mode {
        case .sequential: break
        case .random: targetQuestions.shuffle()
        case .wrongbook: targetQuestions = targetQuestions.filter { qm.isWrong($0.questionId) }
        case .favorites: targetQuestions = targetQuestions.filter { qm.isFavorite($0.questionId) }
        }
        
        viewModel.setup(questions: targetQuestions, mode: mode)
    }
    
    private func syncSlider() {
        sliderValue = Double(viewModel.currentIndex)
    }
    
    private func triggerFavoriteAnimation() {
        viewModel.toggleFavorite()
        let isNowFavorite = viewModel.currentQuestion.map { qm.isFavorite($0.questionId) } == true
        isFavoriteAction = isNowFavorite
        
        showFavoriteAnimation = true
        favoriteScale = 0.0
        favoriteParticles = []
        
        let screenWidth = screenBounds().width
        let screenHeight = screenBounds().height
        let centerX = screenWidth / 2
        let centerY = screenHeight / 2
        
        var particles: [PracticeHeartParticle] = []
        for i in 0..<16 {
            let angle = Double(i) * .pi * 2.0 / 16.0
            let distance: CGFloat = 50 + CGFloat.random(in: 20...70)
            particles.append(PracticeHeartParticle(
                id: i,
                position: CGPoint(x: centerX, y: centerY),
                targetOffset: CGSize(width: CGFloat(cos(angle)) * distance, height: CGFloat(sin(angle)) * distance),
                color: isNowFavorite ? [.yellow, .orange, .yellow.opacity(0.8)].randomElement()! : [.gray, .gray.opacity(0.6)].randomElement()!,
                size: CGFloat.random(in: 4...10),
                opacity: 1.0,
                scale: 0.2
            ))
        }
        favoriteParticles = particles
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            favoriteScale = 1.3
            for i in favoriteParticles.indices {
                favoriteParticles[i].position = CGPoint(
                    x: centerX + favoriteParticles[i].targetOffset.width,
                    y: centerY + favoriteParticles[i].targetOffset.height
                )
                favoriteParticles[i].opacity = 0.9
                favoriteParticles[i].scale = 1.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                favoriteScale = 1.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeOut(duration: 0.35)) {
                favoriteScale = 0.0
                for i in favoriteParticles.indices {
                    favoriteParticles[i].opacity = 0.0
                    favoriteParticles[i].scale = 0.1
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
            showFavoriteAnimation = false
            favoriteParticles = []
        }
    }
    
    private var noteEditorView: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let question = viewModel.currentQuestion {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(question.isTrueFalse ? "判断题" : "单选题")
                            .font(.caption.bold())
                            .foregroundColor(themeColor)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(themeColor.opacity(0.12))
                            .cornerRadius(4)
                        Text(question.content)
                            .font(.subheadline)
                            .lineLimit(3)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top)
                }
                
                TextEditor(text: $noteText)
                    .font(.body)
                    .padding(12)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(themeColor.opacity(0.2), lineWidth: 1)
                    )
                    .padding()
                
                Spacer()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("笔记与备注")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showNoteSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveNote()
                        showNoteSheet = false
                    }
                    .bold()
                }
            }
            .onAppear { loadNoteText() }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func loadNoteText() {
        noteText = viewModel.currentQuestion.flatMap { qm.note(for: $0.questionId) } ?? ""
    }
    
    private func saveNote() {
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let q = viewModel.currentQuestion {
            qm.setNote(q.questionId, note: trimmed.isEmpty ? nil : trimmed)
        }
    }
}

struct PracticeHeartParticle: Identifiable {
    let id: Int
    var position: CGPoint
    let targetOffset: CGSize
    let color: Color
    var size: CGFloat
    var opacity: Double
    var scale: CGFloat
}

extension PracticeView {
    var titleForMode: String {
        switch mode {
        case .sequential: return "顺序刷题"
        case .random: return "随机刷题"
        case .wrongbook: return "错题本"
        case .favorites: return "收藏题库"
        }
    }
}
