import Foundation

// MARK: - FTP Protocol Abstraction

protocol FTPServiceProtocol: AnyObject {
    var isConnected: Bool { get }
    func connect(credential: ServerCredential, password: String) async throws
    func disconnect()
    func listDirectory(path: String) async throws -> [RemoteFileItem]
    func downloadFile(remotePath: String, localURL: URL) async throws
    func uploadFile(localURL: URL, remotePath: String) async throws
    func deleteFile(remotePath: String) async throws
    func deleteDirectory(remotePath: String) async throws
    func createDirectory(remotePath: String) async throws
    func rename(from: String, to: String) async throws
    func fileInfo(path: String) async throws -> RemoteFileItem?
    func recursiveList(path: String) async throws -> [RemoteFileItem]
}

struct RemoteFileItem: Identifiable {
    var id: String { path }
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64
    let modified: Date
}

// MARK: - FTP Service using CFNetwork Streams

final class FTPService: FTPServiceProtocol {
    private var credential: ServerCredential?
    private var password: String?
    private(set) var isConnected = false

    private var host: String { credential?.host ?? "" }
    private var port: Int { credential?.port ?? 21 }
    private var username: String { credential?.username ?? "" }
    private var useFTPS: Bool { credential?.useFTPS ?? false }

    private var controlInput: InputStream?
    private var controlOutput: OutputStream?
    private let queue = DispatchQueue(label: "com.osam.ftp", qos: .utility)
    private let bufferSize = 65536

    func connect(credential: ServerCredential, password: String) async throws {
        self.credential = credential
        self.password = password

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: FTPError.internalError)
                    return
                }
                do {
                    try self.openControlConnection()
                    let welcomeResponse = try self.readResponse()
                    guard welcomeResponse.code == 220 else {
                        throw FTPError.connectionFailed(welcomeResponse.message)
                    }

                    if self.useFTPS {
                        try self.sendCommand("AUTH TLS")
                        let authResp = try self.readResponse()
                        guard authResp.code == 234 else {
                            throw FTPError.tlsFailed
                        }
                        self.upgradeTLS()
                    }

                    try self.sendCommand("USER \(self.username)")
                    let userResp = try self.readResponse()
                    if userResp.code == 331 {
                        try self.sendCommand("PASS \(password)")
                        let passResp = try self.readResponse()
                        guard passResp.code == 230 else {
                            throw FTPError.authenticationFailed
                        }
                    } else if userResp.code != 230 {
                        throw FTPError.authenticationFailed
                    }

                    try self.sendCommand("TYPE I")
                    _ = try self.readResponse()

                    try self.sendCommand("OPTS UTF8 ON")
                    _ = try? self.readResponse()

                    self.isConnected = true
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func disconnect() {
        queue.sync {
            try? sendCommand("QUIT")
            _ = try? readResponse()
            controlInput?.close()
            controlOutput?.close()
            controlInput = nil
            controlOutput = nil
            isConnected = false
        }
    }

    func listDirectory(path: String) async throws -> [RemoteFileItem] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: FTPError.internalError)
                    return
                }
                do {
                    let (dataIn, _) = try self.openPassiveConnection()
                    try self.sendCommand("MLSD \(path)")
                    let cmdResp = try self.readResponse()

                    if cmdResp.code == 500 || cmdResp.code == 502 {
                        // MLSD not supported, fall back to LIST
                        let items = try self.listDirectoryLIST(path: path)
                        continuation.resume(returning: items)
                        return
                    }

                    guard cmdResp.code == 150 || cmdResp.code == 125 else {
                        throw FTPError.listFailed(cmdResp.message)
                    }

                    let data = self.readAllData(from: dataIn)
                    dataIn.close()

                    let transferResp = try self.readResponse()
                    guard transferResp.code == 226 || transferResp.code == 250 else {
                        throw FTPError.listFailed(transferResp.message)
                    }

                    let listing = String(data: data, encoding: .utf8) ?? ""
                    let items = self.parseMLSD(listing, basePath: path)
                    continuation.resume(returning: items)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func listDirectoryLIST(path: String) throws -> [RemoteFileItem] {
        let (dataIn, _) = try openPassiveConnection()
        try sendCommand("LIST -la \(path)")
        let cmdResp = try readResponse()
        guard cmdResp.code == 150 || cmdResp.code == 125 else {
            throw FTPError.listFailed(cmdResp.message)
        }

        let data = readAllData(from: dataIn)
        dataIn.close()

        let transferResp = try readResponse()
        guard transferResp.code == 226 || transferResp.code == 250 else {
            throw FTPError.listFailed(transferResp.message)
        }

        let listing = String(data: data, encoding: .utf8) ?? ""
        return parseLIST(listing, basePath: path)
    }

    func downloadFile(remotePath: String, localURL: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: FTPError.internalError)
                    return
                }
                do {
                    let (dataIn, _) = try self.openPassiveConnection()
                    try self.sendCommand("RETR \(remotePath)")
                    let resp = try self.readResponse()
                    guard resp.code == 150 || resp.code == 125 else {
                        throw FTPError.downloadFailed(resp.message)
                    }

                    let data = self.readAllData(from: dataIn)
                    dataIn.close()
                    try data.write(to: localURL)

                    let transferResp = try self.readResponse()
                    guard transferResp.code == 226 || transferResp.code == 250 else {
                        throw FTPError.downloadFailed(transferResp.message)
                    }

                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func uploadFile(localURL: URL, remotePath: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: FTPError.internalError)
                    return
                }
                do {
                    let fileData = try Data(contentsOf: localURL)
                    let (_, dataOut) = try self.openPassiveConnection()
                    try self.sendCommand("STOR \(remotePath)")
                    let resp = try self.readResponse()
                    guard resp.code == 150 || resp.code == 125 else {
                        throw FTPError.uploadFailed(resp.message)
                    }

                    self.writeAllData(fileData, to: dataOut)
                    dataOut.close()

                    let transferResp = try self.readResponse()
                    guard transferResp.code == 226 || transferResp.code == 250 else {
                        throw FTPError.uploadFailed(transferResp.message)
                    }

                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteFile(remotePath: String) async throws {
        try await executeSimple("DELE \(remotePath)")
    }

    func deleteDirectory(remotePath: String) async throws {
        try await executeSimple("RMD \(remotePath)")
    }

    func createDirectory(remotePath: String) async throws {
        try await executeSimple("MKD \(remotePath)")
    }

    func rename(from: String, to: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: FTPError.internalError)
                    return
                }
                do {
                    try self.sendCommand("RNFR \(from)")
                    let resp1 = try self.readResponse()
                    guard resp1.code == 350 else { throw FTPError.renameFailed(resp1.message) }
                    try self.sendCommand("RNTO \(to)")
                    let resp2 = try self.readResponse()
                    guard resp2.code == 250 else { throw FTPError.renameFailed(resp2.message) }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func fileInfo(path: String) async throws -> RemoteFileItem? {
        // Use MLST if available, otherwise SIZE + MDTM
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: FTPError.internalError)
                    return
                }
                do {
                    try self.sendCommand("MLST \(path)")
                    let resp = try self.readResponse()
                    if resp.code == 250 {
                        // Parse MLST response
                        let lines = resp.message.components(separatedBy: "\r\n")
                        for line in lines where line.trimmingCharacters(in: .whitespaces).contains("=") {
                            let trimmed = line.trimmingCharacters(in: .whitespaces)
                            let item = self.parseMLSDLine(trimmed, basePath: (path as NSString).deletingLastPathComponent)
                            continuation.resume(returning: item)
                            return
                        }
                        continuation.resume(returning: nil)
                    } else {
                        // Fallback
                        var size: Int64 = 0
                        var modified = Date()

                        try self.sendCommand("SIZE \(path)")
                        if let sizeResp = try? self.readResponse(), sizeResp.code == 213 {
                            size = Int64(sizeResp.message.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: " ").last ?? "0") ?? 0
                        }

                        try self.sendCommand("MDTM \(path)")
                        if let mdtmResp = try? self.readResponse(), mdtmResp.code == 213 {
                            let dateStr = mdtmResp.message.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: " ").last ?? ""
                            modified = self.parseFTPDate(dateStr) ?? Date()
                        }

                        let name = (path as NSString).lastPathComponent
                        continuation.resume(returning: RemoteFileItem(name: name, path: path, isDirectory: false, size: size, modified: modified))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func recursiveList(path: String) async throws -> [RemoteFileItem] {
        var allItems: [RemoteFileItem] = []
        let items = try await listDirectory(path: path)
        for item in items {
            if item.isDirectory {
                allItems.append(item)
                let subItems = try await recursiveList(path: item.path)
                allItems.append(contentsOf: subItems)
            } else {
                allItems.append(item)
            }
        }
        return allItems
    }

    // MARK: - Private

    private func openControlConnection() throws {
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?

        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault,
                                           host as CFString,
                                           UInt32(port),
                                           &readStream,
                                           &writeStream)

        guard let input = readStream?.takeRetainedValue(),
              let output = writeStream?.takeRetainedValue() else {
            throw FTPError.connectionFailed("Cannot create streams")
        }

        controlInput = input as InputStream
        controlOutput = output as OutputStream

        controlInput?.open()
        controlOutput?.open()

        // Wait for stream to be ready
        Thread.sleep(forTimeInterval: 0.1)
    }

    private func upgradeTLS() {
        controlInput?.setProperty(StreamSocketSecurityLevel.negotiatedSSL, forKey: .socketSecurityLevelKey)
        controlOutput?.setProperty(StreamSocketSecurityLevel.negotiatedSSL, forKey: .socketSecurityLevelKey)

        let sslSettings: [String: Any] = [
            kCFStreamSSLValidatesCertificateChain as String: false
        ]
        controlInput?.setProperty(sslSettings, forKey: kCFStreamPropertySSLSettings as Stream.PropertyKey)
        controlOutput?.setProperty(sslSettings, forKey: kCFStreamPropertySSLSettings as Stream.PropertyKey)
    }

    @discardableResult
    private func sendCommand(_ command: String) throws {
        let cmdData = "\(command)\r\n"
        guard let data = cmdData.data(using: .utf8),
              let output = controlOutput else {
            throw FTPError.connectionLost
        }
        data.withUnsafeBytes { ptr in
            guard let base = ptr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            output.write(base, maxLength: data.count)
        }
    }

    private func readResponse() throws -> FTPResponse {
        guard let input = controlInput else { throw FTPError.connectionLost }
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        var accumulated = ""

        // Read until we get a complete response (3 digits + space)
        let maxAttempts = 100
        var attempts = 0
        while attempts < maxAttempts {
            if input.hasBytesAvailable {
                let bytesRead = input.read(&buffer, maxLength: bufferSize)
                if bytesRead > 0 {
                    accumulated += String(bytes: buffer[0..<bytesRead], encoding: .utf8) ?? ""
                    // Check if we have a complete response
                    let lines = accumulated.components(separatedBy: "\r\n").filter { !$0.isEmpty }
                    if let lastLine = lines.last {
                        // A complete response has "NNN " (3 digits then space) at the start of the last line
                        if lastLine.count >= 4 {
                            let prefix = String(lastLine.prefix(4))
                            if prefix.count == 4 && prefix.last == " " {
                                let codeStr = String(prefix.prefix(3))
                                if let code = Int(codeStr) {
                                    return FTPResponse(code: code, message: accumulated)
                                }
                            }
                        }
                    }
                }
            } else {
                Thread.sleep(forTimeInterval: 0.05)
            }
            attempts += 1
        }
        throw FTPError.timeout
    }

    private func openPassiveConnection() throws -> (InputStream, OutputStream) {
        if useFTPS {
            try sendCommand("PROT P")
            _ = try readResponse()
        }

        try sendCommand("PASV")
        let resp = try readResponse()
        guard resp.code == 227 else { throw FTPError.passiveFailed(resp.message) }

        let (pasvHost, pasvPort) = try parsePASV(resp.message)

        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault,
                                           pasvHost as CFString,
                                           UInt32(pasvPort),
                                           &readStream,
                                           &writeStream)

        guard let input = readStream?.takeRetainedValue() as InputStream?,
              let output = writeStream?.takeRetainedValue() as OutputStream? else {
            throw FTPError.passiveFailed("Cannot create data streams")
        }

        if useFTPS {
            input.setProperty(StreamSocketSecurityLevel.negotiatedSSL, forKey: .socketSecurityLevelKey)
            output.setProperty(StreamSocketSecurityLevel.negotiatedSSL, forKey: .socketSecurityLevelKey)
            let sslSettings: [String: Any] = [
                kCFStreamSSLValidatesCertificateChain as String: false
            ]
            input.setProperty(sslSettings, forKey: kCFStreamPropertySSLSettings as Stream.PropertyKey)
            output.setProperty(sslSettings, forKey: kCFStreamPropertySSLSettings as Stream.PropertyKey)
        }

        input.open()
        output.open()
        Thread.sleep(forTimeInterval: 0.05)

        return (input, output)
    }

    private func parsePASV(_ message: String) throws -> (String, Int) {
        // Parse "227 Entering Passive Mode (h1,h2,h3,h4,p1,p2)"
        guard let range = message.range(of: "\\(([0-9,]+)\\)", options: .regularExpression),
              !message[range].isEmpty else {
            throw FTPError.passiveFailed("Cannot parse PASV response")
        }

        let inner = message[range].dropFirst().dropLast()
        let parts = inner.split(separator: ",").compactMap { Int($0) }
        guard parts.count == 6 else { throw FTPError.passiveFailed("Bad PASV parts") }

        let host = "\(parts[0]).\(parts[1]).\(parts[2]).\(parts[3])"
        let port = parts[4] * 256 + parts[5]
        return (host, port)
    }

    private func readAllData(from stream: InputStream) -> Data {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        let maxIdle = 50
        var idleCount = 0

        while true {
            if stream.hasBytesAvailable {
                let bytesRead = stream.read(&buffer, maxLength: bufferSize)
                if bytesRead > 0 {
                    data.append(buffer, count: bytesRead)
                    idleCount = 0
                } else if bytesRead == 0 {
                    break
                } else {
                    break
                }
            } else {
                Thread.sleep(forTimeInterval: 0.02)
                idleCount += 1
                if idleCount > maxIdle {
                    break
                }
            }
        }
        return data
    }

    private func writeAllData(_ data: Data, to stream: OutputStream) {
        data.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            var totalWritten = 0
            while totalWritten < data.count {
                let remaining = data.count - totalWritten
                let toWrite = min(remaining, bufferSize)
                let written = stream.write(base.advanced(by: totalWritten), maxLength: toWrite)
                if written <= 0 { break }
                totalWritten += written
            }
        }
    }

    private func executeSimple(_ command: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: FTPError.internalError)
                    return
                }
                do {
                    try self.sendCommand(command)
                    let resp = try self.readResponse()
                    guard (200...399).contains(resp.code) else {
                        throw FTPError.commandFailed(command, resp.message)
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Parsing

    private func parseMLSD(_ listing: String, basePath: String) -> [RemoteFileItem] {
        let lines = listing.components(separatedBy: "\r\n").filter { !$0.isEmpty }
        return lines.compactMap { parseMLSDLine($0, basePath: basePath) }
    }

    private func parseMLSDLine(_ line: String, basePath: String) -> RemoteFileItem? {
        // Format: "facts; filename"
        guard let semiIndex = line.firstIndex(of: ";") else { return nil }

        // Find the filename after the last "; "
        let parts = line.split(separator: " ", maxSplits: 1)
        guard parts.count == 2 || line.contains("; ") else { return nil }

        var name = ""
        var facts = ""

        if let range = line.range(of: "; ") {
            facts = String(line[..<range.lowerBound])
            name = String(line[range.upperBound...])
        } else {
            let split = line.components(separatedBy: " ")
            facts = split[0]
            name = split.dropFirst().joined(separator: " ")
        }

        guard name != "." && name != ".." else { return nil }

        var isDir = false
        var size: Int64 = 0
        var modified = Date()

        let factParts = facts.split(separator: ";")
        for fact in factParts {
            let kv = fact.split(separator: "=", maxSplits: 1)
            guard kv.count == 2 else { continue }
            let key = String(kv[0]).lowercased().trimmingCharacters(in: .whitespaces)
            let val = String(kv[1]).trimmingCharacters(in: .whitespaces)

            switch key {
            case "type":
                isDir = val.lowercased() == "dir" || val.lowercased() == "cdir" || val.lowercased() == "pdir"
                if val.lowercased() == "cdir" || val.lowercased() == "pdir" { return nil }
            case "size":
                size = Int64(val) ?? 0
            case "modify":
                modified = parseFTPDate(val) ?? Date()
            default: break
            }
        }

        let fullPath = basePath.hasSuffix("/") ? basePath + name : basePath + "/" + name
        return RemoteFileItem(name: name, path: fullPath, isDirectory: isDir, size: size, modified: modified)
    }

    private func parseLIST(_ listing: String, basePath: String) -> [RemoteFileItem] {
        let lines = listing.components(separatedBy: "\r\n").filter { !$0.isEmpty }
        return lines.compactMap { parseLISTLine($0, basePath: basePath) }
    }

    private func parseLISTLine(_ line: String, basePath: String) -> RemoteFileItem? {
        // Unix-style: drwxr-xr-x  2 user group  4096 Jan  1 12:00 dirname
        let parts = line.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 9 else { return nil }

        let perms = String(parts[0])
        let isDir = perms.hasPrefix("d")
        let size = Int64(parts[4]) ?? 0
        let name = parts[8...].joined(separator: " ")

        guard name != "." && name != ".." else { return nil }

        // Parse date from parts[5..7]
        let dateStr = "\(parts[5]) \(parts[6]) \(parts[7])"
        let modified = parseLISTDate(dateStr) ?? Date()

        let fullPath = basePath.hasSuffix("/") ? basePath + name : basePath + "/" + name
        return RemoteFileItem(name: name, path: fullPath, isDirectory: isDir, size: size, modified: modified)
    }

    private func parseFTPDate(_ dateStr: String) -> Date? {
        // Format: YYYYMMDDHHmmss or YYYYMMDDHHmmss.sss
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let clean = dateStr.components(separatedBy: ".").first ?? dateStr
        return formatter.date(from: clean)
    }

    private func parseLISTDate(_ dateStr: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // Try "Jan  1 12:00" or "Jan  1  2024"
        for format in ["MMM d HH:mm", "MMM d yyyy", "MMM  d HH:mm", "MMM  d  yyyy"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateStr) {
                return date
            }
        }
        return nil
    }
}

struct FTPResponse {
    let code: Int
    let message: String
}

enum FTPError: LocalizedError {
    case connectionFailed(String)
    case connectionLost
    case authenticationFailed
    case tlsFailed
    case timeout
    case passiveFailed(String)
    case listFailed(String)
    case downloadFailed(String)
    case uploadFailed(String)
    case renameFailed(String)
    case commandFailed(String, String)
    case internalError

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let msg): return "Connection failed: \(msg)"
        case .connectionLost: return "Connection lost"
        case .authenticationFailed: return "Authentication failed"
        case .tlsFailed: return "TLS negotiation failed"
        case .timeout: return "Connection timed out"
        case .passiveFailed(let msg): return "Passive mode failed: \(msg)"
        case .listFailed(let msg): return "Directory listing failed: \(msg)"
        case .downloadFailed(let msg): return "Download failed: \(msg)"
        case .uploadFailed(let msg): return "Upload failed: \(msg)"
        case .renameFailed(let msg): return "Rename failed: \(msg)"
        case .commandFailed(let cmd, let msg): return "\(cmd) failed: \(msg)"
        case .internalError: return "Internal error"
        }
    }
}
