import SwiftUI

struct MindMapZoomRequest: Equatable {
    var id = UUID()
    var factor: CGFloat = 0
}

struct ZoomableMindMap: UIViewRepresentable {
    let map: CollectionMindMap
    let request: MindMapZoomRequest
    @Binding var zoom: Double
    private let canvasSize = CGSize(width: 1250, height: 1120)

    func makeCoordinator() -> Coordinator { Coordinator(zoom: $zoom, size: canvasSize) }
    func makeUIView(context: Context) -> MindMapScrollView {
        let scroll = MindMapScrollView()
        scroll.minimumZoomScale = 0.2
        scroll.maximumZoomScale = 3
        scroll.bouncesZoom = true
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.delegate = context.coordinator
        let host = UIHostingController(rootView: MindMapCanvas(map: map))
        host.view.backgroundColor = .clear
        host.view.frame = CGRect(origin: .zero, size: canvasSize)
        scroll.addSubview(host.view)
        scroll.contentSize = canvasSize
        context.coordinator.host = host
        context.coordinator.lastRequest = request.id
        scroll.onFirstLayout = { [weak scroll, weak coordinator = context.coordinator] in
            guard let scroll, let coordinator else { return }
            coordinator.fit(scroll)
        }
        return scroll
    }
    func updateUIView(_ scroll: MindMapScrollView, context: Context) {
        context.coordinator.host?.rootView = MindMapCanvas(map: map)
        context.coordinator.zoom = $zoom
        guard context.coordinator.lastRequest != request.id else { return }
        context.coordinator.lastRequest = request.id
        if request.factor == 0 { context.coordinator.fit(scroll) }
        else {
            let target = min(scroll.maximumZoomScale, max(scroll.minimumZoomScale, scroll.zoomScale * request.factor))
            let center = CGPoint(x: (scroll.contentOffset.x + scroll.bounds.width / 2) / scroll.zoomScale,
                                 y: (scroll.contentOffset.y + scroll.bounds.height / 2) / scroll.zoomScale)
            let rect = CGRect(x: center.x - scroll.bounds.width / target / 2, y: center.y - scroll.bounds.height / target / 2,
                              width: scroll.bounds.width / target, height: scroll.bounds.height / target)
            scroll.zoom(to: rect, animated: !UIAccessibility.isReduceMotionEnabled)
        }
    }
    final class Coordinator: NSObject, UIScrollViewDelegate {
        var host: UIHostingController<MindMapCanvas>?
        var zoom: Binding<Double>
        let size: CGSize
        var lastRequest: UUID?
        init(zoom: Binding<Double>, size: CGSize) { self.zoom = zoom; self.size = size }
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { host?.view }
        func scrollViewDidZoom(_ scroll: UIScrollView) {
            let scaled = CGSize(width: size.width * scroll.zoomScale, height: size.height * scroll.zoomScale)
            scroll.contentInset = UIEdgeInsets(top: max(0, (scroll.bounds.height - scaled.height) / 2), left: max(0, (scroll.bounds.width - scaled.width) / 2), bottom: 0, right: 0)
            let value = Double(scroll.zoomScale)
            DispatchQueue.main.async { [weak self] in self?.zoom.wrappedValue = value }
        }
        func fit(_ scroll: UIScrollView) {
            guard scroll.bounds.width > 0, scroll.bounds.height > 0 else { return }
            let scale = min(scroll.bounds.width / size.width, scroll.bounds.height / size.height) * 0.94
            scroll.setZoomScale(max(scroll.minimumZoomScale, scale), animated: false)
            scrollViewDidZoom(scroll)
            scroll.setContentOffset(CGPoint(x: -scroll.contentInset.left, y: -scroll.contentInset.top), animated: false)
        }
    }
}

final class MindMapScrollView: UIScrollView {
    var onFirstLayout: (() -> Void)?
    private var didLayout = false
    override func layoutSubviews() {
        super.layoutSubviews()
        if !didLayout, bounds.width > 0, bounds.height > 0 {
            didLayout = true
            onFirstLayout?()
        }
    }
}

struct MindMapCanvas: View {
    let map: CollectionMindMap
    private let colors: [Color] = [.blue, .teal, .purple, .orange, .pink]
    private func branchY(_ index: Int) -> CGFloat { 140 + CGFloat(index) * 205 }
    private var centerY: CGFloat { (branchY(0) + branchY(map.nodes.count - 1)) / 2 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, size in
                for index in map.nodes.indices {
                    let y = branchY(index)
                    drawLink(context: &context, start: CGPoint(x: 285, y: centerY), end: CGPoint(x: 455, y: y), color: colors[index])
                    for child in map.nodes[index].children.indices {
                        let childY = y + (map.nodes[index].children.count == 1 ? 0 : child == 0 ? -55 : 55)
                        drawLink(context: &context, start: CGPoint(x: 695, y: y), end: CGPoint(x: 840, y: childY), color: colors[index])
                    }
                }
            }.frame(width: 1250, height: 1120).accessibilityHidden(true)
            node(map.title, color: .indigo, width: 240, isRoot: true).position(x: 165, y: centerY)
            ForEach(map.nodes.indices, id: \.self) { index in
                let branch = map.nodes[index]
                let y = branchY(index)
                node(branch.title, color: colors[index], width: 240).position(x: 575, y: y)
                ForEach(branch.children.indices, id: \.self) { child in
                    node(branch.children[child], color: colors[index], width: 310)
                        .position(x: 995, y: y + (branch.children.count == 1 ? 0 : child == 0 ? -55 : 55))
                }
            }
        }.frame(width: 1250, height: 1120)
    }
    private func node(_ title: String, color: Color, width: CGFloat, isRoot: Bool = false) -> some View {
        Text(title).font(.system(size: isRoot ? 22 : 18, weight: isRoot ? .bold : .medium))
            .multilineTextAlignment(.center).foregroundStyle(isRoot ? Color.white : Color.primary)
            .padding(16).frame(width: width, height: 96)
            .background(isRoot ? color : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(color.opacity(isRoot ? 0 : 0.35), lineWidth: 2))
            .shadow(color: color.opacity(0.1), radius: 10, y: 3)
            .accessibilityLabel(title)
    }
    private func drawLink(context: inout GraphicsContext, start: CGPoint, end: CGPoint, color: Color) {
        var path = Path(); path.move(to: start)
        let mid = (start.x + end.x) / 2
        path.addCurve(to: end, control1: CGPoint(x: mid, y: start.y), control2: CGPoint(x: mid, y: end.y))
        context.stroke(path, with: .color(color.opacity(0.45)), lineWidth: 3)
    }
}
