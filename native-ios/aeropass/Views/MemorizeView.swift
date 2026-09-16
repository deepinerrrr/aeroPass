import SwiftUI

struct HeartParticle: Identifiable, Equatable {
    let id: Int
    var position: CGPoint
    let targetOffset: CGSize
    let color: Color
    var size: CGFloat
    var opacity: Double
    var scale: CGFloat
    
    static func == (lhs: HeartParticle, rhs: HeartParticle) -> Bool {
        lhs.id == rhs.id
    }
}

struct MemorizeView: View {
    var initialQuestions: [QuestionData]? = nil
    var scopeID: String? = nil
    @State private var didSetup = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel = MemorizeViewModel()
    @StateObject private var qm = QuestionManager.shared
    @StateObject private var drawingController = PencilCanvasController()
    
    @State private var cardOffset: CGSize = .zero
    @State private var dragGeneration = 0
    @State private var isCardTransitioning = false
    
    @State private var heartParticles: [HeartParticle] = []
    @State private var showHeartAnimation: Bool = false
    @State private var heartScale: CGFloat = 0.0
    
    @State private var scrollPageID: Int? = nil
    @State private var showAnswerCard: Bool = false
    @State private var showAIChat = false
    @State private var showNoteSheet = false
    @State private var isDrawingMode = false
    @State private var annotationData = Data()
    
    @AppStorage("appThemeColor") private var themeColorName: String = AppTheme.blue.rawValue
    @AppStorage("practiceSwipeMode") private var studySwipeMode: String = "horizontal"
    
    var themeColor: Color {
        AppTheme(rawValue: themeColorName)?.color ?? AppTheme.blue.color
    }
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            if !viewModel.questions.isEmpty {
                Group {
                    if studySwipeMode == "vertical" {
                        verticalPagingContent
                    } else {
                        horizontalCardSection
                    }
                }
            } else {
                ContentUnavailableView(
                    "当前题库已全部掌握",
                    systemImage: "checkmark.seal.fill",
                    description: Text("可前往“工具 › 题库管理 › 已掌握题目”或“设置 › 隐藏题目”重新显示。")
                )
            }
            
            particleAnimationLayer
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar { memorizeToolbar }
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
            let allQuestions = initialQuestions ?? qm.getAllQuestions()
            viewModel.progressKey = scopeID.map { "memorize_collection_\($0)" } ?? "memorize_\(qm.activeBank?.id.uuidString ?? "default")"
            viewModel.setup(questions: allQuestions)

            let lastIndex = UserDefaults.standard.integer(forKey: viewModel.progressKey)
            if lastIndex < allQuestions.count {
                viewModel.restoreProgress(lastIndex: lastIndex)
            }
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
        .sheet(isPresented: $showAnswerCard) {
            answerCardSheet
        }
        .sheet(isPresented: $showAIChat) {
            if let question = viewModel.currentQuestion {
                AIChatView(question: question)
            }
        }
        .sheet(isPresented: $showNoteSheet) {
            if let question = viewModel.currentQuestion {
                RichNoteEditorView(question: question)
            }
        }
    }

    @ToolbarContentBuilder
    private var memorizeToolbar: some ToolbarContent {
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
    
    private var horizontalCardSection: some View {
        GeometryReader { geo in
            if let question = viewModel.currentQuestion {
                ZStack {
                    if cardOffset.width < 0,
                       viewModel.currentIndex < viewModel.questions.count - 1 {
                        horizontalCardPage(
                            question: viewModel.questions[viewModel.currentIndex + 1],
                            number: viewModel.currentIndex + 2,
                            isCurrent: false
                        )
                        .offset(x: geo.size.width + cardOffset.width)
                        .allowsHitTesting(false)
                    }

                    if cardOffset.width > 0, viewModel.currentIndex > 0 {
                        horizontalCardPage(
                            question: viewModel.questions[viewModel.currentIndex - 1],
                            number: viewModel.currentIndex,
                            isCurrent: false
                        )
                        .offset(x: -geo.size.width + cardOffset.width)
                        .allowsHitTesting(false)
                    }

                    horizontalCardPage(
                        question: question,
                        number: viewModel.currentIndex + 1,
                        isCurrent: true
                    )
                    .offset(x: cardOffset.width)
                    .scaleEffect(
                        reduceMotion
                            ? 1
                            : 1 - min(abs(cardOffset.width) / max(geo.size.width, 1), 1) * 0.018
                    )
                    .rotationEffect(
                        .degrees(
                            reduceMotion
                                ? 0
                                : Double(cardOffset.width / max(geo.size.width, 1)) * 1.4
                        ),
                        anchor: .bottom
                    )
                }
                .contentShape(Rectangle())
                .clipped()
                .simultaneousGesture(
                    horizontalQuestionGesture(containerWidth: geo.size.width),
                    including: isDrawingMode ? .none : .all
                )
            }
        }
    }

    private func horizontalCardPage(
        question: QuestionData,
        number: Int,
        isCurrent: Bool
    ) -> some View {
        CenteredScrollableQuestionPage(scrollingEnabled: !(isDrawingMode && isCurrent)) {
            memorizeCardSurface(
                question: question,
                questionNumber: number,
                isCurrentQuestion: isCurrent
            )
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .highPriorityGesture(
                TapGesture(count: 2).onEnded {
                    guard isCurrent, !isDrawingMode else { return }
                    triggerFavoriteAnimation()
                }
            )
        }
        .id(question.id)
    }

    private func horizontalQuestionGesture(containerWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !isDrawingMode, !isCardTransitioning else { return }
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let canMove = value.translation.width < 0
                    ? viewModel.currentIndex < viewModel.questions.count - 1
                    : viewModel.currentIndex > 0
                let x = canMove
                    ? value.translation.width
                    : rubberBand(value.translation.width, dimension: containerWidth)
                cardOffset = CGSize(width: x, height: 0)
            }
            .onEnded { value in
                guard !isDrawingMode, !isCardTransitioning else { return }
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    resetCardOffset()
                    return
                }

                let projectedX = value.predictedEndTranslation.width
                let shouldMove = abs(value.translation.width) > containerWidth * 0.24
                    || abs(projectedX) > containerWidth * 0.46
                let movesForward = projectedX < 0 || (projectedX == 0 && value.translation.width < 0)
                let canMove = movesForward
                    ? viewModel.currentIndex < viewModel.questions.count - 1
                    : viewModel.currentIndex > 0

                if shouldMove && canMove {
                    completeHorizontalTransition(
                        forward: movesForward,
                        containerWidth: containerWidth
                    )
                } else {
                    resetCardOffset()
                }
            }
    }

    private func rubberBand(_ translation: CGFloat, dimension: CGFloat) -> CGFloat {
        let safeDimension = max(dimension, 1)
        return (translation * safeDimension * 0.55)
            / (safeDimension + 0.55 * abs(translation))
    }

    private func completeHorizontalTransition(forward: Bool, containerWidth: CGFloat) {
        guard !isCardTransitioning else { return }
        isCardTransitioning = true
        dragGeneration += 1
        let generation = dragGeneration
        let target = forward ? -containerWidth : containerWidth

        let animation: Animation = reduceMotion
            ? .easeOut(duration: 0.18)
            : .interactiveSpring(response: 0.34, dampingFraction: 0.82, blendDuration: 0.1)
        withAnimation(animation) {
            cardOffset = CGSize(width: target, height: 0)
        } completion: {
            guard generation == dragGeneration else {
                isCardTransitioning = false
                return
            }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                if forward {
                    viewModel.nextQuestion()
                } else {
                    viewModel.previousQuestion()
                }
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
        withAnimation(animation) {
            cardOffset = .zero
        }
    }
    
    private var verticalPagingContent: some View {
        GeometryReader { geo in
            if let question = viewModel.currentQuestion {
                ZStack {
                    if cardOffset.height < 0,
                       viewModel.currentIndex < viewModel.questions.count - 1 {
                        memorizedCardPage(
                            question: viewModel.questions[viewModel.currentIndex + 1],
                            index: viewModel.currentIndex + 1
                        )
                        .offset(y: geo.size.height + cardOffset.height)
                        .allowsHitTesting(false)
                    }

                    if cardOffset.height > 0, viewModel.currentIndex > 0 {
                        memorizedCardPage(
                            question: viewModel.questions[viewModel.currentIndex - 1],
                            index: viewModel.currentIndex - 1
                        )
                        .offset(y: -geo.size.height + cardOffset.height)
                        .allowsHitTesting(false)
                    }

                    memorizedCardPage(question: question, index: viewModel.currentIndex)
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
                let y = canMove
                    ? value.translation.height
                    : rubberBand(value.translation.height, dimension: containerHeight)
                cardOffset = CGSize(width: 0, height: y)
            }
            .onEnded { value in
                guard !isDrawingMode, !isCardTransitioning else { return }
                guard abs(value.translation.height) > abs(value.translation.width) else {
                    resetCardOffset()
                    return
                }

                let projectedY = value.predictedEndTranslation.height
                let shouldMove = abs(value.translation.height) > containerHeight * 0.20
                    || abs(projectedY) > containerHeight * 0.38
                let movesForward = projectedY < 0 || (projectedY == 0 && value.translation.height < 0)
                let canMove = movesForward
                    ? viewModel.currentIndex < viewModel.questions.count - 1
                    : viewModel.currentIndex > 0

                if shouldMove && canMove {
                    completeVerticalTransition(
                        forward: movesForward,
                        containerHeight: containerHeight
                    )
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
        let target = forward ? -containerHeight : containerHeight

        let animation: Animation = reduceMotion
            ? .easeOut(duration: 0.18)
            : .interactiveSpring(response: 0.34, dampingFraction: 0.84, blendDuration: 0.1)
        withAnimation(animation) {
            cardOffset = CGSize(width: 0, height: target)
        } completion: {
            guard generation == dragGeneration else {
                isCardTransitioning = false
                return
            }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                if forward {
                    viewModel.nextQuestion()
                } else {
                    viewModel.previousQuestion()
                }
                scrollPageID = viewModel.currentIndex
                cardOffset = .zero
            }
            isCardTransitioning = false
        }
    }
    
    private func memorizedCardPage(question: QuestionData, index: Int) -> some View {
        CenteredScrollableQuestionPage(scrollingEnabled: !isDrawingMode) {
            memorizeCardSurface(
                question: question,
                questionNumber: index + 1,
                isCurrentQuestion: index == viewModel.currentIndex
            )
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .highPriorityGesture(
                TapGesture(count: 2).onEnded {
                    guard index == viewModel.currentIndex, !isDrawingMode else { return }
                    triggerFavoriteAnimation()
                }
            )
        }
    }

    private func memorizeCardSurface(
        question: QuestionData,
        questionNumber: Int,
        isCurrentQuestion: Bool
    ) -> some View {
        MemorizeCardNoSwipe(
            question: question,
            questionNumber: questionNumber,
            showAnswer: viewModel.showAnswer,
            showsCollectionSearch: true,
            themeColor: themeColor
        )
        .overlay {
            if isCurrentQuestion && (isDrawingMode || !annotationData.isEmpty) {
                PencilCanvas(
                    drawingData: $annotationData,
                    isInteractive: isDrawingMode,
                    controller: isDrawingMode ? drawingController : nil
                )
                .background(Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .allowsHitTesting(isDrawingMode)
                .transition(.opacity)
                .accessibilityLabel("当前题目涂画区域")
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
            ) {
                toggleDrawingMode()
            }
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

            Button {
                drawingController.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .frame(width: 34, height: 34)
            }
            .disabled(!drawingController.canUndo)
            .accessibilityLabel("撤销上一笔")

            Button(role: .destructive) {
                drawingController.clear()
                annotationData = Data()
            } label: {
                Image(systemName: "trash")
                    .frame(width: 34, height: 34)
            }
            .disabled(!drawingController.hasDrawing)
            .accessibilityLabel("清空涂画")

            Button {
                toggleDrawingMode()
            } label: {
                Label("退出涂画", systemImage: "pencil.slash")
                    .font(.caption.weight(.semibold))
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
        withAnimation(animation) {
            isDrawingMode.toggle()
        }
    }

    private func markCurrentQuestionMastered() {
        saveCurrentAnnotation()
        withAnimation(.easeOut(duration: 0.2)) {
            viewModel.markMastered(true)
        }
        scrollPageID = viewModel.questions.isEmpty ? nil : viewModel.currentIndex
        cardOffset = .zero
    }

    private func loadCurrentAnnotation() {
        annotationData = viewModel.currentQuestion.map {
            qm.annotation(for: $0.questionId).drawingData
        } ?? Data()
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
    
    private var particleAnimationLayer: some View {
        ZStack {
            if showHeartAnimation {
                ForEach(heartParticles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .scaleEffect(particle.scale)
                        .opacity(particle.opacity)
                        .position(particle.position)
                        .blur(radius: 2)
                }
                
                Image(systemName: viewModel.currentQuestion.map { qm.isFavorite($0.questionId) } == true ? "star.fill" : "star.slash.fill")
                    .font(.system(size: 60))
                    .foregroundColor(viewModel.currentQuestion.map { qm.isFavorite($0.questionId) } == true ? .yellow : .secondary)
                    .scaleEffect(heartScale)
                    .opacity(heartScale > 0.3 ? 1.0 : 0.0)
            }
        }
        .allowsHitTesting(false)
    }
    
    private func triggerFavoriteAnimation() {
        viewModel.toggleFavorite()
        let isNowFavorite = viewModel.currentQuestion.map { qm.isFavorite($0.questionId) } == true
        
        showHeartAnimation = true
        heartScale = 0.0
        let screenWidth = screenBounds().width
        let screenHeight = screenBounds().height
        let centerX = screenWidth / 2
        let centerY = screenHeight / 2
        
        var particles: [HeartParticle] = []
        for i in 0..<8 {
            let angle = Double(i) * Double.pi / 4.0
            let distance: CGFloat = 60 + CGFloat.random(in: 20...50)
            let particle = HeartParticle(
                id: i,
                position: CGPoint(x: centerX, y: centerY),
                targetOffset: CGSize(
                    width: CGFloat(cos(angle)) * distance,
                    height: CGFloat(sin(angle)) * distance
                ),
                color: isNowFavorite ? [.yellow, .orange, themeColor, .pink].randomElement()! : [.gray, .secondary].randomElement()!,
                size: CGFloat.random(in: 6...12),
                opacity: 1.0,
                scale: 0.3
            )
            particles.append(particle)
        }
        heartParticles = particles
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            heartScale = 1.2
        }
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            for i in heartParticles.indices {
                heartParticles[i].position = CGPoint(
                    x: centerX + heartParticles[i].targetOffset.width,
                    y: centerY + heartParticles[i].targetOffset.height
                )
                heartParticles[i].opacity = 0.8
                heartParticles[i].scale = 1.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                heartScale = 1.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeOut(duration: 0.4)) {
                heartScale = 0.0
                for i in heartParticles.indices {
                    heartParticles[i].opacity = 0.0
                    heartParticles[i].scale = 0.2
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            showHeartAnimation = false
            heartParticles = []
        }
    }
    
    private var answerCardSheet: some View {
        NavigationStack {
            AnswerCardGridView(
                totalCount: viewModel.questions.count,
                currentIndex: viewModel.currentIndex,
                answeredIndices: Set(viewModel.questions.enumerated().compactMap { qm.isMastered($0.element.questionId) ? $0.offset : nil }),
                markedIndices: Set(viewModel.questions.enumerated().compactMap { !qm.annotation(for: $0.element.questionId).drawingData.isEmpty ? $0.offset : nil }),
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
}

struct MemorizeCardNoSwipe: View {
    let question: QuestionData
    let questionNumber: Int
    let showAnswer: Bool
    var showsCollectionSearch = false
    let themeColor: Color
    
    @StateObject private var qm = QuestionManager.shared
    @State private var selectedSearchText: SearchSelection?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 10) {
                Text("\(questionNumber)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundColor(.secondary)
                    .padding(.top, showsCollectionSearch ? 8 : 0)

                Spacer(minLength: 8)

                if showsCollectionSearch {
                    QuestionCollectionSearchControl(themeColor: themeColor)
                        .zIndex(2)
                }
            }
            
            Text(question.isTrueFalse ? "判断题" : "单选题")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(question.isTrueFalse ? Color.green : themeColor, in: RoundedRectangle(cornerRadius: 6))

            SelectableQuestionText(text: question.content, font: .systemFont(ofSize: 16, weight: .medium)) {
                selectedSearchText = SearchSelection(value: $0)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                memorizeOption(row: question.optionA, label: "A", correctAnswer: question.correctAnswer)
                memorizeOption(row: question.optionB, label: "B", correctAnswer: question.correctAnswer)
                if let c = question.optionC { memorizeOption(row: c, label: "C", correctAnswer: question.correctAnswer) }
                if let d = question.optionD { memorizeOption(row: d, label: "D", correctAnswer: question.correctAnswer) }
            }
        }
        .padding(20)
        .background {
            QuestionCardBackground(
                isFavorite: qm.isFavorite(question.questionId),
                cornerRadius: 20
            )
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
        .animation(.spring(response: 0.32, dampingFraction: 0.6), value: qm.isFavorite(question.questionId))
        .sheet(item: $selectedSearchText) { selection in
            QuestionCollectionSearchSheet(initialQuery: selection.value, themeColor: themeColor)
        }
    }
    
    private func memorizeOption(row: String?, label: String, correctAnswer: String) -> some View {
        Group {
            if let text = row {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: label == correctAnswer ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14))
                        .foregroundColor(label == correctAnswer ? .green : .secondary.opacity(0.5))
                        .padding(.top, 2)
                    
                    Text(text)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)
                    
                    if label == correctAnswer {
                        Text("正确")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.green)
                            .cornerRadius(6)
                            .fixedSize()
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(label == correctAnswer ? Color.green.opacity(0.08) : Color(.systemGray6))
                )
            }
        }
    }
}
