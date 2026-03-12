import Foundation

struct Snippet: Identifiable, Codable {
    let id: String
    let trigger: String
    let body: String
    let language: Language
    let description: String

    static let builtInPHP: [Snippet] = [
        Snippet(id: "php-tag", trigger: "php", body: "<?php\n$0\n?>", language: .php, description: "PHP tags"),
        Snippet(id: "php-echo", trigger: "echo", body: "echo '$0';", language: .php, description: "Echo statement"),
        Snippet(id: "php-foreach", trigger: "foreach", body: "foreach ($$0 as $item) {\n\t\n}", language: .php, description: "Foreach loop"),
        Snippet(id: "php-if", trigger: "if", body: "if ($0) {\n\t\n}", language: .php, description: "If block"),
        Snippet(id: "php-ifelse", trigger: "ifelse", body: "if ($0) {\n\t\n} else {\n\t\n}", language: .php, description: "If-else block"),
        Snippet(id: "php-function", trigger: "fn", body: "function $0() {\n\t\n}", language: .php, description: "Function"),
        Snippet(id: "php-class", trigger: "class", body: "class $0 {\n\tpublic function __construct() {\n\t\t\n\t}\n}", language: .php, description: "Class"),
        Snippet(id: "php-try", trigger: "try", body: "try {\n\t$0\n} catch (Exception $e) {\n\t\n}", language: .php, description: "Try-catch"),
        Snippet(id: "php-for", trigger: "for", body: "for ($i = 0; $i < $0; $i++) {\n\t\n}", language: .php, description: "For loop"),
        Snippet(id: "php-while", trigger: "while", body: "while ($0) {\n\t\n}", language: .php, description: "While loop"),
        Snippet(id: "php-switch", trigger: "switch", body: "switch ($0) {\n\tcase '':\n\t\tbreak;\n\tdefault:\n\t\tbreak;\n}", language: .php, description: "Switch"),
        Snippet(id: "php-array", trigger: "arr", body: "$0 = [];", language: .php, description: "Array"),
        Snippet(id: "php-include", trigger: "inc", body: "include '$0';", language: .php, description: "Include"),
        Snippet(id: "php-require", trigger: "req", body: "require '$0';", language: .php, description: "Require"),
    ]

    static let builtInHTML: [Snippet] = [
        Snippet(id: "html-doc", trigger: "html5", body: "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n\t<meta charset=\"UTF-8\">\n\t<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n\t<title>$0</title>\n</head>\n<body>\n\t\n</body>\n</html>", language: .html, description: "HTML5 boilerplate"),
        Snippet(id: "html-div", trigger: "div", body: "<div class=\"$0\">\n\t\n</div>", language: .html, description: "Div"),
        Snippet(id: "html-link", trigger: "link", body: "<link rel=\"stylesheet\" href=\"$0\">", language: .html, description: "CSS link"),
        Snippet(id: "html-script", trigger: "script", body: "<script src=\"$0\"></script>", language: .html, description: "Script tag"),
        Snippet(id: "html-a", trigger: "a", body: "<a href=\"$0\"></a>", language: .html, description: "Anchor"),
        Snippet(id: "html-img", trigger: "img", body: "<img src=\"$0\" alt=\"\">", language: .html, description: "Image"),
        Snippet(id: "html-form", trigger: "form", body: "<form action=\"$0\" method=\"post\">\n\t\n</form>", language: .html, description: "Form"),
        Snippet(id: "html-input", trigger: "input", body: "<input type=\"$0\" name=\"\" value=\"\">", language: .html, description: "Input"),
        Snippet(id: "html-ul", trigger: "ul", body: "<ul>\n\t<li>$0</li>\n</ul>", language: .html, description: "Unordered list"),
        Snippet(id: "html-table", trigger: "table", body: "<table>\n\t<thead>\n\t\t<tr>\n\t\t\t<th>$0</th>\n\t\t</tr>\n\t</thead>\n\t<tbody>\n\t\t<tr>\n\t\t\t<td></td>\n\t\t</tr>\n\t</tbody>\n</table>", language: .html, description: "Table"),
        Snippet(id: "html-meta", trigger: "meta", body: "<meta name=\"$0\" content=\"\">", language: .html, description: "Meta tag"),
    ]

    static let builtInCSS: [Snippet] = [
        Snippet(id: "css-flex", trigger: "flex", body: "display: flex;\njustify-content: $0;\nalign-items: center;", language: .css, description: "Flexbox"),
        Snippet(id: "css-grid", trigger: "grid", body: "display: grid;\ngrid-template-columns: $0;\ngap: 1rem;", language: .css, description: "Grid"),
        Snippet(id: "css-media", trigger: "media", body: "@media (max-width: $0px) {\n\t\n}", language: .css, description: "Media query"),
        Snippet(id: "css-reset", trigger: "reset", body: "* {\n\tmargin: 0;\n\tpadding: 0;\n\tbox-sizing: border-box;\n}", language: .css, description: "Reset"),
    ]

    static let builtInJS: [Snippet] = [
        Snippet(id: "js-fn", trigger: "fn", body: "function $0() {\n\t\n}", language: .javascript, description: "Function"),
        Snippet(id: "js-arrow", trigger: "arrow", body: "const $0 = () => {\n\t\n};", language: .javascript, description: "Arrow function"),
        Snippet(id: "js-fetch", trigger: "fetch", body: "fetch('$0')\n\t.then(res => res.json())\n\t.then(data => {\n\t\t\n\t})\n\t.catch(err => console.error(err));", language: .javascript, description: "Fetch API"),
        Snippet(id: "js-ael", trigger: "ael", body: "document.addEventListener('$0', (e) => {\n\t\n});", language: .javascript, description: "Event listener"),
        Snippet(id: "js-qs", trigger: "qs", body: "document.querySelector('$0')", language: .javascript, description: "querySelector"),
        Snippet(id: "js-log", trigger: "log", body: "console.log($0);", language: .javascript, description: "Console log"),
        Snippet(id: "js-forin", trigger: "forin", body: "for (const $0 of ) {\n\t\n}", language: .javascript, description: "For-of loop"),
        Snippet(id: "js-promise", trigger: "promise", body: "new Promise((resolve, reject) => {\n\t$0\n});", language: .javascript, description: "Promise"),
        Snippet(id: "js-async", trigger: "async", body: "async function $0() {\n\ttry {\n\t\t\n\t} catch (error) {\n\t\tconsole.error(error);\n\t}\n}", language: .javascript, description: "Async function"),
    ]

    static func snippets(for language: Language) -> [Snippet] {
        switch language {
        case .php: return builtInPHP
        case .html: return builtInHTML
        case .css: return builtInCSS
        case .javascript: return builtInJS
        default: return []
        }
    }
}
