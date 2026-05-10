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

        let scaledWidth = coordinator.canvasSize.width * scrollView.zoomScale
        let scaledHeight = coordinator.canvasSize.height * scrollView.zoomScale
        let x = max((scaledWidth - scrollView.bounds.width) / 2, 0)
        let y = max((scaledHeight - scrollView.bounds.height) / 2, 0)
        scrollView.setContentOffset(CGPoint(x: x, y: y), animated: false)
        coordinator.didSetInitialOffset = true
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        let canvasSize = CGSize(width: 12_000, height: 12_000)
        weak var drawingView: WhiteboardDrawingView?
        var didSetInitialOffset = false

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            drawingView
        }
    }
}
