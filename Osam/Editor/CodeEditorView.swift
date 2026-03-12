import SwiftUI
import UIKit

struct CodeEditorView: UIViewRepresentable {
    @Binding var text: String
    let language: Language
    let settings: AppSettings
    var onTextChange: ((String) -> Void)?
    var onCursorChange: ((Int) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor(red: 0.11, green: 0.12, blue: 0.14, alpha: 1)

        let textView = CodeTextView()
        textView.delegate = context.coordinator
        textView.language = language
        textView.codeFont = UIFont.monospacedSystemFont(ofSize: settings.fontSize, weight: .regular)
        textView.tabString = settings.useSpacesForTabs
            ? String(repeating: " ", count: settings.tabWidth)
            : "\t"
        textView.syntaxHighlighter = SyntaxHighlighter(theme: .dark)
        textView.onTextChange = { content in
            self.text = content
            self.onTextChange?(content)
        }
        textView.onCursorChange = onCursorChange
        textView.text = text
        textView.translatesAutoresizingMaskIntoConstraints = false

        let gutter = LineNumberGutter()
        gutter.textView = textView
        gutter.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(gutter)
        container.addSubview(textView)

        NSLayoutConstraint.activate([
            gutter.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            gutter.topAnchor.constraint(equalTo: container.topAnchor),
            gutter.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            gutter.widthAnchor.constraint(equalToConstant: settings.showLineNumbers ? 46 : 0),

            textView.leadingAnchor.constraint(equalTo: gutter.trailingAnchor),
            textView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            textView.topAnchor.constraint(equalTo: container.topAnchor),
            textView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        context.coordinator.gutter = gutter
        textView.applyHighlighting()

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let textView = uiView.subviews.compactMap({ $0 as? CodeTextView }).first else { return }
        
        if textView.text != text {
            textView.text = text
            textView.applyHighlighting()
        }
        
        if let gutter = context.coordinator.gutter {
            gutter.isHidden = !settings.showLineNumbers
            gutter.update()
        }
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: CodeEditorView
        var gutter: LineNumberGutter?

        init(_ parent: CodeEditorView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.onTextChange?(textView.text)
            gutter?.update()
            
            if let codeTextView = textView as? CodeTextView {
                codeTextView.scheduleHighlighting()
            }
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            gutter?.update()
        }
    }
}
