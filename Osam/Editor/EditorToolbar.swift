import SwiftUI

struct EditorToolbar: View {
    let onTab: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onFind: () -> Void
    let onSave: () -> Void
    let extraKeys: [(String, () -> Void)]

    init(
        onTab: @escaping () -> Void = {},
        onUndo: @escaping () -> Void = {},
        onRedo: @escaping () -> Void = {},
        onFind: @escaping () -> Void = {},
        onSave: @escaping () -> Void = {},
        extraKeys: [(String, () -> Void)] = []
    ) {
        self.onTab = onTab
        self.onUndo = onUndo
        self.onRedo = onRedo
        self.onFind = onFind
        self.onSave = onSave
        self.extraKeys = extraKeys
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                toolButton("arrow.right.to.line.compact") { onTab() }
                toolButton("arrow.uturn.backward") { onUndo() }
                toolButton("arrow.uturn.forward") { onRedo() }
                toolButton("magnifyingglass") { onFind() }
                toolButton("square.and.arrow.down") { onSave() }

                Divider().frame(height: 24)

                // Extra character keys for common programming chars
                charButton("{")
                charButton("}")
                charButton("(")
                charButton(")")
                charButton("[")
                charButton("]")
                charButton("<")
                charButton(">")
                charButton("/")
                charButton("=")
                charButton("\"")
                charButton("'")
                charButton(";")
                charButton("$")
                charButton("#")

                ForEach(extraKeys.indices, id: \.self) { i in
                    let (label, action) = extraKeys[i]
                    charButton(label, action: action)
                }
            }
            .padding(.horizontal, 6)
        }
        .frame(height: 40)
        .background(Color.osamSurface)
    }

    private func toolButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15))
                .frame(width: 38, height: 34)
        }
        .foregroundColor(.osamText)
    }

    private func charButton(_ char: String, action: (() -> Void)? = nil) -> some View {
        Button(action: {
            action?()
            // If no custom action, inject character via notification
            if action == nil {
                NotificationCenter.default.post(name: .editorInsertCharacter, object: char)
            }
        }) {
            Text(char)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .frame(width: 34, height: 34)
        }
        .foregroundColor(.osamText)
        .background(Color.osamBackground.opacity(0.5))
        .cornerRadius(5)
    }
}

extension Notification.Name {
    static let editorInsertCharacter = Notification.Name("editorInsertCharacter")
}
