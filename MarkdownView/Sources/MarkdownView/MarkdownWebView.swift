//
//  MarkdownWebView.swift
//  SKB
//
//  Created by Apple on 2025/10/10.
//  Copyright © 2025 junjie. All rights reserved.
//

import UIKit

class MarkdownWebView : WKWebView {
    
    var updateHeightHandler: ((CGFloat) -> Void)?
    var selectionHandler: (([String:Any]) -> Void)?
    var noteHandler: ((String) -> Void)?
    var messageHandler:((WKScriptMessage) -> Void)?
    
    
    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
#if DEBUG
        if #available(iOS 16.4, *) {
            self.isInspectable = true
        }
#endif
        
        let scriptMessageHandler = ScriptMessageHandler(scriptDelegate: self)
        let handlerNames = ["updateHeight","selectionHandler"]
        handlerNames.forEach { handlerName in
            configuration.userContentController.add(scriptMessageHandler, name: handlerName)
        }
        
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

extension MarkdownWebView : WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "updateHeight" :
            guard let updateHeightHandler = self.updateHeightHandler else { return }
            if let height = message.body as? CGFloat {
                updateHeightHandler(height)
            }
        case "selectionHandler":
            guard let selectionHandler = self.selectionHandler else { return }
            if let data = message.body as? [String:Any] {
                selectionHandler(data)
            }
        default:
            guard let messageHandler = self.messageHandler else { return }
            messageHandler(message)
            debugPrint("未处理的消息：\(message.name)")
        }
    }
}

extension MarkdownWebView {
    // 让 WebView 可以响应菜单事件
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    // 返回支持的菜单操作
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(noteAction(_:)) {
            return true
        }
        // 保留系统菜单选项（如复制、选中、查询）
        return super.canPerformAction(action, withSender: sender)
    }
    
    // 注入自定义菜单
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        addCustomMenuItem()
        return result
    }
    
    private func addCustomMenuItem() {
        let menu = UIMenuController.shared
        var items = menu.menuItems ?? []
        // 检查是否已添加，避免重复
        if !items.contains(where: { $0.action == #selector(noteAction(_:)) }) {
            let noteItem = UIMenuItem(title: "记笔记", action: #selector(noteAction(_:)))
            items.insert(noteItem, at: 0)
            menu.menuItems = items
        }
    }
    
    // 处理自定义菜单点击事件
    @objc func noteAction(_ sender: Any?) {
        evaluateJavaScript("window.getSelection().toString()") { result, _ in
            if let text = result as? String {
                if let noteHandler = self.noteHandler {
                    noteHandler(text)
                }
                print("✏️ 选中的文字: \(text)")
                // 👉 这里可以弹出笔记输入框、保存到数据库等操作
            }
        }
    }
}

private class ScriptMessageHandler:NSObject, WKScriptMessageHandler {
    
    var scriptDelegate:WKScriptMessageHandler
    
    init(scriptDelegate: WKScriptMessageHandler) {
        self.scriptDelegate = scriptDelegate
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        self.scriptDelegate.userContentController(userContentController, didReceive: message)
    }
}
