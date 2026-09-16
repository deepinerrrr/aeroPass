import SwiftUI
import UIKit

struct SearchSelection: Identifiable {
    let id = UUID()
    let value: String
}

/// 保留系统的长按选词、拖动选区和复制菜单，并增加用选中文字搜索题目的动作。
struct SelectableQuestionText: UIViewRepresentable {
    let text: String
    let font: UIFont
    let onSearch: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onSearch: onSearch) }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.isEditable = false
        view.isSelectable = true
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.adjustsFontForContentSizeCategory = true
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.onSearch = onSearch
        if view.text != text { view.text = text }
        view.font = font
        view.textColor = .label
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? 300
        return uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var onSearch: (String) -> Void
        init(onSearch: @escaping (String) -> Void) { self.onSearch = onSearch }

        func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
            guard let text = textView.text as NSString?, range.location != NSNotFound,
                  NSMaxRange(range) <= text.length else { return nil }
            let selected = text.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !selected.isEmpty else { return nil }
            let search = UIAction(title: String(localized: "搜索题目并建合集"), image: UIImage(systemName: "magnifyingglass")) { [weak self] _ in
                self?.onSearch(selected)
            }
            return UIMenu(children: [search] + suggestedActions)
        }
    }
}
