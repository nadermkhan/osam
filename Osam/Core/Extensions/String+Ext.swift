import Foundation

extension String {
    func lineNumber(at offset: Int) -> Int {
        let prefix = self.prefix(offset)
        return prefix.filter { $0 == "\n" }.count + 1
    }

    var lineCount: Int {
        var count = 1
        for char in self where char == "\n" {
            count += 1
        }
        return count
    }

    func indentation(ofLineAt offset: Int) -> String {
        let nsString = self as NSString
        let lineRange = nsString.lineRange(for: NSRange(location: min(offset, nsString.length - 1), length: 0))
        let line = nsString.substring(with: lineRange)
        var indent = ""
        for char in line {
            if char == " " || char == "\t" {
                indent.append(char)
            } else {
                break
            }
        }
        return indent
    }

    func wordPrefix(at offset: Int) -> String {
        let nsString = self as NSString
        guard offset > 0 && offset <= nsString.length else { return "" }
        var start = offset - 1
        let wordChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_$"))
        while start >= 0 {
            let char = nsString.character(at: start)
            guard let scalar = Unicode.Scalar(char), wordChars.contains(scalar) else { break }
            start -= 1
        }
        start += 1
        guard start < offset else { return "" }
        return nsString.substring(with: NSRange(location: start, length: offset - start))
    }
}

extension URL {
    var isDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }
}
