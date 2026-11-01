import Foundation
import AppKit

/// Windows panosu. NOT: sshd servis olarak çalıştığı için ssh oturumu kullanıcının masaüstü
/// panosuna doğrudan erişemez. Bu yüzden kullanıcının AÇIK oturumunda çalışan küçük bir
/// zamanlanmış görev ("KopruClip", /IT) kullanılır. Deneysel: gerçek Windows'ta doğrulanmalı.
public extension SSHSession {
    private var agentDir: String { "$env:LOCALAPPDATA\\Kopru" }

    /// Windows tarafına yardımcı betiği ve görevi kurar (bir kez).
    func installClipboardAgent() async throws {
        let script = #"""
        $d = Join-Path $env:LOCALAPPDATA 'Kopru'; New-Item -ItemType Directory -Force $d | Out-Null
        $agent = @'
        Add-Type -AssemblyName System.Windows.Forms, System.Drawing
        $d = Join-Path $env:LOCALAPPDATA 'Kopru'
        $mode = (Get-Content (Join-Path $d 'mode.txt') -Raw).Trim()
        if ($mode -eq 'get') {
          if ([Windows.Forms.Clipboard]::ContainsImage()) {
            $img = [Windows.Forms.Clipboard]::GetImage(); $img.Save((Join-Path $d 'out.png'), [Drawing.Imaging.ImageFormat]::Png)
            Set-Content (Join-Path $d 'kind.txt') 'image'
          } else {
            $t = [Windows.Forms.Clipboard]::GetText(); [IO.File]::WriteAllText((Join-Path $d 'out.txt'), $t, (New-Object Text.UTF8Encoding $false))
            Set-Content (Join-Path $d 'kind.txt') 'text'
          }
        } elseif ($mode -eq 'set') {
          $t = [IO.File]::ReadAllText((Join-Path $d 'in.txt'), [Text.Encoding]::UTF8)
          [Windows.Forms.Clipboard]::SetText($t)
        }
        Set-Content (Join-Path $d 'done.txt') (Get-Date).Ticks
        '@
        Set-Content -Path (Join-Path $d 'clip.ps1') -Value $agent -Encoding UTF8
        $u = "$env:USERDOMAIN\$env:USERNAME"
        schtasks /Create /F /TN KopruClip /SC ONCE /ST 00:00 /IT /RU $u /RL LIMITED /TR "powershell -NoProfile -WindowStyle Hidden -STA -ExecutionPolicy Bypass -File `"$d\clip.ps1`"" | Out-Null
        'ok'
        """#
        try await powershell(script)
    }

    private func runAgent(mode: String, prepare: String = "") async throws {
        let script = """
        $d = Join-Path $env:LOCALAPPDATA 'Kopru'
        Remove-Item "$d\\done.txt" -ErrorAction SilentlyContinue
        Set-Content "$d\\mode.txt" '\(mode)'
        \(prepare)
        schtasks /Run /TN KopruClip | Out-Null
        for ($i=0; $i -lt 100; $i++) { if (Test-Path "$d\\done.txt") { break }; Start-Sleep -Milliseconds 100 }
        if (-not (Test-Path "$d\\done.txt")) { throw 'Windows panosu zaman aşımı (kullanıcı oturumu açık mı?)' }
        """
        try await powershell(script)
    }

    enum ClipboardContent { case text(String), image(URL) }

    /// Windows panosunu Mac'e alır (görsel PNG olarak, kayıpsız).
    func pullClipboard() async throws -> ClipboardContent {
        try await runAgent(mode: "get")
        let kind = try await powershell("Get-Content \"$env:LOCALAPPDATA\\Kopru\\kind.txt\"").text.trimmingCharacters(in: .whitespacesAndNewlines)
        if kind == "image" {
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("kopru-clip.png")
            try? FileManager.default.removeItem(at: tmp)
            try await scp([scpRemote("%LOCALAPPDATA%/Kopru/out.png".replacingOccurrences(of: "%LOCALAPPDATA%", with: try await localAppData())), tmp.path])
            return .image(tmp)
        }
        let b64 = try await powershell("[Convert]::ToBase64String([IO.File]::ReadAllBytes(\"$env:LOCALAPPDATA\\Kopru\\out.txt\"))").text
        let data = Data(base64Encoded: b64.trimmingCharacters(in: .whitespacesAndNewlines)) ?? Data()
        return .text(String(decoding: data, as: UTF8.self))
    }

    func pushClipboardText(_ text: String) async throws {
        let b64 = Data(text.utf8).base64EncodedString()
        try await runAgent(mode: "set", prepare: "[IO.File]::WriteAllBytes(\"$d\\in.txt\", [Convert]::FromBase64String('\(b64)'))")
    }

    private func localAppData() async throws -> String {
        try await powershell("$env:LOCALAPPDATA").text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\\", with: "/")
    }
}
