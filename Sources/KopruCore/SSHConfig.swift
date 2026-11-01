import Foundation

/// ~/.ssh/config içindeki (joker olmayan) Host takma adlarını okur.
public enum SSHConfig {
    public static func hostAliases(configPath: String = NSHomeDirectory() + "/.ssh/config") -> [String] {
        guard let text = try? String(contentsOfFile: configPath, encoding: .utf8) else { return [] }
        return parseAliases(text)
    }

    static func parseAliases(_ text: String) -> [String] {
        var result: [String] = []
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard line.lowercased().hasPrefix("host ") else { continue }
            for name in line.dropFirst(5).split(separator: " ") {
                let n = String(name)
                if !n.contains("*") && !n.contains("?") && !n.hasPrefix("!") && !result.contains(n) {
                    result.append(n)
                }
            }
        }
        return result
    }
}
