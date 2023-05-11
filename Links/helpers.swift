//
//  helpers.swift
//  Links
//
//  Created by Serhiy Mytrovtsiy on 22/08/2022.
//  Using Swift 5.0.
//  Running on macOS 12.5.
//
//  Copyright © 2022 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import ServiceManagement

public extension Notification.Name {
    static let openSettings = Notification.Name("open_settings")
    static let showNewLink = Notification.Name("new_link")
    static let showDeleteLink = Notification.Name("delete_link")
    static let reloadList = Notification.Name("reload_list")
}

public class Store {
    public static let shared = Store()
    private let defaults = UserDefaults.standard
    
    public init() {}
    
    public func exist(key: String) -> Bool {
        return self.defaults.object(forKey: key) == nil ? false : true
    }
    
    public func remove(_ key: String) {
        self.defaults.removeObject(forKey: key)
    }
    
    public func bool(key: String, defaultValue value: Bool) -> Bool {
        return !self.exist(key: key) ? value : defaults.bool(forKey: key)
    }
    
    public func string(key: String, defaultValue value: String) -> String {
        return (!self.exist(key: key) ? value : defaults.string(forKey: key))!
    }
    
    public func int(key: String, defaultValue value: Int) -> Int {
        return (!self.exist(key: key) ? value : defaults.integer(forKey: key))
    }
    
    public func set(key: String, value: Bool) {
        self.defaults.set(value, forKey: key)
    }
    
    public func set(key: String, value: String) {
        self.defaults.set(value, forKey: key)
    }
    
    public func set(key: String, value: Int) {
        self.defaults.set(value, forKey: key)
    }
    
    public func reset() {
        self.defaults.dictionaryRepresentation().keys.forEach { key in
            self.defaults.removeObject(forKey: key)
        }
    }
}

public struct LaunchAtLogin {
    public static var isEnabled: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    if SMAppService.mainApp.status == .enabled {
                        try? SMAppService.mainApp.unregister()
                    }
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("failed to \(newValue ? "enable" : "disable") launch at login: \(error.localizedDescription)")
            }
        }
    }
}

private protocol DeprecationWarningWorkaround {
    static var jobsDict: [[String: AnyObject]]? { get }
}

extension LaunchAtLogin: DeprecationWarningWorkaround {
    @available(*, deprecated)
    static var jobsDict: [[String: AnyObject]]? {
        SMCopyAllJobDictionaries(kSMDomainUserLaunchd)?.takeRetainedValue() as? [[String: AnyObject]]
    }
}

internal class TableViewWithActiveRow: NSTableView {
    public var activeRow: Int = -1
    
    override func menu(for event: NSEvent) -> NSMenu? {
        self.activeRow = self.row(at: self.convert(event.locationInWindow, from: nil))
        return super.menu(for: event)
    }
}

internal class TextField: NSTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let commandKey = NSEvent.ModifierFlags.command.rawValue
        let commandShiftKey = NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue
        
        if event.type == NSEvent.EventType.keyDown {
            if (event.modifierFlags.rawValue & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue) == commandKey {
                switch event.charactersIgnoringModifiers! {
                case "x":
                    if NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self) { return true }
                case "c":
                    if NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self) { return true }
                case "v":
                    if NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self) { return true }
                case "z":
                    if NSApp.sendAction(Selector(("undo:")), to: nil, from: self) { return true }
                case "a":
                    if NSApp.sendAction(#selector(NSResponder.selectAll(_:)), to: nil, from: self) { return true }
                default:
                    break
                }
            } else if (event.modifierFlags.rawValue & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue) == commandShiftKey {
                if event.charactersIgnoringModifiers == "Z" {
                    if NSApp.sendAction(Selector(("redo:")), to: nil, from: self) { return true }
                }
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

internal class EmptyView: NSStackView {
    public init(_ title: String, isHidden: Bool, height: CGFloat = 13) {
        super.init(frame: NSRect.zero)
        
        self.translatesAutoresizingMaskIntoConstraints = false
        self.spacing = 0
        self.orientation = .vertical
        self.distribution = .equalCentering
        self.isHidden = isHidden
        
        let textView: NSTextView = NSTextView()
        textView.heightAnchor.constraint(equalToConstant: height).isActive = true
        textView.alignment = .center
        textView.isEditable = false
        textView.isSelectable = false
        textView.drawsBackground = false
        textView.string = title
        
        self.addArrangedSubview(NSView())
        self.addArrangedSubview(textView)
        self.addArrangedSubview(NSView())
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

internal class Icon: NSView {
    public static let size: CGSize = CGSize(width: 12, height: 16)
    
    init() {
        super.init(frame: NSRect(x: 0, y: 3, width: Icon.size.width, height: Icon.size.height))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        NSColor.textColor.set()
        NSBezierPath(roundedRect: NSRect(
            x: 0,
            y: 0,
            width: Icon.size.width,
            height: Icon.size.height
        ), xRadius: 2, yRadius: 2).fill()
        
        ctx.saveGState()
        ctx.setBlendMode(.destinationOut)
        
        let points: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: Icon.size.width/2, y: 7),
            CGPoint(x: Icon.size.width, y: 0),
            CGPoint(x: 0, y: 0)
        ]
        
        let linePath = NSBezierPath()
        linePath.move(to: CGPoint(x: points[0].x, y: points[0].y))
        for i in 1..<points.count {
            linePath.line(to: CGPoint(x: points[i].x, y: points[i].y))
        }
        linePath.line(to: CGPoint(x: points[0].x, y: points[0].y))
        
        NSColor.textColor.set()
        linePath.fill()
        
        ctx.restoreGState()
    }
}
