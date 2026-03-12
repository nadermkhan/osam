import UIKit

final class LineNumberGutter: UIView {
    weak var textView: UITextView?
    var font: UIFont = .monospacedSystemFont(ofSize: 12, weight: .regular)
    var textColor: UIColor = UIColor(red: 0.45, green: 0.48, blue: 0.52, alpha: 1)
    var backgroundColor2: UIColor = UIColor(red: 0.13, green: 0.14, blue: 0.16, alpha: 1)
    var gutterWidth: CGFloat = 46

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(),
              let textView = textView else { return }

        context.setFillColor(backgroundColor2.cgColor)
        context.fill(rect)

        // Draw separator
        context.setStrokeColor(UIColor(red: 0.2, green: 0.21, blue: 0.23, alpha: 1).cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: gutterWidth - 0.5, y: 0))
        context.addLine(to: CGPoint(x: gutterWidth - 0.5, y: rect.height))
        context.strokePath()

        let text = textView.text ?? ""
        let nsText = text as NSString
        let layoutManager = textView.layoutManager
        let textContainer = textView.textContainer
        let contentOffset = textView.contentOffset

        let visibleRect = CGRect(
            x: 0,
            y: contentOffset.y,
            width: textView.bounds.width,
            height: textView.bounds.height
        )

        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        var lineNumber = 1
        // Count newlines before visible range
        let prefixRange = NSRange(location: 0, length: min(charRange.location, nsText.length))
        if prefixRange.length > 0 {
            lineNumber += nsText.substring(with: prefixRange).filter { $0 == "\n" }.count
        }

        var index = charRange.location
        while index < NSMaxRange(charRange) && index < nsText.length {
            let lineRange = nsText.lineRange(for: NSRange(location: index, length: 0))

            let glyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
            var lineRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            lineRect.origin.y += textView.textContainerInset.top - contentOffset.y

            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor
            ]
            let numberString = "\(lineNumber)" as NSString
            let size = numberString.size(withAttributes: attrs)
            let drawPoint = CGPoint(
                x: gutterWidth - size.width - 8,
                y: lineRect.origin.y + (lineRect.height - size.height) / 2
            )
            numberString.draw(at: drawPoint, withAttributes: attrs)

            lineNumber += 1
            index = NSMaxRange(lineRange)
        }
    }

    func update() {
        setNeedsDisplay()
    }
}
