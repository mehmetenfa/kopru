import SwiftUI
import KopruCore
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var m = Model()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("kullanıcı@sunucu (ör. ad@misalpc1)", text: $m.host).frame(width: 260).textFieldStyle(.roundedBorder)
                if !m.hosts.isEmpty {
                    Menu("Kayıtlı") { ForEach(m.hosts, id: \.self) { h in Button(h) { m.host = h } } }.fixedSize()
                }
                Button("Bağlan") { m.open(nil) }.disabled(m.host.isEmpty || m.busy)
                Toggle("SHA-256 doğrula", isOn: $m.verify).toggleStyle(.checkbox).help("Aktarım sonrası dosya iki tarafta okunup karşılaştırılır. Çok büyük dosyalarda biraz zaman alır.")
                Spacer()
                Menu("Pano") {
                    Button("Windows panosunu al") { m.pullClipboard() }
                    Button("Mac panosunu gönder") { m.pushClipboard() }
                }.disabled(m.host.isEmpty || m.busy).fixedSize()
            }.padding(10)
            Divider()
            HStack {
                Button { m.up() } label: { Image(systemName: "arrow.up") }.disabled(m.cwd.isEmpty)
                Text(m.cwd.isEmpty ? "Bağlanınca klasör burada görünür" : m.cwd).font(.system(.body, design: .monospaced)).lineLimit(1).truncationMode(.head)
                Spacer()
            }.padding(.horizontal, 10).padding(.vertical, 6)
            List(m.items) { item in
                HStack {
                    Image(systemName: item.isDirectory ? "folder.fill" : "doc").foregroundStyle(item.isDirectory ? Color.accentColor : .secondary)
                    Text(item.name)
                    Spacer()
                    if !item.isDirectory { Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file)).foregroundStyle(.secondary).font(.caption) }
                    Button { m.download(item) } label: { Image(systemName: "arrow.down.circle") }.buttonStyle(.borderless).help("Mac'e indir (doğrulamalı)")
                }
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { if item.isDirectory { m.open(item.path) } }
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                for p in providers {
                    p.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                        if let d = data as? Data, let u = URL(dataRepresentation: d, relativeTo: nil) { Task { @MainActor in m.upload([u]) } }
                    }
                }
                return true
            }
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                if let p = m.progress {
                    HStack {
                        if p.phase == .transferring { ProgressView(value: p.fraction) } else { ProgressView().progressViewStyle(.linear) }
                        if p.phase == .transferring { Text(String(format: "%.0f%%", p.fraction * 100)).font(.caption.monospacedDigit()) }
                        Button("İptal") { m.cancel() }
                    }
                    Text(p.summary).font(.caption).foregroundStyle(.secondary)
                } else if m.busy {
                    HStack { ProgressView().controlSize(.small); Button("İptal") { m.cancel() } }
                }
                Text(m.status).font(.caption).lineLimit(2)
            }.padding(8)
        }
    }
}
