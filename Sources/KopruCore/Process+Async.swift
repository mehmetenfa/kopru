import Foundation

public struct CommandResult {
    public let status: Int32
    public let stdout: Data
    public let stderr: String
    public var text: String { String(decoding: stdout, as: UTF8.self) }
}

public enum KopruError: LocalizedError {
    case failed(String)
    case hashMismatch(local: String, remote: String)
    case badRemoteOutput(String)

    public var errorDescription: String? {
        switch self {
        case .failed(let m): return m
        case .hashMismatch(let l, let r): return "Bütünlük kontrolü başarısız (yerel \(l.prefix(12))…, uzak \(r.prefix(12))…)"
        case .badRemoteOutput(let m): return "Windows'tan beklenmeyen yanıt: \(m)"
        }
    }
}

func runProcess(_ exe: String, _ args: [String], stdin: Data? = nil) async throws -> CommandResult {
    try await withCheckedThrowingContinuation { cont in
        let p = Process()
        p.executableURL = URL(fileURLWithPath: exe)
        p.arguments = args
        let out = Pipe(), err = Pipe(), inp = Pipe()
        p.standardOutput = out
        p.standardError = err
        p.standardInput = stdin == nil ? FileHandle.nullDevice : inp
        var outData = Data(), errData = Data()
        let lock = NSLock()
        out.fileHandleForReading.readabilityHandler = { h in
            let d = h.availableData; lock.lock(); outData.append(d); lock.unlock()
        }
        err.fileHandleForReading.readabilityHandler = { h in
            let d = h.availableData; lock.lock(); errData.append(d); lock.unlock()
        }
        p.terminationHandler = { proc in
            out.fileHandleForReading.readabilityHandler = nil
            err.fileHandleForReading.readabilityHandler = nil
            lock.lock()
            outData.append(out.fileHandleForReading.readDataToEndOfFile())
            errData.append(err.fileHandleForReading.readDataToEndOfFile())
            let r = CommandResult(status: proc.terminationStatus, stdout: outData,
                                  stderr: String(decoding: errData, as: UTF8.self))
            lock.unlock()
            cont.resume(returning: r)
        }
        do {
            try p.run()
            if let stdin { inp.fileHandleForWriting.write(stdin); try? inp.fileHandleForWriting.close() }
        } catch { cont.resume(throwing: error) }
    }
}
