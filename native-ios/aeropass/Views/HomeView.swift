import SwiftUI
import Charts

struct HomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var qm = QuestionManager.shared
    
    @AppStorage("appThemeColor") private var themeColorName: String = AppTheme.blue.rawValue
    @AppStorage("userNickname") private var userNickname: String = "预备飞行员"
    @AppStorage("userAvatarData") private var userAvatarData: Data?
    
    var themeColor: Color {
        AppTheme(rawValue: themeColorName)?.color ?? AppTheme.blue.color
    }
    
    var currentTheme: AppTheme {
        AppTheme(rawValue: themeColorName) ?? AppTheme.blue
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        userInfoHeaderSection
                        coreTrainingSection
                        
                        StatsDashboardView(
                            totalQuestions: qm.totalCount,
                            masteredCount: qm.masteredIds.count,
                            wrongCount: qm.wrongIds.count,
                            themeColor: themeColor,
                            dailyActivity: last7DaysActivity
                        )
                    }
                    .padding(.bottom, 30)
                }
                
                if colorScheme == .dark {
                    coneSpotlight(themeColor: themeColor, screenHeight: screenBounds().height)
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private var userInfoHeaderSection: some View {
        HStack(spacing: 16) {
            if let data = userAvatarData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 54, height: 54)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(themeColor.opacity(0.4), lineWidth: 2))
                    .shadow(color: themeColor.opacity(0.2), radius: 6, x: 0, y: 3)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 54, height: 54)
                    .foregroundStyle(themeColor.gradient)
                    .shadow(color: themeColor.opacity(0.3), radius: 6, x: 0, y: 3)
            }
            
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 4) {
                    Text("\(String(localized: "你好"))，\(displayNickname)")
                        .font(.title3.bold())
                    Text(currentTheme.emoji)
                }
                Text(LocalizedStringKey(timeGreeting))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }

    private var displayNickname: String {
        userNickname == "预备飞行员" ? String(localized: "预备飞行员") : userNickname
    }
    
    private var timeGreeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<9: return "早上好"
        case 9..<12: return "上午好"
        case 12..<18: return "下午好"
        default: return "晚上好"
        }
    }

    private var practicedCount: Int {
        qm.records.values.filter { $0.attempts > 0 }.count
    }

    private var trainingProgress: Double {
        guard qm.totalCount > 0 else { return 0 }
        return min(1, Double(practicedCount) / Double(qm.totalCount))
    }

    /// 近 7 天每天练习过的题目数（今天在末位）
    private var last7DaysActivity: [DailyStudyPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let weekdaySymbols = ["日", "一", "二", "三", "四", "五", "六"]
        return (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: offset - 6, to: today) ?? today
            let count = qm.studyCount(on: day)
            let label = offset == 6
                ? "今天"
                : "周\(weekdaySymbols[calendar.component(.weekday, from: day) - 1])"
            return DailyStudyPoint(id: offset, label: label, count: count)
        }
    }

    private var coreTrainingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("核心训练")
                    .font(.title3.bold())
                Spacer()
                Text("题库共 \(qm.totalCount) 题")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            NavigationLink(destination: PracticeView(mode: .sequential)) {
                TrainingHeroCard(
                    title: String(localized: "刷题模式"),
                    subtitle: String(localized: "按节奏完成专项训练"),
                    icon: "doc.text.below.ecg.fill",
                    tint: themeColor,
                    footer: String(localized: "已练 \(practicedCount) 题 · 共 \(qm.totalCount) 题"),
                    progress: trainingProgress
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal)

            HStack(spacing: 14) {
                NavigationLink(destination: MemorizeView()) {
                    TrainingGridCard(
                        title: String(localized: "背题模式"),
                        subtitle: String(localized: "快速浏览并标记掌握"),
                        icon: "brain.head.profile.fill",
                        tint: currentTheme.palette.first ?? .indigo,
                        badge: String(localized: "\(qm.masteredIds.count) 题已掌握")
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: MockExamView()) {
                    TrainingGridCard(
                        title: String(localized: "模拟考试"),
                        subtitle: String(localized: "计时组卷，还原考试节奏"),
                        icon: "stopwatch.fill",
                        tint: Color(hex: "#FF5E62"),
                        badge: String(localized: "\(qm.examRecords.count) 次记录")
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
        }
    }
}

private struct TrainingHeroCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let footer: String
    let progress: Double

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(colors: [tint, tint.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing))

            Circle()
                .fill(.white.opacity(0.12))
                .frame(width: 150, height: 150)
                .offset(x: 52, y: -46)
                .blur(radius: 4)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.22))
                            .frame(width: 48, height: 48)
                        Image(systemName: icon)
                            .font(.system(size: 21, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Spacer(minLength: 12)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(tint)
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.92), in: Circle())
                }

                Spacer(minLength: 4)

                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.86))

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(footer)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer(minLength: 8)
                        Text("\(Int(progress * 100))%")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.25))
                            Capsule()
                                .fill(.white)
                                .frame(width: geo.size.width * min(max(progress, 0), 1))
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
        .frame(height: 186)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: tint.opacity(0.28), radius: 16, x: 0, y: 8)
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)，\(subtitle)，\(footer)")
    }
}

private struct TrainingGridCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let badge: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.14))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(tint)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 2)

            Text(LocalizedStringKey(title))
                .font(.headline)
                .foregroundColor(.primary)
            Text(LocalizedStringKey(subtitle))
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)
            Text(LocalizedStringKey(badge))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(tint.opacity(0.12), in: Capsule())
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 168, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(tint.opacity(0.14), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)，\(subtitle)，\(badge)")
    }
}

struct DailyStudyPoint: Identifiable {
    let id: Int
    let label: String
    let count: Int
}

struct StatsDashboardView: View {
    var totalQuestions: Int
    var masteredCount: Int
    var wrongCount: Int
    var themeColor: Color
    var dailyActivity: [DailyStudyPoint] = []
    
    var correctRate: Double {
        guard totalQuestions > 0 else { return 0 }
        return Double(masteredCount) / Double(totalQuestions)
    }

    private var recentStudyCount: Int {
        dailyActivity.reduce(0, { $0 + $1.count })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("学习概览")
                    .font(.headline)
                Spacer()
                Text("通关率预测")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.1), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: correctRate)
                        .stroke(themeColor.gradient, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.8), value: correctRate)
                    
                    VStack {
                        Text("\(Int(correctRate * 100))%")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(themeColor)
                        Text("正确率")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 90, height: 90)
                .shadow(color: themeColor.opacity(0.15), radius: 8, x: 0, y: 4)
                
                VStack(spacing: 10) {
                    MiniStatRow(title: "总题数", value: "\(totalQuestions)", icon: "list.bullet", color: themeColor)
                    MiniStatRow(title: "已熟记", value: "\(masteredCount)", icon: "checkmark.seal.fill", color: .green)
                    MiniStatRow(title: "错题数", value: "\(wrongCount)", icon: "exclamationmark.triangle.fill", color: .red)
                }
            }
            
            Divider()
            
            VStack(spacing: 14) {
                ProgressBarRow(label: "记忆进度", current: masteredCount, total: totalQuestions, color: themeColor)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("近期趋势")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("近7天练了 \(recentStudyCount) 题")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if recentStudyCount > 0 {
                    Chart {
                        ForEach(dailyActivity) { point in
                            LineMark(
                                x: .value("天", point.label),
                                y: .value("道", point.count)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(themeColor.gradient)

                            AreaMark(
                                x: .value("天", point.label),
                                y: .value("道", point.count)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(LinearGradient(colors: [themeColor.opacity(0.15), themeColor.opacity(0)], startPoint: .top, endPoint: .bottom))
                        }
                    }
                    .frame(height: 70)
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.xyaxis.line")
                        Text("最近 7 天暂无练习记录")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 70, alignment: .center)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 14, x: 0, y: 7)
        )
        .padding(.horizontal)
    }
}

struct MiniStatRow: View {
    var title: String
    var value: String
    var icon: String
    var color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
                .frame(width: 24, height: 24)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            Text(LocalizedStringKey(title))
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .bold()
        }
    }
}

struct ProgressBarRow: View {
    var label: String
    var current: Int
    var total: Int
    var color: Color
    
    var progress: Double {
        total > 0 ? Double(current) / Double(total) : 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(LocalizedStringKey(label))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(current)/\(total)")
                    .font(.caption.monospaced())
                    .foregroundColor(.primary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.12))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.gradient)
                        .frame(width: geometry.size.width * CGFloat(progress), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}
