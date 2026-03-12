import SwiftUI

struct TabBarView: View {
    @ObservedObject var viewModel: EditorViewModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(viewModel.tabs) { tab in
                    TabItem(tab: tab, isActive: viewModel.activeTabId == tab.id, onSelect: {
                        viewModel.switchToTab(tab.id)
                    }, onClose: {
                        viewModel.closeTab(tab.id)
                    })
                }
            }
        }
        .frame(height: 40)
        .background(Color.osamSurface)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.white.opacity(0.1)),
            alignment: .bottom
        )
    }
}

struct TabItem: View {
    let tab: EditorTab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: Language.detect(from: tab.url.pathExtension).iconName)
                .foregroundColor(isActive ? .osamAccent : .secondary)
            
            Text(tab.name)
                .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                .foregroundColor(isActive ? .osamText : .secondary)
            
            if tab.isModified {
                Circle()
                    .fill(Color.osamOrange)
                    .frame(width: 6, height: 6)
            }
            
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding(4)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(isActive ? Color.osamBackground : Color.clear)
        .onTapGesture(perform: onSelect)
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(Color.white.opacity(0.05)),
            alignment: .trailing
        )
    }
}

extension Language {
    var iconName: String {
        switch self {
        case .php: return "chevron.left.forwardslash.chevron.right"
        case .html: return "doc.richtext"
        case .css: return "paintbrush"
        case .javascript: return "bolt"
        case .json: return "curlybraces"
        case .markdown: return "doc.text"
        case .plainText: return "doc"
        }
    }
}
