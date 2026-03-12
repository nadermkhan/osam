import Foundation

final class AutocompleteEngine {

    struct Suggestion: Identifiable {
        let id = UUID()
        let text: String
        let detail: String
        let type: SuggestionType
        let insertText: String

        enum SuggestionType {
            case keyword, snippet, word
        }
    }

    private var languageKeywords: [Language: [String]] = [:]
    private var documentWords: Set<String> = []

    init() {
        loadKeywords()
    }

    func suggestions(for prefix: String, language: Language, documentText: String) -> [Suggestion] {
        guard prefix.count >= 2 else { return [] }
        let lower = prefix.lowercased()
        var results: [Suggestion] = []

        // 1. Snippets
        let snippets = Snippet.snippets(for: language)
        for snippet in snippets where snippet.trigger.lowercased().hasPrefix(lower) {
            results.append(Suggestion(
                text: snippet.trigger,
                detail: snippet.description,
                type: .snippet,
                insertText: snippet.body.replacingOccurrences(of: "$0", with: "")
            ))
        }

        // 2. Keywords
        if let keywords = languageKeywords[language] {
            for kw in keywords where kw.lowercased().hasPrefix(lower) && kw.lowercased() != lower {
                results.append(Suggestion(
                    text: kw,
                    detail: "keyword",
                    type: .keyword,
                    insertText: kw
                ))
            }
        }

        // 3. Document words
        extractWords(from: documentText)
        for word in documentWords where word.lowercased().hasPrefix(lower) && word.lowercased() != lower && word.count > 3 {
            if !results.contains(where: { $0.text.lowercased() == word.lowercased() }) {
                results.append(Suggestion(
                    text: word,
                    detail: "word",
                    type: .word,
                    insertText: word
                ))
            }
        }

        // Limit results
        return Array(results.prefix(15))
    }

    private func extractWords(from text: String) {
        documentWords.removeAll()
        let scanner = Scanner(string: text)
        let wordChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_$"))
        while !scanner.isAtEnd {
            if let word = scanner.scanCharacters(from: wordChars), word.count > 3 {
                documentWords.insert(word)
            } else {
                scanner.currentIndex = text.index(after: scanner.currentIndex)
            }
        }
    }

    private func loadKeywords() {
        languageKeywords[.php] = [
            "abstract", "and", "array", "as", "break", "case", "catch", "class", "clone", "const",
            "continue", "declare", "default", "do", "echo", "else", "elseif", "empty", "enddeclare",
            "endfor", "endforeach", "endif", "endswitch", "endwhile", "eval", "exit", "extends",
            "false", "final", "finally", "fn", "for", "foreach", "function", "global", "goto",
            "if", "implements", "include", "include_once", "instanceof", "interface", "isset",
            "list", "match", "namespace", "new", "null", "or", "print", "private", "protected",
            "public", "readonly", "require", "require_once", "return", "static", "switch", "throw",
            "trait", "true", "try", "unset", "use", "var", "while", "xor", "yield",
            "array_push", "array_pop", "array_map", "array_filter", "array_merge", "array_keys",
            "array_values", "count", "strlen", "strpos", "substr", "explode", "implode",
            "str_replace", "preg_match", "preg_replace", "file_get_contents", "file_put_contents",
            "json_encode", "json_decode", "isset", "empty", "var_dump", "print_r", "die",
            "header", "session_start", "setcookie", "htmlspecialchars", "urlencode", "urldecode",
            "intval", "floatval", "is_array", "is_string", "is_numeric", "is_null", "in_array",
            "array_key_exists", "array_unique", "array_reverse", "array_slice", "array_splice",
            "sort", "asort", "ksort", "usort", "trim", "ltrim", "rtrim", "strtolower", "strtoupper",
            "ucfirst", "lcfirst", "nl2br", "number_format", "date", "time", "mktime", "strtotime"
        ]

        languageKeywords[.html] = [
            "html", "head", "body", "title", "meta", "link", "script", "style", "div", "span",
            "p", "a", "img", "ul", "ol", "li", "table", "tr", "td", "th", "thead", "tbody",
            "form", "input", "button", "select", "option", "textarea", "label", "h1", "h2",
            "h3", "h4", "h5", "h6", "header", "footer", "nav", "main", "section", "article",
            "aside", "figure", "figcaption", "br", "hr", "strong", "em", "code", "pre",
            "blockquote", "iframe", "video", "audio", "source", "canvas", "svg", "details",
            "summary", "template", "slot", "class", "id", "href", "src", "alt", "type",
            "name", "value", "placeholder", "action", "method", "target", "rel", "charset",
            "viewport", "content", "width", "height", "onclick", "onload", "onsubmit"
        ]

        languageKeywords[.css] = [
            "display", "position", "top", "right", "bottom", "left", "float", "clear",
            "margin", "margin-top", "margin-right", "margin-bottom", "margin-left",
            "padding", "padding-top", "padding-right", "padding-bottom", "padding-left",
            "width", "height", "max-width", "max-height", "min-width", "min-height",
            "border", "border-radius", "border-color", "border-style", "border-width",
            "background", "background-color", "background-image", "background-size",
            "background-position", "background-repeat",
            "color", "font-family", "font-size", "font-weight", "font-style",
            "text-align", "text-decoration", "text-transform", "line-height", "letter-spacing",
            "flex", "flex-direction", "flex-wrap", "justify-content", "align-items", "align-self",
            "gap", "grid", "grid-template-columns", "grid-template-rows",
            "overflow", "opacity", "z-index", "cursor", "transition", "transform",
            "animation", "box-shadow", "box-sizing", "visibility",
            "none", "block", "inline", "inline-block", "flex", "grid",
            "relative", "absolute", "fixed", "sticky", "static",
            "center", "space-between", "space-around", "stretch", "baseline",
            "bold", "normal", "italic", "underline", "uppercase", "lowercase",
            "pointer", "auto", "hidden", "visible", "scroll", "cover", "contain",
            "inherit", "initial", "unset", "transparent", "solid", "dashed", "dotted",
            "important", "media", "keyframes", "import", "var", "calc"
        ]

        languageKeywords[.javascript] = [
            "async", "await", "break", "case", "catch", "class", "const", "continue",
            "debugger", "default", "delete", "do", "else", "export", "extends", "false",
            "finally", "for", "from", "function", "if", "import", "in", "instanceof",
            "let", "new", "null", "of", "return", "static", "super", "switch",
            "this", "throw", "true", "try", "typeof", "undefined", "var", "void",
            "while", "with", "yield",
            "console", "document", "window", "navigator", "location", "history",
            "setTimeout", "setInterval", "clearTimeout", "clearInterval",
            "fetch", "Promise", "JSON", "Math", "Date", "Array", "Object", "String",
            "Number", "Boolean", "Map", "Set", "Symbol", "Proxy", "Reflect",
            "addEventListener", "removeEventListener", "querySelector", "querySelectorAll",
            "getElementById", "getElementsByClassName", "createElement", "appendChild",
            "innerHTML", "textContent", "classList", "style", "getAttribute", "setAttribute",
            "forEach", "map", "filter", "reduce", "find", "findIndex", "some", "every",
            "push", "pop", "shift", "unshift", "splice", "slice", "concat", "join",
            "split", "replace", "match", "includes", "indexOf", "startsWith", "endsWith",
            "keys", "values", "entries", "assign", "freeze", "parse", "stringify",
            "then", "catch", "finally", "resolve", "reject", "all", "race", "allSettled",
            "log", "error", "warn", "info", "table", "dir"
        ]

        languageKeywords[.json] = ["true", "false", "null"]
    }
}
