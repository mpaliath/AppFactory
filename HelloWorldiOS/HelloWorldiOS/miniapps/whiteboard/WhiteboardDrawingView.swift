import UIKit

final class WhiteboardDrawingView: UIView {
    var currentColor: UIColor = .black
    var onLongPress: (() -> Void)?

    private var strokes: [WhiteboardStroke] = []
    private var activeStroke: WhiteboardStroke?
    private let baseLineWidth: CGFloat = 5
    private let gestureDelegate = WhiteboardDrawingGestureDelegate()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        UIColor.white.setFill()
        UIRectFill(bounds)

        strokes.forEach(drawStroke)
        activeStroke.map(drawStroke)
    }

    func clear() {
        strokes.removeAll()
        activeStroke = nil
        setNeedsDisplay()
    }

    private func configureView() {
        backgroundColor = .white
        isOpaque = true
        isMultipleTouchEnabled = true

        let drawPan = UIPanGestureRecognizer(target: self, action: #selector(handleDrawPan(_:)))
        drawPan.minimumNumberOfTouches = 1
        drawPan.maximumNumberOfTouches = 1
        drawPan.cancelsTouchesInView = false
        drawPan.delegate = gestureDelegate
        addGestureRecognizer(drawPan)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.45
        longPress.cancelsTouchesInView = false
        longPress.delegate = gestureDelegate
        addGestureRecognizer(longPress)
    }

    private func beginStroke(at point: CGPoint) {
        activeStroke = WhiteboardStroke(points: [point], color: currentColor, lineWidth: baseLineWidth)
        setNeedsDisplay()
    }

    private func appendPoint(_ point: CGPoint) {
        activeStroke?.points.append(point)
        setNeedsDisplay()
    }

    private func finishActiveStroke(with finalPoint: CGPoint?) {
        guard var stroke = activeStroke else { return }

        if let finalPoint, stroke.points.last != finalPoint {
            stroke.points.append(finalPoint)
        }

        strokes.append(stroke)
        activeStroke = nil
        setNeedsDisplay()
    }

    private func drawStroke(_ stroke: WhiteboardStroke) {
        guard let firstPoint = stroke.points.first else { return }

        let path = UIBezierPath()
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.lineWidth = stroke.lineWidth
        path.move(to: firstPoint)

        if stroke.points.count == 1 {
            path.addLine(to: CGPoint(x: firstPoint.x + 0.1, y: firstPoint.y + 0.1))
        } else {
            stroke.points.dropFirst().forEach { path.addLine(to: $0) }
        }

        stroke.color.setStroke()
        path.stroke()
    }

    @objc private func handleDrawPan(_ recognizer: UIPanGestureRecognizer) {
        let point = recognizer.location(in: self)

        switch recognizer.state {
        case .began:
            beginStroke(at: point)
        case .changed:
            appendPoint(point)
        case .ended, .cancelled, .failed:
            finishActiveStroke(with: point)
        default:
            break
        }
    }

    @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        onLongPress?()
    }
}

private final class WhiteboardDrawingGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        otherGestureRecognizer.view is UIScrollView
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        touch.type == .direct || touch.type == .pencil
    }
}
