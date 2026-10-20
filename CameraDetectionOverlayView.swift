//
//  CameraDetectionOverlayView.swift
//  sbog
//

import UIKit

struct CameraBoxAnnotation {
    let rect: CGRect
    let titleArabic: String
    let isPrimary: Bool
    let labelOnTrailing: Bool
}

final class CameraDetectionOverlayView: UIView {
    var boxes: [CameraBoxAnnotation] = [] {
        didSet { setNeedsDisplay() }
    }

    private let dashPattern: [CGFloat] = [7, 5]
    private let primaryColor = UIColor(red: 0.22, green: 0.78, blue: 0.42, alpha: 1)
    private let secondaryColor = UIColor(red: 0.98, green: 0.78, blue: 0.18, alpha: 1)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        for box in boxes {
            drawDashedBox(box.rect, color: box.isPrimary ? primaryColor : secondaryColor)
            drawPillLabel(
                title: box.titleArabic,
                near: box.rect,
                color: box.isPrimary ? primaryColor : secondaryColor,
                showCheck: box.isPrimary,
                onTrailing: box.labelOnTrailing
            )
        }
    }

    private func drawDashedBox(_ box: CGRect, color: UIColor) {
        let path = UIBezierPath(roundedRect: box, cornerRadius: 10)
        path.lineWidth = 2.5
        path.setLineDash(dashPattern, count: dashPattern.count, phase: 0)
        color.setStroke()
        path.stroke()
    }

    private func drawPillLabel(
        title: String,
        near box: CGRect,
        color: UIColor,
        showCheck: Bool,
        onTrailing: Bool
    ) {
        let display = showCheck ? "✓ \(title)" : title
        let font = UIFont.systemFont(ofSize: 13, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white
        ]
        let textSize = (display as NSString).size(withAttributes: attributes)
        let hPad: CGFloat = 10
        let vPad: CGFloat = 5
        let pillW = textSize.width + hPad * 2
        let pillH = textSize.height + vPad * 2

        var pillX = onTrailing ? box.maxX - pillW : box.minX
        var pillY = box.minY - pillH - 4
        pillX = max(4, min(bounds.width - pillW - 4, pillX))
        pillY = max(4, pillY)
        if pillY + pillH > box.minY {
            pillY = box.minY + 6
        }

        let pillRect = CGRect(x: pillX, y: pillY, width: pillW, height: pillH)
        let pillPath = UIBezierPath(roundedRect: pillRect, cornerRadius: pillH / 2)
        color.setFill()
        pillPath.fill()

        (display as NSString).draw(
            in: pillRect.insetBy(dx: hPad, dy: vPad),
            withAttributes: attributes
        )
    }
}
