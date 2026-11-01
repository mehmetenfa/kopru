import SwiftUI
import KopruCore

struct ContentView: View {
    @EnvironmentObject private var m: Model

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            pathBar
            RemoteTable(
                items: m.items,
                onSelect: { m.selection = $0 },
                onOpen: { m.open($0.path) },
                onDropFiles: { urls, folder in m.upload(urls, into: folder) },
                onPromise: { item, url, done in
                    Task { @MainActor in
                        do { try await m.promiseDownload(item, to: url); done(nil) } catch { done(error) }
                    }
                },
                onDownload: { m.downloadSelected(forceAsk: true) },
                onDownloadDesktop: { m.downloadSelected(to: m.desktop) }
            )
            Divider()
            downloadBar
            Divider()
            statusBar
        }
    }

    private var topBar: some View {
        HStack {
            TextField("kullanıcı@sunucu (ör. ad@pc-adi)", text: $m.host)
                .textFieldStyle(.roundedBorder).frame(width: 260).disabled(m.connected)
            if !m.hosts.isEmpty && !m.connected {
                Menu("Kayıtlı") { ForEach(m.hosts, id: \.self) { h in Button(h) { m.host = h } } }.fixedSize()
            }
            if m.connected {
                Button { m.disconnect() } label: { Label("Bağlantıyı kes", systemImage: "bolt.slash") }
            } else {
                Button { m.connect() } label: { Label("Bağlan", systemImage: "bolt") }
                    .disabled(m.host.trimmingCharacters(in: .whitespaces).isEmpty || m.busy)
            }
            Spacer()
            Toggle("SHA-256 doğrula", isOn: $m.verify).toggleStyle(.checkbox)
                .help("Aktarım sonrası dosya iki tarafta okunup karşılaştırılır. Çok büyük dosyalarda biraz zaman alır.")
            Menu("Pano") {
                Button("Windows panosunu al") { m.pullClipboard() }
                Button("Mac panosunu gönder") { m.pushClipboard() }
            }.disabled(!m.connected || m.busy).fixedSize()
        }.padding(10)
    }

    private var pathBar: some View {
        HStack {
            Button { m.up() } label: { Image(systemName: "arrow.up") }.disabled(m.cwd.isEmpty || m.busy).help("Üst klasör")
            Button { m.open(m.cwd) } label: { Image(systemName: "arrow.clockwise") }.disabled(m.cwd.isEmpty || m.busy).help("Yenile")
            Text(m.cwd.isEmpty ? "Bağlanınca klasör burada görünür" : m.cwd)
                .font(.system(.body, design: .monospaced)).lineLimit(1).truncationMode(.head)
            Spacer()
        }.padding(.horizontal, 10).padding(.vertical, 6)
    }

    private var downloadBar: some View {
        HStack(spacing: 10) {
            Text(m.selection.isEmpty ? "Seçili öğe yok" : "\(m.selection.count) öğe seçili").font(.caption).foregroundStyle(.secondary)
            Spacer()
            Toggle("Her indirmede yeri sor", isOn: $m.askEachTime).toggleStyle(.checkbox).font(.caption)
            Menu {
                Button("Masaüstü") { m.destination = m.desktop }
                Button("İndirilenler") { m.destination = m.downloads }
                Button("Belgeler") { m.destination = m.documents }
                Divider()
                Button("Başka klasör seç…") { _ = m.chooseDestination() }
            } label: {
                Label("Kaydet: \(m.destination.lastPathComponent)", systemImage: "folder")
            }.fixedSize().help(m.destination.path)
            Button {
                m.downloadSelected()
            } label: { Label("Seçilenleri indir", systemImage: "arrow.down.circle.fill") }
                .buttonStyle(.borderedProminent)
                .disabled(m.selection.isEmpty || m.busy || !m.connected)
        }.padding(8)
    }

    private var statusBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let p = m.progress {
                HStack {
                    if p.phase == .transferring { ProgressView(value: p.fraction) } else { ProgressView().progressViewStyle(.linear) }
                    if p.phase == .transferring { Text(String(format: "%.0f%%", p.fraction * 100)).font(.caption.monospacedDigit()) }
                    Button("İptal") { m.cancel() }
                }
                if !m.batchInfo.isEmpty { Text(m.batchInfo).font(.caption).lineLimit(1) }
                Text(p.summary).font(.caption).foregroundStyle(.secondary)
            } else if m.busy {
                HStack { ProgressView().controlSize(.small); Button("İptal") { m.cancel() } }
            }
            Text(m.status).font(.caption).lineLimit(3)
        }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
    }
}
