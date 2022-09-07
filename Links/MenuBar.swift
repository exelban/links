//
//  MenuBar.swift
//  Links
//
//  Created by Serhiy Mytrovtsiy on 20/08/2022.
//  Using Swift 5.0.
//  Running on macOS 12.5.
//
//  Copyright © 2022 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

internal class PopupWindow: NSWindow, NSWindowDelegate {
    private var view: PopupView = PopupView()
    
    init() {
        let vc: NSViewController = NSViewController(nibName: nil, bundle: nil)
        let view = NSView(frame: NSRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height))
        view.addSubview(self.view)
        vc.view = view
        
        super.init(
            contentRect: NSRect(
                x: NSScreen.main!.frame.width - vc.view.frame.width,
                y: NSScreen.main!.frame.height - vc.view.frame.height,
                width: vc.view.frame.width,
                height: vc.view.frame.height
            ),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        
        self.contentViewController = vc
        self.titlebarAppearsTransparent = true
        self.animationBehavior = .default
        self.collectionBehavior = .moveToActiveSpace
        self.backgroundColor = .clear
        self.hasShadow = true
        self.setIsVisible(false)
        self.delegate = self
        self.isMovable = false
    }
    
    func windowDidResignKey(_ notification: Notification) {
        self.setIsVisible(false)
    }
}

private class PopupView: NSStackView {
    private let foreground: NSVisualEffectView = {
        let view = NSVisualEffectView(frame: NSRect.zero)
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }()
    
    private let itemsView = ItemsView()
    private let navBarView = NavBarView()
    
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 0, height: 400))
        
        self.orientation = .vertical
        self.distribution = .fill
        self.spacing = 0
        
        self.addArrangedSubview(self.itemsView)
        self.addArrangedSubview(self.navBarView)
        
        self.addSubview(self.foreground, positioned: .below, relativeTo: .none)
        
        let w = self.itemsView.bounds.width
        let h = self.itemsView.bounds.height + self.navBarView.bounds.height
        self.setFrameSize(NSSize(width: w, height: h))
        self.foreground.setFrameSize(self.frame.size)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.reload), name: .reloadList, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func reload() {
        self.itemsView.reload()
        
        let w = self.itemsView.bounds.width
        let h = self.itemsView.bounds.height + self.navBarView.bounds.height
        self.setFrameSize(NSSize(width: w, height: h))
        self.foreground.setFrameSize(self.frame.size)
        self.window?.setContentSize(self.frame.size)
    }
}

private class ItemsView: NSStackView {
    private let emptyBox = EmptyView("No links", isHidden: true, height: 26)
    
    init() {
        super.init(frame: NSRect.zero)
        
        self.orientation = .horizontal
        self.distribution = .fillProportionally
        self.alignment = .bottom
        self.spacing = 14
        self.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 0, right: 14)
        
        self.emptyBox.setFrameSize(NSSize(width: 44, height: 44))
        self.emptyBox.widthAnchor.constraint(equalToConstant: 44).isActive = true
        self.emptyBox.heightAnchor.constraint(equalToConstant: 44).isActive = true
        
        self.addArrangedSubview(self.emptyBox)
        self.reload()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func reload() {
        var views = self.subviews.filter({ $0 is ItemView })
        views.forEach({ $0.removeFromSuperview() })
        
        Items.forEach { (i: Item) in
            self.addArrangedSubview(ItemView(i))
        }
        views = self.subviews.filter({ $0 is ItemView })
        
        if Items.isEmpty {
            self.emptyBox.isHidden = false
            views = self.subviews
        } else if !self.emptyBox.isHidden {
            self.emptyBox.isHidden = true
        }
        
        self.setFrameSize(NSSize(
            width: views.map({ $0.bounds.width + self.spacing }).reduce(0, +) - self.spacing + self.edgeInsets.left + self.edgeInsets.right,
            height: (views.compactMap({ $0.bounds.height }).max() ?? 30) + self.edgeInsets.top + self.edgeInsets.bottom
        ))
    }
}

private class NavBarView: NSStackView {
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 0, height: 28))
        
        self.orientation = .horizontal
        self.alignment = .centerY
        self.spacing = 0
        self.edgeInsets = NSEdgeInsets(top: 0, left: 7, bottom: 0, right: 7)
        
        let addButton = NSButton(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
        addButton.bezelStyle = .regularSquare
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.imageScaling = .scaleNone
        addButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: nil)
        addButton.contentTintColor = .controlTextColor
        addButton.toolTip = "Add link"
        addButton.isBordered = false
        addButton.target = self
        addButton.focusRingType = .none
        addButton.action = #selector(self.newLink)
        
        let settingsButton = NSButton(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
        settingsButton.bezelStyle = .regularSquare
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.imageScaling = .scaleNone
        settingsButton.image = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: nil)
        settingsButton.toolTip = "Open settings"
        settingsButton.isBordered = false
        settingsButton.target = self
        settingsButton.focusRingType = .none
        settingsButton.action = #selector(self.openSettings)
        
        self.addArrangedSubview(addButton)
        self.addArrangedSubview(NSView())
        self.addArrangedSubview(settingsButton)
        
        self.heightAnchor.constraint(equalToConstant: self.frame.height).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func newLink() {
        NotificationCenter.default.post(name: .showNewLink, object: nil, userInfo: nil)
    }
    
    @objc private func openSettings() {
        NotificationCenter.default.post(name: .openSettings, object: nil, userInfo: nil)
    }
}

internal class ItemView: NSStackView, NSMenuDelegate {
    private let item: Item
    
    init(_ item: Item) {
        self.item = item
        
        super.init(frame: NSRect(x: 0, y: 0, width: 44, height: 44))
        
        self.orientation = .vertical
        self.distribution = .fill
        self.alignment = .centerY
        self.spacing = 0
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.1).cgColor
        self.layer?.cornerRadius = 4
        self.edgeInsets = NSEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        
        self.toolTip = item.name ?? item.url.absoluteString
        
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(NSMenuItem(title: "Open", action: #selector(self.openByMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Delete", action: #selector(self.deleteByMenu), keyEquivalent: ""))
        
        self.menu = menu
        
        let imageView = NSImageView()
        item.setIcon(imageView)
        
        self.addArrangedSubview(imageView)
        
        let trackingArea = NSTrackingArea(
            rect: CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height),
            options: [NSTrackingArea.Options.activeAlways, NSTrackingArea.Options.mouseEnteredAndExited, NSTrackingArea.Options.activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        self.addTrackingArea(trackingArea)
        
        self.widthAnchor.constraint(equalToConstant: self.frame.width).isActive = true
        self.heightAnchor.constraint(equalToConstant: self.frame.height).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func mouseEntered(with: NSEvent) {
        self.layer?.backgroundColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.13).cgColor
        NSCursor.pointingHand.set()
    }
    
    override func mouseExited(with: NSEvent) {
        self.layer?.backgroundColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.1).cgColor
        NSCursor.arrow.set()
    }
    
    override func mouseDown(with event: NSEvent) {
        self.item.handler()
    }
    
    @objc private func openByMenu(_ sender: NSTableView) {
        self.item.handler()
    }
    
    @objc private func deleteByMenu(_ sender: NSMenuItem) {
        NotificationCenter.default.post(name: .showDeleteLink, object: nil, userInfo: ["idx": self.item.index])
    }
}
