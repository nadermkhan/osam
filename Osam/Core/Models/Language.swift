import Foundation
import SwiftUI

enum Language: String, CaseIterable, Codable {
    case php
    case html
    case css
    case javascript
    case json
    case markdown
    case plainText

    static func detect(from ext: String) -> Language {
        switch ext.lowercased() {
        case "php", "phtml", "php3", "php4", "php5", "phps": return .php
        case "html", "htm", "xhtml", "shtml": return .html
        case "css", "scss", "less": return .css
        case "js", "jsx", "mjs", "cjs": return .javascript
        case "json", "jsonl": return .json
        case "md", "markdown", "mdown": return .markdown
        default: return .plainText
        }
    }

    var displayName: String {
        switch self {
        case .php: return "PHP"
        case .html: return "HTML"
        case .css: return "CSS"
        case .javascript: return "JavaScript"
        case .json: return "JSON"
        case .markdown: return "Markdown"
        case .plainText: return "Text"
        }
    }
}
