import Foundation
import UIKit

final class SyntaxHighlighter {

    struct Theme {
        let keyword: UIColor
        let string: UIColor
        let comment: UIColor
        let number: UIColor
        let tag: UIColor
        let attribute: UIColor
        let variable: UIColor
        let function: UIColor
        let type: UIColor
        let plain: UIColor
        let background: UIColor

        static let dark = Theme(
            keyword: UIColor(red: 0.78, green: 0.46, blue: 0.86, alpha: 1),     // purple
            string: UIColor(red: 0.90, green: 0.56, blue: 0.40, alpha: 1),      // orange
            comment: UIColor(red: 0.45, green: 0.50, blue: 0.55, alpha: 1),     // gray
            number: UIColor(red: 0.82, green: 0.75, blue: 0.50, alpha: 1),      // yellow
            tag: UIColor(red: 0.40, green: 0.72, blue: 0.90, alpha: 1),         // blue
            attribute: UIColor(red: 0.55, green: 0.82, blue: 0.60, alpha: 1),   // green
            variable: UIColor(red: 0.90, green: 0.40, blue: 0.45, alpha: 1),    // red
            function: UIColor(red: 0.40, green: 0.80, blue: 0.85, alpha: 1),    // teal
            type: UIColor(red: 0.55, green: 0.82, blue: 0.60, alpha: 1),        // green
            plain: UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1),       // light gray
            background: UIColor(red: 0.11, green: 0.12, blue: 0.14, alpha: 1)   // dark bg
        )

        static let light = Theme(
            keyword: UIColor(red: 0.60, green: 0.20, blue: 0.70, alpha: 1),
            string: UIColor(red: 0.75, green: 0.30, blue: 0.10, alpha: 1),
            comment: UIColor(red: 0.45, green: 0.50, blue: 0.45, alpha: 1),
            number: UIColor(red: 0.10, green: 0.40, blue: 0.70, alpha: 1),
            tag: UIColor(red: 0.10, green: 0.30, blue: 0.70, alpha: 1),
            attribute: UIColor(red: 0.30, green: 0.55, blue: 0.15, alpha: 1),
            variable: UIColor(red: 0.70, green: 0.15, blue: 0.15, alpha: 1),
            function: UIColor(red: 0.10, green: 0.50, blue: 0.55, alpha: 1),
            type: UIColor(red: 0.20, green: 0.55, blue: 0.20, alpha: 1),
            plain: UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1),
            background: UIColor.white
        )
    }

    private let theme: Theme

    init(theme: Theme = .dark) {
        self.theme = theme
    }

    func highlight(_ text: String, language: Language, font: UIFont) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: text, attributes: [
            .foregroundColor: theme.plain,
            .font: font
        ])

        let fullRange = NSRange(location: 0, length: (text as NSString).length)

        switch language {
        case .php: highlightPHP(attributed, range: fullRange)
        case .html: highlightHTML(attributed, range: fullRange)
        case .css: highlightCSS(attributed, range: fullRange)
        case .javascript: highlightJavaScript(attributed, range: fullRange)
        case .json: highlightJSON(attributed, range: fullRange)
        case .markdown: highlightMarkdown(attributed, range: fullRange)
        case .plainText: break
        }

        return attributed
    }

    // MARK: - PHP

    private func highlightPHP(_ attr: NSMutableAttributedString, range: NSRange) {
        let text = attr.string

        // Comments
        applyPattern(attr, text: text, pattern: "//[^\n]*", color: theme.comment, range: range)
        applyPattern(attr, text: text, pattern: "#[^\n]*", color: theme.comment, range: range)
        applyPattern(attr, text: text, pattern: "/\\*[\\s\\S]*?\\*/", color: theme.comment, range: range)

        // Strings
        applyPattern(attr, text: text, pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", color: theme.string, range: range)
        applyPattern(attr, text: text, pattern: "'(?:[^'\\\\]|\\\\.)*'", color: theme.string, range: range)

        // Variables
        applyPattern(attr, text: text, pattern: "\\$[a-zA-Z_][a-zA-Z0-9_]*", color: theme.variable, range: range)

        // Numbers
        applyPattern(attr, text: text, pattern: "\\b\\d+\\.?\\d*\\b", color: theme.number, range: range)

        // Keywords
        let phpKeywords = "abstract|and|array|as|break|case|catch|class|clone|const|continue|declare|default|do|echo|else|elseif|empty|enddeclare|endfor|endforeach|endif|endswitch|endwhile|eval|exit|extends|final|finally|fn|for|foreach|function|global|goto|if|implements|include|include_once|instanceof|insteadof|interface|isset|list|match|namespace|new|or|print|private|protected|public|readonly|require|require_once|return|static|switch|throw|trait|try|unset|use|var|while|xor|yield"
        applyPattern(attr, text: text, pattern: "\\b(\(phpKeywords))\\b", color: theme.keyword, range: range)

        // PHP tags
        applyPattern(attr, text: text, pattern: "<\\?php|\\?>|<\\?=", color: theme.tag, range: range)

        // Functions
        applyPattern(attr, text: text, pattern: "\\b([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\(", color: theme.function, range: range)
    }

    // MARK: - HTML

    private func highlightHTML(_ attr: NSMutableAttributedString, range: NSRange) {
        let text = attr.string

        // Comments
        applyPattern(attr, text: text, pattern: "<!--[\\s\\S]*?-->", color: theme.comment, range: range)

        // Tags
        applyPattern(attr, text: text, pattern: "</?[a-zA-Z][a-zA-Z0-9]*", color: theme.tag, range: range)
        applyPattern(attr, text: text, pattern: "/?>", color: theme.tag, range: range)

        // Attributes
        applyPattern(attr, text: text, pattern: "\\b[a-zA-Z-]+(?=\\s*=)", color: theme.attribute, range: range)

        // Strings in attributes
        applyPattern(attr, text: text, pattern: "\"[^\"]*\"", color: theme.string, range: range)
        applyPattern(attr, text: text, pattern: "'[^']*'", color: theme.string, range: range)

        // Inline PHP
        highlightPHP(attr, range: range)
    }

    // MARK: - CSS

    private func highlightCSS(_ attr: NSMutableAttributedString, range: NSRange) {
        let text = attr.string

        // Comments
        applyPattern(attr, text: text, pattern: "/\\*[\\s\\S]*?\\*/", color: theme.comment, range: range)

        // Selectors (simplified)
        applyPattern(attr, text: text, pattern: "[.#][a-zA-Z_-][a-zA-Z0-9_-]*", color: theme.variable, range: range)

        // Properties
        applyPattern(attr, text: text, pattern: "\\b[a-zA-Z-]+(?=\\s*:)", color: theme.attribute, range: range)

        // Values: strings
        applyPattern(attr, text: text, pattern: "\"[^\"]*\"", color: theme.string, range: range)
        applyPattern(attr, text: text, pattern: "'[^']*'", color: theme.string, range: range)

        // Numbers with units
        applyPattern(attr, text: text, pattern: "\\b\\d+\\.?\\d*(px|em|rem|%|vh|vw|s|ms|deg|fr)?\\b", color: theme.number, range: range)

        // Colors
        applyPattern(attr, text: text, pattern: "#[0-9a-fA-F]{3,8}\\b", color: theme.number, range: range)

        // At-rules
        applyPattern(attr, text: text, pattern: "@[a-zA-Z-]+", color: theme.keyword, range: range)

        // Keywords
        let cssKeywords = "important|inherit|initial|unset|none|auto|block|inline|flex|grid|relative|absolute|fixed|sticky|hidden|visible|solid|dashed|dotted"
        applyPattern(attr, text: text, pattern: "\\b(\(cssKeywords))\\b", color: theme.keyword, range: range)
    }

    // MARK: - JavaScript

    private func highlightJavaScript(_ attr: NSMutableAttributedString, range: NSRange) {
        let text = attr.string

        // Comments
        applyPattern(attr, text: text, pattern: "//[^\n]*", color: theme.comment, range: range)
        applyPattern(attr, text: text, pattern: "/\\*[\\s\\S]*?\\*/", color: theme.comment, range: range)

        // Strings
        applyPattern(attr, text: text, pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", color: theme.string, range: range)
        applyPattern(attr, text: text, pattern: "'(?:[^'\\\\]|\\\\.)*'", color: theme.string, range: range)
        applyPattern(attr, text: text, pattern: "`(?:[^`\\\\]|\\\\.)*`", color: theme.string, range: range)

        // Numbers
        applyPattern(attr, text: text, pattern: "\\b\\d+\\.?\\d*\\b", color: theme.number, range: range)

        // Keywords
        let jsKeywords = "abstract|arguments|async|await|boolean|break|byte|case|catch|char|class|const|continue|debugger|default|delete|do|double|else|enum|eval|export|extends|false|final|finally|float|for|from|function|goto|if|implements|import|in|instanceof|int|interface|let|long|native|new|null|of|package|private|protected|public|return|short|static|super|switch|synchronized|this|throw|throws|transient|true|try|typeof|undefined|var|void|volatile|while|with|yield"
        applyPattern(attr, text: text, pattern: "\\b(\(jsKeywords))\\b", color: theme.keyword, range: range)

        // Functions
        applyPattern(attr, text: text, pattern: "\\b([a-zA-Z_$][a-zA-Z0-9_$]*)\\s*\\(", color: theme.function, range: range)
    }

    // MARK: - JSON

    private func highlightJSON(_ attr: NSMutableAttributedString, range: NSRange) {
        let text = attr.string

        // Keys
        applyPattern(attr, text: text, pattern: "\"[^\"]*\"\\s*:", color: theme.attribute, range: range)

        // String values
        applyPattern(attr, text: text, pattern: ":\\s*\"[^\"]*\"", color: theme.string, range: range)

        // Numbers
        applyPattern(attr, text: text, pattern: ":\\s*-?\\d+\\.?\\d*", color: theme.number, range: range)

        // Booleans / null
        applyPattern(attr, text: text, pattern: "\\b(true|false|null)\\b", color: theme.keyword, range: range)
    }

    // MARK: - Markdown

    private func highlightMarkdown(_ attr: NSMutableAttributedString, range: NSRange) {
        let text = attr.string

        // Headers
        applyPattern(attr, text: text, pattern: "^#{1,6}\\s.*$", color: theme.keyword, range: range, options: [.anchorsMatchLines])

        // Bold
        applyPattern(attr, text: text, pattern: "\\*\\*[^*]+\\*\\*", color: theme.tag, range: range)
        applyPattern(attr, text: text, pattern: "__[^_]+__", color: theme.tag, range: range)

        // Italic
        applyPattern(attr, text: text, pattern: "\\*[^*]+\\*", color: theme.attribute, range: range)
        applyPattern(attr, text: text, pattern: "_[^_]+_", color: theme.attribute, range: range)

        // Code
        applyPattern(attr, text: text, pattern: "```[\\s\\S]*?```", color: theme.string, range: range)
        applyPattern(attr, text: text, pattern: "`[^`]+`", color: theme.string, range: range)

        // Links
        applyPattern(attr, text: text, pattern: "\\[([^\\]]+)\\]\\(([^)]+)\\)", color: theme.function, range: range)

        // Lists
        applyPattern(attr, text: text, pattern: "^\\s*[-*+]\\s", color: theme.variable, range: range, options: [.anchorsMatchLines])
        applyPattern(attr, text: text, pattern: "^\\s*\\d+\\.\\s", color: theme.variable, range: range, options: [.anchorsMatchLines])
    }

    // MARK: - Helpers

    private func applyPattern(_ attr: NSMutableAttributedString, text: String, pattern: String, color: UIColor, range: NSRange, options: NSRegularExpression.Options = []) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        let matches = regex.matches(in: text, options: [], range: range)
        for match in matches {
            attr.addAttribute(.foregroundColor, value: color, range: match.range)
        }
    }
}
