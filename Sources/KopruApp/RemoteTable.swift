import SwiftUI
import AppKit
import UniformTypeIdentifiers
import KopruCore

/// Finder benzeri dosya listesi (NSTableView): çoklu seçim (⌘/⇧/⌘A), çift tıkla klasör aç,
/// seçilenleri masaüstüne/Finder'a sürükle (dosya sözü: indirme bırakınca başlar),
/// dışarıdan dosya sürükleyip yükle (klasörün üstüne bırakırsan o klasöre).
struct RemoteTable: NSViewRepresentable {
    var items: [RemoteItem]
    var onSelect: ([RemoteItem]) -> Void
    var onOpen: (RemoteItem) -> Void
    var onDropFiles: ([URL], RemoteItem?) -> Void
    var onPromise: (RemoteItem, URL, @escaping (Error?) -> Void) -> Void
    var onDownload: () -> Void
    var onDownloadDesktop: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let table = KeyTable()
        table.allowsMultipleSelection = true
        table.usesAlternatingRowBackgroundColors = true
        table.rowHeight = 22
        table.style = .inset
        let name = NSTableColumn(identifier: .init("name")); name.title = "Ad"; name.minWidth = 160
        let size = NSTableColumn(identifier: .init("size")); size.title = "Boyut"; size.width = 90; size.minWidth = 60
        table.addTableColumn(name); table.addTableColumn(size)
        table.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        table.dataSource = context.coordinator
        table.delegate = context.coordinator
        table.target = context.coordinator
        table.doubleAction = #selector(Coordinator.doubleClicked)
        table.onReturn = { [weak c = context.coordinator] in c?.openSelected() }
        table.registerForDraggedTypes([.fileURL])
        table.setDraggingSourceOperationMask(.copy, forLocal: false)
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Seçilenleri indir…", action: #selector(Coordinator.menuDownload), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Seçilenleri Masaüstüne indir", action: #selector(Coordinator.menuDesktop), keyEquivalent: ""))
        menu.items.forEach { $0.target = context.coordinator }
        table.menu = menu
        context.coordinator.table = table
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let c = context.coordinator
        c.parent = self
        if c.items.map(\.id) != items.map(\.id) {
            c.items = items
            c.table?.reloadData()
            onSelect([])
        }
    }

    final class KeyTable: NSTableView {
        var onReturn: (() -> Void)?
        override func keyDown(with event: NSEvent) {
            if event.keyCode == 36 || event.keyCode == 76 { onReturn?() } else { super.keyDown(with: event) }
        }
    }

    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSFilePromiseProviderDelegate {
        var parent: RemoteTable
        var items: [RemoteItem] = []
        weak var table: NSTableView?
        private let queue: OperationQueue = { let q = OperationQueue(); q.maxConcurrentOperationCount = 2; return q }()

        init(_ p: RemoteTable) { parent = p }

        func numberOfRows(in tableView: NSTableView) -> Int { items.count }

        func tableView(_ tv: NSTableView, viewFor col: NSTableColumn?, row: Int) -> NSView? {
            guard row < items.count else { return nil }
            let item = items[row]
            if col?.identifier.rawValue == "size" {
                let cell = makeCell(tv, "sizeCell", icon: false)
                cell.textField?.stringValue = item.isDirectory ? "—" : ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file)
                cell.textField?.alignment = .right
                cell.textField?.textColor = .secondaryLabelColor
                return cell
            }
            let cell = makeCell(tv, "nameCell", icon: true)
            cell.textField?.stringValue = item.name
            let type = item.isDirectory ? UTType.folder : (UTType(filenameExtension: (item.name as NSString).pathExtension) ?? .data)
            cell.imageView?.image = NSWorkspace.shared.icon(for: type)
            return cell
        }

        private func makeCell(_ tv: NSTableView, _ id: String, icon: Bool) -> NSTableCellView {
            let ident = NSUserInterfaceItemIdentifier(id)
            if let c = tv.makeView(withIdentifier: ident, owner: nil) as? NSTableCellView { return c }
            let cell = NSTableCellView(); cell.identifier = ident
            let tf = NSTextField(labelWithString: ""); tf.lineBreakMode = .byTruncatingMiddle
            tf.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(tf); cell.textField = tf
            if icon {
                let iv = NSImageView(); iv.translatesAutoresizingMaskIntoConstraints = false
                cell.addSubview(iv); cell.imageView = iv
                NSLayoutConstraint.activate([
                    iv.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                    iv.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                    iv.widthAnchor.constraint(equalToConstant: 16), iv.heightAnchor.constraint(equalToConstant: 16),
                    tf.leadingAnchor.constraint(equalTo: iv.trailingAnchor, constant: 6)])
            } else {
                tf.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2).isActive = true
            }
            tf.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2).isActive = true
            tf.centerYAnchor.constraint(equalTo: cell.centerYAnchor).isActive = true
            return cell
        }

        // Seçim
        func tableViewSelectionDidChange(_ n: Notification) { parent.onSelect(selectedItems()) }
        func selectedItems() -> [RemoteItem] { (table?.selectedRowIndexes ?? []).compactMap { $0 < items.count ? items[$0] : nil } }

        @objc func doubleClicked() {
            guard let row = table?.clickedRow, row >= 0, row < items.count, items[row].isDirectory else { return }
            parent.onOpen(items[row])
        }
        func openSelected() { if let f = selectedItems().first, f.isDirectory { parent.onOpen(f) } }
        @objc func menuDownload() { parent.onDownload() }
        @objc func menuDesktop() { parent.onDownloadDesktop() }

        // Dışarı sürükleme: dosya sözü (bırakılınca indirilir)
        func tableView(_ tv: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
            guard row < items.count else { return nil }
            let item = items[row]
            let p = NSFilePromiseProvider(fileType: item.isDirectory ? UTType.folder.identifier : (UTType(filenameExtension: (item.name as NSString).pathExtension) ?? .data).identifier,
                                          delegate: self)
            p.userInfo = item
            return p
        }
        func filePromiseProvider(_ p: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
            (p.userInfo as? RemoteItem)?.name ?? "dosya"
        }
        func filePromiseProvider(_ p: NSFilePromiseProvider, writePromiseTo url: URL, completionHandler: @escaping (Error?) -> Void) {
            guard let item = p.userInfo as? RemoteItem else { return completionHandler(nil) }
            parent.onPromise(item, url, completionHandler)
        }
        func operationQueue(for p: NSFilePromiseProvider) -> OperationQueue { queue }

        // İçeri sürükleme: yükleme
        func tableView(_ tv: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation op: NSTableView.DropOperation) -> NSDragOperation {
            if (info.draggingSource as AnyObject?) === tv { return [] }
            guard info.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) else { return [] }
            if op == .on, row >= 0, row < items.count, items[row].isDirectory { return .copy }
            tv.setDropRow(-1, dropOperation: .on)
            return .copy
        }
        func tableView(_ tv: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation op: NSTableView.DropOperation) -> Bool {
            guard let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty else { return false }
            let target = (op == .on && row >= 0 && row < items.count && items[row].isDirectory) ? items[row] : nil
            parent.onDropFiles(urls, target)
            return true
        }
    }
}
