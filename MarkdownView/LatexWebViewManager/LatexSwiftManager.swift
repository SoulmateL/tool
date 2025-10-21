//
//  LatexSwiftManager.swift
//  SKB
//
//  Created by Apple on 2025/10/14.
//  Copyright © 2025 junjie. All rights reserved.
//

import Foundation
import WebKit
import UIKit
import SDWebImage

typealias LatexCompletion = ([UIImage]) -> Void

@objcMembers
class LatexSwiftManager: NSObject {

    static let shared = LatexSwiftManager()

    // MARK: - Core Properties
    private var webView: WKWebView?
    private var isKatexReady: Bool = false

    // 并发队列 + barrier 用于线程安全
    private let asyncQueue = DispatchQueue(label: "com.skb.latex.manager", attributes: .concurrent)
    private var completionMap: [String: LatexCompletion] = [:]
    private var pendingLatex: [String: [String]] = [:]
    private var timeoutMap: [String: DispatchSourceTimer] = [:]
    private var taskQueue: [String] = []
    private var waitingQueue: [(latexArray: [String], completion: LatexCompletion)] = []
    private var runningBatches: Int = 0
    private let maxConcurrentBatches = 2

    private override init() {
        super.init()
        setupRender()
        addMemoryWarningObserver()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup WebView
    @objc func setupRender() {
        guard webView == nil else { return }

        let config = WKWebViewConfiguration()
        let userController = WKUserContentController()
        userController.add(self, name: "katexHandler")
        userController.add(self, name: "katexReadyHandler")
        config.userContentController = userController

        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = self
        self.webView = webView

        if let htmlURL = Bundle.main.url(forResource: "LaTex2Img", withExtension: "html") {
            let baseURL = htmlURL.deletingLastPathComponent()
            webView.loadFileURL(htmlURL, allowingReadAccessTo: baseURL)
        }
    }

    // MARK: - Public Render
    @objc func renderFormulas(_ latexArray: [String], completion: @escaping LatexCompletion) {
        guard !latexArray.isEmpty else { return }

        asyncQueue.async(flags: .barrier) {
            guard self.isKatexReady else {
                debugPrint("⏳ KaTeX 环境未就绪，任务暂存等待")
                self.waitingQueue.append((latexArray, completion))
                return
            }

            let batchId = "batch_\(UUID().uuidString)"
            self.completionMap[batchId] = completion

            var cachedImages: [UIImage] = []
            var pending: [String] = []

            for latex in latexArray {
                let cacheKey = self.cacheKey(for: latex, scale: 2)
                if let img = SDImageCache.shared.imageFromCache(forKey: cacheKey) {
                    cachedImages.append(img)
                } else {
                    cachedImages.append(UIImage())
                    pending.append(latex)
                }
            }

            if pending.isEmpty {
                DispatchQueue.main.async {
                    completion(cachedImages)
                }
                self.completionMap.removeValue(forKey: batchId)
                return
            }

            self.pendingLatex[batchId] = pending
            self.taskQueue.append(batchId)
            self.tryExecuteNextBatch()
        }
    }

    @objc func cancelBatch(_ batchId: String) {
        asyncQueue.async(flags: .barrier) {
            self.cleanupBatch(batchId)
        }
    }

    // MARK: - Batch Execution
    private func tryExecuteNextBatch() {
        asyncQueue.async(flags: .barrier) {
            guard self.runningBatches < self.maxConcurrentBatches else { return }
            guard !self.taskQueue.isEmpty else { return }

            let batchId = self.taskQueue.removeFirst()
            self.runningBatches += 1

            guard let pending = self.pendingLatex[batchId] else {
                self.batchFinished(batchId: batchId, images: [])
                return
            }

            var jsonData: Data
            do {
                jsonData = try JSONSerialization.data(withJSONObject: pending, options: [])
            } catch {
                debugPrint("❌ JSON 序列化失败: \(error)")
                self.batchFinished(batchId: batchId, images: [])
                return
            }

            var jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
            jsonString = jsonString.replacingOccurrences(of: "\\", with: "\\\\")
            jsonString = jsonString.replacingOccurrences(of: "'", with: "\\'")

            let js = "renderFormulasBatch('\(batchId)', '\(jsonString)', 2)"

            // 超时保护
            let timer = DispatchSource.makeTimerSource(queue: self.asyncQueue)
            timer.schedule(deadline: .now() + 15)
            timer.setEventHandler { [weak self] in
                guard let self else { return }
                debugPrint("⚠️ Batch \(batchId) 超时")
                self.batchFinished(batchId: batchId, images: [])
            }
            timer.resume()
            self.timeoutMap[batchId] = timer

            DispatchQueue.main.async {
                self.webView?.evaluateJavaScript(js) { _, error in
                    if let error = error {
                        print("❌ JS 调用失败: \(error)")
                        self.asyncQueue.async(flags: .barrier) {
                            self.batchFinished(batchId: batchId, images: [])
                        }
                    }
                }
            }
        }
    }

    private func batchFinished(batchId: String, images: [UIImage]) {
        asyncQueue.async(flags: .barrier) {
            if let completion = self.completionMap[batchId] {
                DispatchQueue.main.async {
                    completion(images)
                }
            }
            self.cleanupBatch(batchId)
            self.runningBatches = max(0, self.runningBatches - 1)
            self.tryExecuteNextBatch()
        }
    }

    private func cleanupBatch(_ batchId: String) {
        self.completionMap.removeValue(forKey: batchId)
        self.pendingLatex.removeValue(forKey: batchId)
        if let timer = self.timeoutMap[batchId] {
            timer.cancel()
            self.timeoutMap.removeValue(forKey: batchId)
        }
    }

    private func cacheKey(for latex: String, scale: Int) -> String {
        return "\(latex)_scale\(scale)"
    }

    // MARK: - KaTeX Ready
    private func handleKatexReady() {
        asyncQueue.async(flags: .barrier) {
            self.isKatexReady = true
            debugPrint("✅ KaTeX 环境已就绪，共有 \(self.waitingQueue.count) 个等待任务")

            // 执行所有等待中的任务
            let waiting = self.waitingQueue
            self.waitingQueue.removeAll()

            for item in waiting {
                self.renderFormulas(item.latexArray, completion: item.completion)
            }
        }
    }

    // MARK: - WebView 崩溃恢复
    private func handleWebViewCrashed() {
        asyncQueue.async(flags: .barrier) {
            self.isKatexReady = false

            var allTasks: [(latexArray: [String], completion: LatexCompletion)] = []
            for (batchId, latexArray) in self.pendingLatex {
                if let completion = self.completionMap[batchId] {
                    allTasks.append((latexArray, completion))
                }
            }
            allTasks.append(contentsOf: self.waitingQueue)

            self.taskQueue.removeAll()
            self.pendingLatex.removeAll()
            self.completionMap.removeAll()
            self.timeoutMap.values.forEach { $0.cancel() }
            self.timeoutMap.removeAll()
            self.runningBatches = 0
            self.waitingQueue.removeAll()

            print("♻️ WKWebView 崩溃，准备重建，恢复任务数: \(allTasks.count)")

            DispatchQueue.main.async {
                self.webView?.navigationDelegate = nil
                self.webView?.configuration.userContentController.removeAllUserScripts()
                self.webView?.removeFromSuperview()
                self.webView = nil

                self.setupRender()
                self.waitingQueue.append(contentsOf: allTasks)
            }
        }
    }

    // MARK: - 内存警告
    private func addMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    @objc private func handleMemoryWarning() {
        debugPrint("⚠️ 收到系统内存警告，清理内存缓存")
        SDImageCache.shared.clearMemory()

        asyncQueue.async(flags: .barrier) {
            guard self.runningBatches == 0 else { return }
            if let webView = self.webView {
                debugPrint("💤 释放 WKWebView 节省内存")
                DispatchQueue.main.async {
                    webView.removeFromSuperview()
                    self.webView = nil
                }
                self.isKatexReady = false
            }
        }
    }
}

// MARK: - WKScriptMessageHandler
extension LatexSwiftManager: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "katexReadyHandler" {
            handleKatexReady()
            return
        }

        if message.name == "katexHandler",
           let payload = message.body as? [String: Any],
           let batchId = payload["batchId"] as? String,
           let results = payload["results"] as? [[String: Any]],
           let pending = self.pendingLatex[batchId] {

            var generated: [UIImage] = []
            for item in results {
                guard let latex = item["latex"] as? String,
                      let base64 = item["base64"] as? String,
                      let cleanBase64 = base64.components(separatedBy: ",").last,
                      let data = Data(base64Encoded: cleanBase64),
                      let img = UIImage(data: data) else { continue }

                let cacheKey = self.cacheKey(for: latex, scale: 2)
                SDImageCache.shared.store(img, forKey: cacheKey, completion: nil)
                generated.append(img)
            }

            var finalImages: [UIImage] = []
            for latex in pending {
                let cacheKey = self.cacheKey(for: latex, scale: 2)
                let img = SDImageCache.shared.imageFromCache(forKey: cacheKey) ?? UIImage()
                finalImages.append(img)
            }

            self.batchFinished(batchId: batchId, images: finalImages)
        }
    }
}

// MARK: - WKNavigationDelegate
extension LatexSwiftManager: WKNavigationDelegate {
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        print("⚠️ WKWebView 内容进程终止，将尝试恢复环境")
        handleWebViewCrashed()
    }
}
