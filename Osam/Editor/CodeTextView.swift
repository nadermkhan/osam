import UIKit
import SwiftUI

final class CodeTextView: UITextView {
    var language = Language.plainText
    var onTextChange: ((String) -> Void)?
    var onCursorChange: ((Int) -> Void)?
    var syntaxHighlighter: SyntaxHighlighter?
    var codeFont = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    var tabString = "    "

    private let bracketPairs: [Character: Character] = [
        "(": ")", "[": "]", "{": "}", "\"": "\"", "'": "'", "`": "`"
    ]
    private let closingBrackets: Set<Character> = [")", "]", "}", "\"", "'", "`"]
    private var highlightDebounceTimer: Timer?

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        autocorrectionType = .no
        autocapitalizationType = .none
        spellCheckingType = .no
        smartQuotesType = .no
        smartDashesType = .no
        smartInsertDeleteType = .no
        keyboardType = .asciiCapable
        keyboardAppearance = .dark
        backgroundColor = .clear
        textColor = UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1)
        font = codeFont
        tintColor = UIColor(red: 0.35, green: 0.65, blue: 0.95, alpha: 1)
        contentInset = UIEdgeInsets(top: 8, left: 50, bottom: 8, right: 8)
        textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 8)
    }

    func applyHighlighting() {
        guard let highlighter = syntaxHighlighter else { return }
        let selectedRange = self.selectedRange
        let attributed = highlighter.highlight(text, language: language, font: codeFont)
        let mutable = NSMutableAttributedString(attributedString: attributed)

        // Preserve paragraph style for line spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 3
        mutable.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: mutable.length))

        self.attributedText = mutable
        self.selectedRange = selectedRange
    }

    func scheduleHighlighting() {
        highlightDebounceTimer?.invalidate()
        highlightDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
            self?.applyHighlighting()
        }
    }

    func insertBracketPair(opening: Character) -> Bool {
        guard let closing = bracketPairs[opening] else { return false }

        // For quotes, check if we're not already inside a quote
        if opening == closing {
            let selectedRange = self.selectedRange
            let nsText = text as NSString
            // If cursor is right before the same character, just move past it
            if selectedRange.location < nsText.length {
                let nextChar = nsText.character(at: selectedRange.location)
                if nextChar == opening.asciiValue.map({ UInt16($0) }) ?? 0 {
                    self.selectedRange = NSRange(location: selectedRange.location + 1, length: 0)
                    return true
                }
            }
        }

        let selectedRange = self.selectedRange
        if selectedRange.length > 0 {
            // Wrap selection
            let selectedText = (text as NSString).substring(with: selectedRange)
            let replacement = "\(opening)\(selectedText)\(closing)"
            replaceCharacters(in: selectedRange, with: replacement)
            self.selectedRange = NSRange(location: selectedRange.location + 1, length: selectedText.count)
        } else {
            let replacement = "\(opening)\(closing)"
            replaceCharacters(in: selectedRange, with: replacement)
            self.selectedRange = NSRange(location: selectedRange.location + 1, length: 0)
        }
        return true
    }

    func handleNewline() {
        let nsText = text as NSString
        let cursorPos = selectedRange.location
        let indent = text.indentation(ofLineAt: max(0, cursorPos - 1))

        // Check if we need extra indentation (after { or ( or [)
        var extraIndent = ""
        if cursorPos > 0 {
            let prevChar = nsText.character(at: cursorPos - 1)
            if prevChar == Character("{").asciiValue.map({ UInt16($0) }) ?? 0 ||
               prevChar == Character("(").asciiValue.map({ UInt16($0) }) ?? 0 ||
               prevChar == Character("[").asciiValue.map({ UInt16($0) }) ?? 0 ||
               prevChar == Character(":").asciiValue.map({ UInt16($0) }) ?? 0 {
                extraIndent = tabString
            }
        }

        let replacement = "\n\(indent)\(extraIndent)"
        replaceCharacters(in: selectedRange, with: replacement)
        self.selectedRange = NSRange(location: cursorPos + replacement.count, length: 0)
    }

    private func replaceCharacters(in range: NSRange, with string: String) {
        let mutable = NSMutableString(string: text)
        mutable.replaceCharacters(in: range, with: string)
        text = mutable as String
        onTextChange?(text)
        scheduleHighlighting()
    }
}
