//
//  item.swift
//  Links
//
//  Created by Serhiy Mytrovtsiy on 20/08/2022.
//  Using Swift 5.0.
//  Running on macOS 12.5.
//
//  Copyright © 2022 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public struct Item: Codable {
    let id: UUID
    
    var name: String?
    var url: URL
    var index: Int = -1
    
    public init(url: URL) {
        self.id = UUID.init()
        self.url = url
    }
    
    func setIcon(_ view: NSImageView) {
        let url = URL(string: "https://www.google.com/s2/favicons?sz=64&domain=\(url.absoluteString)")!
        DispatchQueue.global().async {
            let data = try? Data(contentsOf: url)
            DispatchQueue.main.async {
                if let data = data {
                    view.image = NSImage(data: data)
                    return
                }
                view.image = self.defaultIcon()
            }
        }
    }
    
    private func defaultIcon() -> NSImage? {
        return NSImage(systemSymbolName: "link.circle.fill", accessibilityDescription: nil)?.withSymbolConfiguration(NSImage.SymbolConfiguration(scale: .large))
    }
    
    func handler() {
        NSWorkspace.shared.open(self.url)
    }
}

public var Items: [Item] {
    get {
        var arr: [Item] = []
        
        if let decodedData = UserDefaults.standard.data(forKey: "items") {
            do {
                arr = try JSONDecoder().decode([Item].self, from: decodedData)
            } catch {
                print(error)
            }
        }
        
        return arr.sorted(by: { $0.index < $1.index })
    }
    set {
        do {
            let encodedData = try JSONEncoder().encode(newValue)
            UserDefaults.standard.set(encodedData, forKey: "items")
        } catch {
            print(error)
        }
        NotificationCenter.default.post(name: .reloadList, object: nil, userInfo: nil)
    }
}
