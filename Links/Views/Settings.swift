//
//  Settings.swift
//  Links
//
//  Created by Serhiy Mytrovtsiy on 21/08/2022.
//  Using Swift 5.0.
//  Running on macOS 12.5.
//
//  Copyright © 2022 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

class CustomViewController: NSViewController {
    let _view: NSView
    
    public init(view: NSView) {
        self._view = view
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        self.view = self._view
    }
}

internal class SettingsWindow: NSWindow, NSWindowDelegate {
    private let size: NSSize = NSSize(width: 360, height: 400)
    
    private let foreground: NSVisualEffectView = {
        let view = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 360, height: 400))
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }()
    
    lazy var tabViewController: NSTabViewController = {
        let tabVC = NSTabViewController()
        tabVC.tabStyle = .toolbar
        
        let v1 = CustomViewController(view: LinksSettingsView())
        v1.preferredContentSize = self.size
        
        let v2 = CustomViewController(view: AppSettingsView())
        v2.preferredContentSize = self.size
        
        let tab1 = NSTabViewItem(viewController: v1)
        tab1.label = "Links"
        tab1.image = NSImage(systemSymbolName: "list.bullet", accessibilityDescription: nil)
        
        let tab2 = NSTabViewItem(viewController: v2)
        tab2.label = "Application"
        tab2.image = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: nil)
        
        tabVC.addTabViewItem(tab1)
        tabVC.addTabViewItem(tab2)
        
        tabVC.view.addSubview(self.foreground, positioned: .below, relativeTo: .none)
        
        return tabVC
    }()
    
    init() {
        super.init(
            contentRect: NSRect(
                x: NSScreen.main!.frame.width - self.size.width,
                y: NSScreen.main!.frame.height - self.size.height,
                width: self.size.width,
                height: self.size.height
            ),
            styleMask: [.closable, .titled],
            backing: .buffered,
            defer: true
        )
        
        self.title = "Settings"
        self.contentViewController = self.tabViewController
        self.animationBehavior = .default
        self.backgroundColor = .clear
        self.hasShadow = true
        self.center()
        self.setIsVisible(false)
        self.delegate = self
        self.titlebarSeparatorStyle = .line
        
        let windowController = NSWindowController()
        windowController.window = self
        windowController.loadWindow()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.open), name: .openSettings, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func open(_ notification: Notification) {
        guard !self.isVisible else { return }
        self.setIsVisible(true)
        self.makeKeyAndOrderFront(nil)
    }
}

private class LinksSettingsView: NSStackView {
    private let tableView = TableView()
    
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 360, height: 400))
        
        self.orientation = .vertical
        self.spacing = 0
        
        self.addArrangedSubview(self.tableView)
        self.addArrangedSubview(self.buttons())
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func buttons() -> NSView {
        let view = NSStackView()
        view.heightAnchor.constraint(equalToConstant: 30).isActive = true
        view.edgeInsets = NSEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        
        view.orientation = .vertical
        view.spacing = 8
        view.alignment = .centerY
        view.distribution = .fillEqually
        
        let addButton = NSButton()
        addButton.bezelStyle = .roundRect
        addButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: nil)
        addButton.toolTip = "Add link"
        addButton.focusRingType = .none
        addButton.target = self
        addButton.action = #selector(self.newLink)
        
        view.addArrangedSubview(addButton)
        
        return view
    }
    
    @objc public func newLink() {
        NotificationCenter.default.post(name: .showNewLink, object: nil, userInfo: nil)
    }
}

private class TableView: NSView, NSTableViewDelegate, NSTableViewDataSource, NSMenuDelegate, NSTextFieldDelegate {
    private let emptyView = EmptyView("No links", isHidden: true)
    
    private let scrollView = NSScrollView()
    private let tableView = TableViewWithActiveRow()
    
    private var dragDropType = NSPasteboard.PasteboardType(rawValue: "\(Bundle.main.bundleIdentifier!).links-row")
    
    init() {
        super.init(frame: NSRect.zero)
        
        self.wantsLayer = true
        self.layer?.cornerRadius = 3
        
        self.scrollView.translatesAutoresizingMaskIntoConstraints = false
        self.scrollView.documentView = self.tableView
        self.scrollView.hasHorizontalScroller = false
        self.scrollView.hasVerticalScroller = true
        self.scrollView.autohidesScrollers = true
        self.scrollView.backgroundColor = NSColor.clear
        self.scrollView.drawsBackground = true
        
        self.tableView.frame = self.scrollView.bounds
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.headerView = nil
        self.tableView.backgroundColor = NSColor.clear
        self.tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        self.tableView.registerForDraggedTypes([dragDropType])
        self.tableView.doubleAction = #selector(self.openByDoubleClick)
        self.tableView.gridColor = .gridColor
        self.tableView.gridStyleMask = .solidHorizontalGridLineMask
        
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(NSMenuItem(title: "New link", action: #selector(self.newLink), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Open", action: #selector(self.openByMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Edit", action: #selector(self.editByMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Delete", action: #selector(self.deleteByMenu), keyEquivalent: ""))
        self.tableView.menu = menu
        
        let colURL = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "url"))
        colURL.title = "URL"
        self.tableView.addTableColumn(colURL)
        
        self.addSubview(self.emptyView)
        self.addSubview(self.scrollView)
        
        self.emptyView.isHidden = !Items.isEmpty
        self.scrollView.isHidden = Items.isEmpty
        
        NSLayoutConstraint.activate([
            self.emptyView.widthAnchor.constraint(equalTo: self.widthAnchor),
            self.emptyView.heightAnchor.constraint(equalTo: self.heightAnchor),
            
            self.scrollView.leftAnchor.constraint(equalTo: self.leftAnchor),
            self.scrollView.rightAnchor.constraint(equalTo: self.rightAnchor),
            self.scrollView.topAnchor.constraint(equalTo: self.topAnchor),
            self.scrollView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.reload), name: .reloadList, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func reload() {
        self.emptyView.isHidden = !Items.isEmpty
        self.scrollView.isHidden = Items.isEmpty
        
        self.tableView.reloadData()
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return Items.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let link = Items[row]
        
        let text: NSTextField = TextField()
        text.drawsBackground = false
        text.isBordered = false
        text.isEditable = false
        text.isSelectable = false
        text.translatesAutoresizingMaskIntoConstraints = false
        text.identifier = NSUserInterfaceItemIdentifier(link.id.uuidString)
        text.delegate = self
        
        switch tableColumn?.identifier.rawValue {
        case "url":
            text.stringValue = link.url.absoluteString
        default: break
        }
        
        text.sizeToFit()
        
        let cell = NSTableCellView()
        cell.addSubview(text)
        
        NSLayoutConstraint.activate([
            text.widthAnchor.constraint(equalTo: cell.widthAnchor),
            text.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        
        return cell
    }
    
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = NSTableRowView()
        rowView.isEmphasized = false
        return rowView
    }
    
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let item = NSPasteboardItem()
        item.setString(String(row), forType: self.dragDropType)
        return item
    }
    
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        if dropOperation == .above {
            return .move
        }
        return []
    }
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        var oldIndexes = [Int]()
        info.enumerateDraggingItems(options: [], for: tableView, classes: [NSPasteboardItem.self], searchOptions: [:]) { dragItem, _, _ in
            if let str = (dragItem.item as! NSPasteboardItem).string(forType: self.dragDropType), let index = Int(str) {
                oldIndexes.append(index)
            }
        }
        
        var oldIndexOffset = 0
        var newIndexOffset = 0
        
        tableView.beginUpdates()
        for oldIndex in oldIndexes {
            if oldIndex < row {
                let currentIdx = oldIndex + oldIndexOffset
                let newIdx = row - 1
                
                Items[currentIdx].index = newIdx
                Items[newIdx].index = currentIdx
                tableView.reloadData()
                
                oldIndexOffset -= 1
            } else {
                let currentIdx = oldIndex
                let newIdx = row + newIndexOffset
                
                Items[currentIdx].index = newIdx
                Items[newIdx].index = currentIdx
                tableView.reloadData()
                
                newIndexOffset += 1
            }
        }
        tableView.endUpdates()
        
        return true
    }
    
    func menuWillOpen(_ menu: NSMenu) {
        if self.tableView.activeRow == -1 {
            menu.items[1].isHidden = true
            menu.items[2].isHidden = true
            menu.items[3].isHidden = true
        } else {
            menu.items[0].isHidden = true
        }
    }
    
    func menuDidClose(_ menu: NSMenu) {
        menu.items.forEach({ $0.isHidden = false })
    }
    
    @objc private func newLink(_ sender: NSTableView) {
        NotificationCenter.default.post(name: .showNewLink, object: nil, userInfo: nil)
    }
    
    @objc private func openByDoubleClick(_ sender: NSTableView) {
        guard sender.selectedRow >= 0,
              let row = self.tableView.rowView(atRow: sender.selectedRow, makeIfNecessary: false),
              let cell = row.subviews.first(where: { $0 is NSTableCellView }),
              let field = cell.subviews.first(where: { $0 is NSTextField }) as? NSTextField else { return }
        
        field.isEditable = true
        field.becomeFirstResponder()
        
        self.tableView.activeRow = -1
    }
    
    @objc private func openByMenu(_ sender: NSTableView) {
        guard self.tableView.activeRow != -1 else { return }
        
        if Items.indices.contains(self.tableView.activeRow) {
            Items[self.tableView.activeRow].handler()
        }
    }
    
    @objc private func editByMenu(_ sender: NSMenuItem) {
        guard self.tableView.activeRow != -1,
              let row = self.tableView.rowView(atRow: self.tableView.activeRow, makeIfNecessary: false),
              let cell = row.subviews.first(where: { $0 is NSTableCellView }),
              let field = cell.subviews.first(where: { $0 is NSTextField }) as? NSTextField else { return }
        
        field.isEditable = true
        field.becomeFirstResponder()
        
        self.tableView.activeRow = -1
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField,
              let id = field.identifier?.rawValue,
              let idx = Items.firstIndex(where: { $0.id.uuidString == id }) else { return }
        
        Items[idx].url = URL(string: field.stringValue)!
        field.isEditable = false
    }
    
    @objc private func deleteByMenu(_ sender: NSMenuItem) {
        guard self.tableView.activeRow != -1 else { return }
        NotificationCenter.default.post(name: .showDeleteLink, object: nil, userInfo: ["idx": self.tableView.activeRow])
    }
}

private class AppSettingsView: NSStackView {
    private var updateSelector: NSPopUpButton?
    private var startAtLoginBtn: NSButton?
    
    init() {
        super.init(frame: NSRect.zero)
        
        self.orientation = .vertical
        self.distribution = .fill
        self.spacing = 0
        
        self.addArrangedSubview(self.informationView())
        self.addArrangedSubview(self.separatorView())
        self.addArrangedSubview(self.settingsView())
        self.addArrangedSubview(self.separatorView())
        self.addArrangedSubview(self.buttonsView())
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func informationView() -> NSView {
        let view = NSStackView()
        view.heightAnchor.constraint(equalToConstant: 160).isActive = true
        view.orientation = .vertical
        view.distribution = .fill
        view.alignment = .centerY
        view.spacing = 0
        
        let container: NSGridView = NSGridView()
        container.heightAnchor.constraint(equalToConstant: 115).isActive = true
        container.rowSpacing = 0
        container.yPlacement = .center
        container.xPlacement = .center
        
        let iconView: NSImageView = NSImageView(image: NSImage(named: NSImage.Name("AppIcon"))!)
        
        let statsName: NSTextField = self.textView(NSRect(x: 0, y: 0, width: view.frame.width, height: 22))
        statsName.alignment = .center
        statsName.font = NSFont.systemFont(ofSize: 20, weight: .regular)
        statsName.stringValue = "Links"
        statsName.isSelectable = true
        
        let versionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
        
        let statsVersion: NSTextField = self.textView(NSRect(x: 0, y: 0, width: view.frame.width, height: 16))
        statsVersion.alignment = .center
        statsVersion.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        statsVersion.stringValue = "\("Version") \(versionNumber)"
        statsVersion.isSelectable = true
        statsVersion.toolTip = "\("Build number") \(buildNumber)"
        
        let updateButton: NSButton = NSButton()
        updateButton.title = "Check for update"
        updateButton.bezelStyle = .rounded
        updateButton.target = self
        
        container.addRow(with: [iconView])
        container.addRow(with: [statsName])
        container.addRow(with: [statsVersion])
//        container.addRow(with: [updateButton])
        
        container.row(at: 1).height = 22
        container.row(at: 2).height = 20
//        container.row(at: 3).height = 30
        
        view.addArrangedSubview(container)
        
        return view
    }
    
    private func settingsView() -> NSView {
        let view: NSView = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 0))
        
        let grid: NSGridView = NSGridView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: 0))
        grid.rowSpacing = 10
        grid.columnSpacing = 20
        grid.xPlacement = .trailing
        grid.rowAlignment = .firstBaseline
        grid.translatesAutoresizingMaskIntoConstraints = false
        
        grid.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        grid.setContentHuggingPriority(.defaultHigh, for: .vertical)
        
        grid.addRow(with: [NSGridCell.emptyContentView, self.toggleView(
            action: #selector(self.toggleDock),
            state: Store.shared.bool(key: "dockIcon", defaultValue: false),
            text: "Show icon in dock"
        )])
        self.startAtLoginBtn = self.toggleView(
            action: #selector(self.toggleLaunchAtLogin),
            state: LaunchAtLogin.isEnabled,
            text: "Start at login"
        )
        grid.addRow(with: [NSGridCell.emptyContentView, self.startAtLoginBtn!])
        
        view.addSubview(grid)
        
        NSLayoutConstraint.activate([
            grid.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            grid.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        return view
    }
    
    private func buttonsView() -> NSView {
        let view = NSStackView()
        view.heightAnchor.constraint(equalToConstant: 60).isActive = true
        
        let reset: NSButton = NSButton()
        reset.title = "Close app"
        reset.bezelStyle = .rounded
        reset.target = self
        reset.action = #selector(self.closeApp)
        
        view.addArrangedSubview(reset)
        
        return view
    }
    // MARK: - helpers
    
    private func separatorView() -> NSBox {
        let view = NSBox()
        view.boxType = .separator
        return view
    }
    
    private func titleView(_ value: String) -> NSTextField {
        let field: NSTextField = self.textView(NSRect(x: 0, y: 0, width: 120, height: 17))
        field.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        field.textColor = .secondaryLabelColor
        field.stringValue = value
        
        return field
    }
    
    private func toggleView(action: Selector, state: Bool, text: String) -> NSButton {
        let button: NSButton = NSButton(frame: NSRect(x: 0, y: 0, width: 30, height: 20))
        button.setButtonType(.switch)
        button.state = state ? .on : .off
        button.title = text
        button.action = action
        button.isBordered = false
        button.isTransparent = false
        button.target = self
        
        return button
    }
    
    private func textView(_ frame: NSRect) -> NSTextField {
        let view = NSTextField(frame: frame)
        view.isEditable = false
        view.isSelectable = false
        view.isBezeled = false
        view.wantsLayer = true
        view.textColor = .labelColor
        view.backgroundColor = .clear
        view.canDrawSubviewsIntoLayer = true
        view.alignment = .natural
        
        return view
    }
    
    @objc func toggleDock(_ sender: NSButton) {
        let state = sender.state
        
        Store.shared.set(key: "dockIcon", value: state == NSControl.StateValue.on)
        let dockIconStatus = state == NSControl.StateValue.on ? NSApplication.ActivationPolicy.regular : NSApplication.ActivationPolicy.accessory
        NSApp.setActivationPolicy(dockIconStatus)
        if state == .off {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
    
    @objc func toggleLaunchAtLogin(_ sender: NSButton) {
        LaunchAtLogin.isEnabled = sender.state == NSControl.StateValue.on
        if !Store.shared.exist(key: "runAtLoginInitialized") {
            Store.shared.set(key: "runAtLoginInitialized", value: true)
        }
    }
    
    @objc private func closeApp(_ sender: Any) {
        NSApp.terminate(sender)
    }
}
