import SwiftUI
import UIKit

struct InfiniteWhiteboardCanvas: UIViewRepresentable {
    @Binding var selectedColor: Color
    @Binding var shouldClear: Bool
    let onLongPress: () -> Void

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .white
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 0.25
        scrollView.maximumZoomScale = 5
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.panGestureRecognizer.minimumNumberOfTouches = 2
        scrollView.contentSize = context.coordinator.canvasSize

        let drawingView = WhiteboardDrawingView(frame: CGRect(origin: .zero, size: context.coordinator.canvasSize))
        drawingView.currentColor = UIColor(selectedColor)
        drawingView.onLongPress = onLongPress
        scrollView.addSubview(drawingView)
        context.coordinator.drawingView = drawingView

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.drawingView?.currentColor = UIColor(selectedColor)
        context.coordinator.drawingView?.onLongPress = onLongPress

        if shouldClear {
            context.coordinator.drawingView?.clear()
            DispatchQueue.main.async {
                shouldClear = false
            }
        }

        centerCanvasIfNeeded(in: scrollView, coordinator: context.coordinator)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func centerCanvasIfNeeded(in scrollView: UIScrollView, coordinator: Coordinator) {
        guard !coordinator.didSetInitialOffset, scrollView.bounds.size != .zero else { return }

        let scaledWidth = coordinator.contentSize.width * scrollView.zoomScale
        let scaledHeight = coordinator.contentSize.height * scrollView.zoomScale
        let x = max((scaledWidth - scrollView.bounds.width) / 2, 0)
        let y = max((scaledHeight - scrollView.bounds.height) / 2, 0)
        scrollView.setContentOffset(CGPoint(x: x, y: y), animated: false)
        coordinator.didSetInitialOffset = true
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        private static let initialCanvasSize = CGSize(width: 12_000, height: 12_000)
        private let edgeExpansionThreshold: CGFloat = 1_500
        private let expansionAmount: CGFloat = 6_000

        weak var drawingView: WhiteboardDrawingView?
        var didSetInitialOffset = false
        var contentSize: CGSize

        var canvasSize: CGSize {
            contentSize
        }

        override init() {
            contentSize = Self.initialCanvasSize
            super.init()
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            drawingView
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            expandCanvasIfNeeded(in: scrollView)
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            expandCanvasIfNeeded(in: scrollView)
        }

        private func expandCanvasIfNeeded(in scrollView: UIScrollView) {
            guard let drawingView else { return }

            var originOffset = CGPoint.zero
            var newSize = contentSize
            var newContentOffset = scrollView.contentOffset
            let visibleSize = scrollView.bounds.size
            let zoomScale = max(scrollView.zoomScale, 0.001)
            let threshold = edgeExpansionThreshold * zoomScale
            let expansion = expansionAmount * zoomScale

            if newContentOffset.x < threshold {
                newSize.width += expansionAmount
                originOffset.x += expansionAmount
                newContentOffset.x += expansion
            }

            if newContentOffset.y < threshold {
                newSize.height += expansionAmount
                originOffset.y += expansionAmount
                newContentOffset.y += expansion
            }

            if newContentOffset.x + visibleSize.width > (contentSize.width * zoomScale) - threshold {
                newSize.width += expansionAmount
            }

            if newContentOffset.y + visibleSize.height > (contentSize.height * zoomScale) - threshold {
                newSize.height += expansionAmount
            }

            guard newSize != contentSize else { return }

            contentSize = newSize
            scrollView.contentSize = newSize
            drawingView.frame = CGRect(origin: .zero, size: newSize)
            drawingView.translateDrawing(by: originOffset)
            scrollView.contentOffset = newContentOffset
        }
    }
}
