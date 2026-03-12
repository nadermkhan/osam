import SwiftUI
import UIKit

@MainActor
final class EditorViewModel: ObservableObject {
    @Published var tabs: [EditorTab] = []
    @Published var activeTabId: String?
    @Published var content = ""
    @Published var showAutocomplete = false
    @Published var autocompleSuggestions: [AutocompleteEngine.Suggestion] = []
    @Published var showFindBar = false
    @Published var findQuery = ""
    @Published var findResults: [NSRange] = []
    @Published var currentFindIndex = 0
    @Published var showJumpToLine = false
    @Published var jumpToLineNumber = ""
    @Published var errorMessage: String?

    private let fileManager = LocalFileManager.shared
    private let autocomplete = AutocompleteEngine()
    private var fileContents: [String: String] = [:]
    private var undoStacks: [String: [String]] = [:]
    private var redoStacks: [String: [String]] = [:]

    var activeTab: EditorTab? {
        tabs.first { $0.id == activeTabId }
    }

    var activeLanguage: Language {
        activeTab?.language ?? .plainText
    }

    func openFile(url: URL, isRemote: Bool = false, remotePath: String? = nil, serverId: String? = nil) {
        let tab = EditorTab(url: url, isRemote: isRemote, remotePath: remotePath, serverId: serverId)

        if let existing = tabs.first(where: { $0.id == tab.id }) {
            activeTabId = existing.id
            content = fileContents[existing.id] ?? ""
            return
        }

        do {
            let text = try fileManager.readFile(at: url)
            fileContents[tab.id] = text
            tabs.append(tab)
            activeTabId = tab.id
            content = text
            undoStacks[tab.id] = [text]
            redoStacks[tab.id] = []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openRemoteContent(_ text: String, tab: EditorTab) {
        fileContents[tab.id] = text
        if !tabs.contains(where: { $0.id == tab.id }) {
            tabs.append(tab)
        }
        activeTabId = tab.id
        content = text
        undoStacks[tab.id] = [text]
        redoStacks[tab.id] = []
    }

    func switchToTab(_ tabId: String) {
        // Save current content
        if let currentId = activeTabId {
            fileContents[currentId] = content
        }
        activeTabId = tabId
        content = fileContents[tabId] ?? ""
    }

    func closeTab(_ tabId: String) {
        tabs.removeAll { $0.id == tabId }
        fileContents.removeValue(forKey: tabId)
        undoStacks.removeValue(forKey: tabId)
        redoStacks.removeValue(forKey: tabId)

        if activeTabId == tabId {
            activeTabId = tabs.last?.id
            content = activeTabId.flatMap { fileContents[$0] } ?? ""
        }
    }

    func saveCurrentFile() {
        guard let tab = activeTab else { return }
        fileContents[tab.id] = content
        do {
            try fileManager.writeFile(content: content, to: tab.url)
            if let idx = tabs.firstIndex(where: { $0.id == tab.id }) {
                tabs[idx].isModified = false
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func contentDidChange(_ newContent: String) {
        content = newContent
        if let tabId = activeTabId {
            fileContents[tabId] = newContent
            if let idx = tabs.firstIndex(where: { $0.id == tabId }) {
                tabs[idx].isModified = true
            }
            // Push to undo stack
            if undoStacks[tabId] == nil { undoStacks[tabId] = [] }
            undoStacks[tabId]?.append(newContent)
            // Limit undo stack size
            if let count = undoStacks[tabId]?.count, count > 100 {
                undoStacks[tabId]?.removeFirst(count - 100)
            }
            redoStacks[tabId] = []
        }
    }

    func undo() {
        guard let tabId = activeTabId,
              var stack = undoStacks[tabId],
              stack.count > 1 else { return }
        let current = stack.removeLast()
        redoStacks[tabId, default: []].append(current)
        let previous = stack.last ?? ""
        undoStacks[tabId] = stack
        content = previous
        fileContents[tabId] = previous
    }

    func redo() {
        guard let tabId = activeTabId,
              var stack = redoStacks[tabId],
              !stack.isEmpty else { return }
        let next = stack.removeLast()
        redoStacks[tabId] = stack
        undoStacks[tabId, default: []].append(next)
        content = next
        fileContents[tabId] = next
    }

    // MARK: - Find

    func performFind() {
        guard !findQuery.isEmpty else {
            findResults = []
            return
        }
        let nsString = content as NSString
        var results: [NSRange] = []
        var searchRange = NSRange(location: 0, length: nsString.length)
        while searchRange.location < nsString.length {
            let range = nsString.range(of: findQuery, options: .caseInsensitive, range: searchRange)
            if range.location == NSNotFound { break }
            results.append(range)
            searchRange.location = range.location + range.length
            searchRange.length = nsString.length - searchRange.location
        }
        findResults = results
        currentFindIndex = results.isEmpty ? 0 : 0
    }

    func findNext() {
        guard !findResults.isEmpty else { return }
        currentFindIndex = (currentFindIndex + 1) % findResults.count
    }

    func findPrevious() {
        guard !findResults.isEmpty else { return }
        currentFindIndex = (currentFindIndex - 1 + findResults.count) % findResults.count
    }

    // MARK: - Autocomplete

    func updateAutocomplete(prefix: String) {
        guard prefix.count >= 2 else {
            showAutocomplete = false
            autocompleSuggestions = []
            return
        }
        let suggestions = autocomplete.suggestions(for: prefix, language: activeLanguage, documentText: content)
        autocompleSuggestions = suggestions
        showAutocomplete = !suggestions.isEmpty
    }

    func applySuggestion(_ suggestion: AutocompleteEngine.Suggestion, replacingPrefix prefix: String) -> String {
        // The caller (CodeTextView) will handle the actual text replacement
        showAutocomplete = false
        return suggestion.insertText
    }
}
