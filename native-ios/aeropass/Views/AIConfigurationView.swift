import SwiftUI

struct AIConfigurationView: View {
    @AppStorage("currentAIModel") private var currentModel = AIProvider.qwen.rawValue
    @AppStorage("aiTemperature") private var temperature = 0.7
    @AppStorage("aiMaxTokens") private var maxTokens = 2000
    @AppStorage("aiSystemPrompt") private var systemPrompt = "你是执照考试的专业辅导老师。请详细解释正确答案、分析各选项，并提供知识拓展与通俗记忆方法。"

    var body: some View {
        Form {
            Section("默认模型") {
                Picker("AI 模型", selection: $currentModel) {
                    ForEach(AIProvider.allCases) { provider in
                        HStack(spacing: 8) {
                            AIProviderLogoView(provider: provider)
                            Text(provider.name)
                        }
                        .tag(provider.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            ForEach(AIProvider.allCases) { provider in
                ProviderKeySection(provider: provider)
            }

            Section {
                LabeledContent("温度", value: temperature.formatted(.number.precision(.fractionLength(1))))
                Slider(value: $temperature, in: 0...1.5, step: 0.1)
                Stepper("最大输出：\(maxTokens) tokens", value: $maxTokens, in: 256...8192, step: 256)
                TextEditor(text: $systemPrompt)
                    .frame(minHeight: 150)
                    .accessibilityLabel("系统提示词")
            } header: {
                Text("生成参数")
            } footer: {
                Text("API Key 保存在本机钥匙串中。温度越高，回答越发散。Qwen 和 DeepSeek 均关闭思考模式，直接流式输出回答。")
            }
        }
        .navigationTitle("大模型配置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ProviderKeySection: View {
    let provider: AIProvider
    @Environment(\.openURL) private var openURL
    @State private var key = ""
    @State private var revealKey = false
    @State private var saved = false
    @State private var saveError: String?
    @State private var modelName = ""

    var body: some View {
        Section(provider.name) {
            TextField("模型名称", text: $modelName)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .onChange(of: modelName) { _, value in
                    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { UserDefaults.standard.set(trimmed, forKey: "\(provider.rawValue)ModelName") }
                    else { UserDefaults.standard.removeObject(forKey: "\(provider.rawValue)ModelName") }
                }
            HStack {
                Group {
                    if revealKey {
                        TextField("请输入 API Key", text: $key)
                    } else {
                        SecureField("请输入 API Key", text: $key)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                Button { revealKey.toggle() } label: {
                    Image(systemName: revealKey ? "eye.slash" : "eye")
                }
                .accessibilityLabel(revealKey ? "隐藏密钥" : "显示密钥")
            }
            Button {
                saved = KeychainStore.set(key.trimmingCharacters(in: .whitespacesAndNewlines), for: provider.keychainKey)
                saveError = saved ? nil : "密钥保存失败，请重新尝试"
            } label: {
                Label("保存密钥", systemImage: "key.fill")
            }
            if let saveError { Text(LocalizedStringKey(saveError)).foregroundStyle(.red) }
            if saved { Label("已保存", systemImage: "checkmark.circle").foregroundStyle(.green) }
            Button {
                openURL(provider.applicationURL)
            } label: {
                Label("前往 \(provider.name) 平台申请 API Key", systemImage: "arrow.up.right.square")
            }
        }
        .onAppear { key = KeychainStore.string(for: provider.keychainKey); modelName = provider.model }
        .onChange(of: key) { _, _ in saved = false }
    }
}
