import Foundation

public enum ClipboardContent {
    case text(String)
    case image(Data) // PNG
    case empty
}

/// Windows panosu: WSL'den powershell.exe (interop) ile kullanıcının masaüstü panosuna doğrudan erişilir.
/// Veri base64 ile taşınır; görseller PNG olarak, yeniden sıkıştırmadan gelir.
public extension SSHSession {
    func pullClipboard() async throws -> ClipboardContent {
        let r = try await powershell(#"""
        Add-Type -AssemblyName System.Windows.Forms,System.Drawing
        if ([Windows.Forms.Clipboard]::ContainsImage()) {
          $ms = New-Object IO.MemoryStream
          [Windows.Forms.Clipboard]::GetImage().Save($ms, [Drawing.Imaging.ImageFormat]::Png)
          'image:' + [Convert]::ToBase64String($ms.ToArray())
        } elseif ([Windows.Forms.Clipboard]::ContainsText()) {
          'text:' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([Windows.Forms.Clipboard]::GetText()))
        } else { 'empty:' }
        """#)
        let line = r.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let colon = line.firstIndex(of: ":") else { throw KopruError.badRemoteOutput(String(line.prefix(200))) }
        let kind = line[..<colon], body = String(line[line.index(after: colon)...])
        let data = Data(base64Encoded: body) ?? Data()
        switch kind {
        case "image": return .image(data)
        case "text": return .text(String(decoding: data, as: UTF8.self))
        default: return .empty
        }
    }

    func pushClipboardText(_ text: String) async throws {
        try await powershell(#"""
        Add-Type -AssemblyName System.Windows.Forms
        $t = [Console]::In.ReadToEnd().Trim()
        [Windows.Forms.Clipboard]::SetText([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($t)))
        """#, stdin: Data(Data(text.utf8).base64EncodedString().utf8))
    }

    func pushClipboardImage(png: Data) async throws {
        try await powershell(#"""
        Add-Type -AssemblyName System.Windows.Forms,System.Drawing
        $t = [Console]::In.ReadToEnd().Trim()
        $ms = New-Object IO.MemoryStream (,[Convert]::FromBase64String($t))
        [Windows.Forms.Clipboard]::SetImage([Drawing.Image]::FromStream($ms))
        """#, stdin: Data(png.base64EncodedString().utf8))
    }
}
