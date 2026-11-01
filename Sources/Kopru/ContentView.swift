import SwiftUI
import KopruCore
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var m = Model()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if m.hosts.isEmpty {
                    TextField("ssh takma adı (~/.ssh/config)", text: $m.host).frame(width: 220)
                } else {
                    Picker("Windows", selection: $m.host) { ForEach(m.hosts, id: \.self) { Text($0) } }.frame(width: 240)
                }
                Button("Bağlan") { m.open(nil) }.disabled(m.host.isEmpty || m.busy)
                Spacer()
                Menu("Pano") {
                    Button("Windows panosunu al") { m.pullClipboard() }
                    Button("Mac panosunu gönder") { m.pushClipboard() }
                    Divider()
                    Button("Pano yardımcısını kur (bir kez)") { m.setupClipboard() }
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
                .onTapGesture(count: 2) { if item.isDirectory { m.open(item.FullName) } }
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
            HStack { if m.busy { ProgressView().controlSize(.small) }; Text(m.status).font(.caption); Spacer() }.padding(8)
        }
    }
}
