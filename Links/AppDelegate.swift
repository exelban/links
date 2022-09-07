//
//  AppDelegate.swift
//  Links
//
//  Created by Serhiy Mytrovtsiy on 20/08/2022.
//  Using Swift 5.0.
//  Running on macOS 12.5.
//
//  Copyright © 2022 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Updater

let updater = Updater(name: "Links",
    providers: [
        Updater.Github(user: "exelban", repo: "links", asset: "Links.dmg")
    ]
)

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private let icon: Icon = Icon()
    private let item: NSStatusItem = {
        let item = NSStatusBar.system.statusItem(withLength: Icon.size.width)
        item.autosaveName = Bundle.main.bundleIdentifier
        return item
    }()
    
    private let popup: PopupWindow = PopupWindow()
    private let settings: SettingsWindow = SettingsWindow()
    
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        updater.cleanup()
        
        self.defaults()
        
        if let button = item.button {
            button.addSubview(self.icon)
            button.target = self
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
            button.action = #selector(self.togglePopup)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(self.showNewAlert), name: .showNewLink, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.showDeleteAlert), name: .showDeleteLink, object: nil)
        
        self.checkForUpdate()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {}
}

extension AppDelegate {
    private func defaults() {
        if !Store.shared.exist(key: "runAtLoginInitialized") {
            Store.shared.set(key: "runAtLoginInitialized", value: true)
            LaunchAtLogin.isEnabled = true
        }
        
        NSApp.setActivationPolicy(Store.shared.bool(key: "dockIcon", defaultValue: false) ? NSApplication.ActivationPolicy.regular : NSApplication.ActivationPolicy.accessory)
    }
    
    private func checkForUpdate() {
        updater.check() { result, error in
            if error != nil {
                print("error updater.check(): %s", "\(error!)")
                return
            }
            
            guard let external = result else {
                print("no external release found")
                return
            }
            let local = Updater.Tag("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String)")
            
            if local >= external.tag {
                return
            }
            
            DispatchQueue.main.async(execute: {
                print("show update window because new version of app found: %s", "\(external.tag.raw)")
                
                let alert = NSAlert()
                alert.messageText = "New version available"
                alert.informativeText = "Current version:   \(local.raw)\nLatest version:     \(external.tag.raw)"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Install")
                alert.addButton(withTitle: "Cancel")
                
                if alert.runModal() == .alertFirstButtonReturn {
                    if let url = URL(string: external.url) {
                        updater.download(url, done: { path in
                            updater.install(path: path)
                        })
                    }
                }
            })
        }
    }
}

extension AppDelegate {
    @objc private func togglePopup(sender: Any) {
        guard let window = self.item.button?.window,
              let view = self.popup.contentView else {
            return
        }
        let buttonOrigin = window.frame.origin
        let buttonCenter = window.frame.width/2
        
        let openedWindows = NSApplication.shared.windows.filter{ $0 is NSPanel }
        openedWindows.forEach{ $0.setIsVisible(false) }
        
        if self.popup.occlusionState.rawValue == 8192 {
            NSApplication.shared.activate(ignoringOtherApps: true)
            
            self.popup.contentView?.invalidateIntrinsicContentSize()
            
            let windowCenter = view.frame.width / 2
            var x = buttonOrigin.x - windowCenter + buttonCenter
            let y = buttonOrigin.y - view.frame.height - 3

            let maxWidth = NSScreen.screens.map{ $0.frame.width }.reduce(0, +)
            if x + view.frame.width > maxWidth {
                x = maxWidth - view.frame.width - 3
            }
            
            self.popup.setFrameOrigin(NSPoint(x: x, y: y))
            self.popup.setIsVisible(true)
        } else {
            self.popup.setIsVisible(false)
        }
    }
    
    @objc private func showNewAlert(_ notification: Notification) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Add a new link"
        
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        
        let inputTextField = TextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        inputTextField.focusRingType = .none
        inputTextField.placeholderString = ("Please enter valid URL")
        alert.accessoryView = inputTextField
        
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            if let url = URL(string: inputTextField.stringValue) {
                var link = Item(url: url)
                link.index = Items.count
                Items.append(link)
            }
        default: break
        }
    }
    
    @objc private func showDeleteAlert(_ notification: Notification) {
        guard let idx = notification.userInfo?["idx"] as? Int else { return }
        
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Are you sure you want delete link?"
        alert.informativeText = Items[idx].url.absoluteString
        
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            Items.remove(at: idx)
        default: break
        }
    }
}
