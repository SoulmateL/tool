import UIKit
import WebKit

/**
 Markdown View for iOS.
 
 - Note: [How to get height of entire document with javascript](https://stackoverflow.com/questions/1145850/how-to-get-height-of-entire-document-with-javascript)
 */
@objcMembers
open class MarkdownView: UIView {
    
    private var webView: MarkdownWebView?
    
    private var intrinsicContentHeight: CGFloat? {
        didSet {
            self.invalidateIntrinsicContentSize()
        }
    }
    
    @objc public var isScrollEnabled: Bool = true {
        didSet {
            webView?.scrollView.isScrollEnabled = isScrollEnabled
        }
    }
    
    @objc public var onTouchLink: ((URLRequest) -> Bool)?
    
    @objc public var onRendered: ((CGFloat) -> Void)?
    
    public convenience init() {
        self.init(frame: .zero)
    }
    
    /// Reserve a web view before displaying markdown.
    /// You can use this for performance optimization.
    ///
    /// - Note: `webView` needs complete loading before invoking `show` method.
    @objc public convenience init(css: String?, plugins: [String]?, stylesheets: [URL]? = nil, styled: Bool = true) {
        self.init(frame: .zero)
        
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = makeContentController(css: css, plugins: plugins, stylesheets: stylesheets, markdown: nil, enableImage: nil)
        self.webView = makeWebView(with: configuration)
        self.webView?.load(URLRequest(url: styled ? Self.styledHtmlUrl : Self.nonStyledHtmlUrl))
    }
    
    @objc public convenience init (markdownStyle:Bool) {
        var plugins:[String] {
            var array:[String] = []
            for name in ["katexv2","sub","sup","markdown-it-footnote"] {
                if let url = Bundle.main.url(forResource: name, withExtension: "js") {
                    array.append(try! String(contentsOf: url, encoding: .utf8))
                }
            }
            return array
        }
        
        var stylesheet:[URL] {
            var array:[URL] = []
            for name in ["katexv2.min"] {
                if let url = Bundle.main.url(forResource: name, withExtension: "css") {
                    array.append(url)
                }
            }
            return array
        }
        
        self.init(css: nil, plugins: plugins, stylesheets: stylesheet, styled: true)
    }
    
    override init (frame: CGRect) {
        super.init(frame: frame)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func showCustomMenu(text: String, at point: CGPoint) {
        print("选中文本：\(text)")
    }
}

extension MarkdownView {
    open override var intrinsicContentSize: CGSize {
        if let height = self.intrinsicContentHeight {
            return CGSize(width: UIView.noIntrinsicMetric, height: height)
        } else {
            return CGSize.zero
        }
    }
    
    /// Load markdown with a newly configured webView.
    ///
    /// If you want to preserve already applied css or plugins, use `show` instead.
    @objc public func load(markdown: String?, enableImage: Bool = true, css: String? = nil, plugins: [String]? = nil, stylesheets: [URL]? = nil, styled: Bool = true) {
        guard let markdown = markdown else { return }
        
        self.webView?.removeFromSuperview()
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = makeContentController(css: css, plugins: plugins, stylesheets: stylesheets, markdown: markdown, enableImage: enableImage)
        self.webView = makeWebView(with: configuration)
        self.webView?.load(URLRequest(url: styled ? Self.styledHtmlUrl : Self.nonStyledHtmlUrl))
    }
    
    public func show(markdown: String,divId:String = "contents") {
        guard let webView = webView else { return }
        let escapedMarkdown = self.escape(markdown: markdown) ?? ""
        let script = "window.showMarkdown('\(divId)','\(escapedMarkdown)', true);"
        webView.evaluateJavaScript(script) { _, error in
            guard let error = error else { return }
            print("[MarkdownView][Error] \(error)")
        }
    }
}

// MARK: - WKNavigationDelegate

extension MarkdownView: WKNavigationDelegate {
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        switch navigationAction.navigationType {
        case .linkActivated:
            if let onTouchLink = onTouchLink, onTouchLink(navigationAction.request) {
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)
            }
        default:
            decisionHandler(.allow)
        }
        
    }
}

// MARK: - Scripts

private extension MarkdownView {
    
    func styleScript(_ css: String) -> String {
        [
            "var s = document.createElement('style');",
            "s.innerHTML = `\(css)`;",
            "document.head.appendChild(s);"
        ].joined()
    }
    
    func linkScript(_ url: URL) -> String {
        [
            "var link = document.createElement('link');",
            "link.href = '\(url.absoluteURL)';",
            "link.rel = 'stylesheet';",
            "document.head.appendChild(link);"
        ].joined()
    }
    
    func usePluginScript(_ pluginBody: String) -> String {
    """
      var _module = {};
      var _exports = {};
      (function(module, exports) {
        \(pluginBody)
      })(_module, _exports);
      window.usePlugin(_module.exports || _exports);
    """
    }
}

// MARK: - Misc

private extension MarkdownView {
    static var styledHtmlUrl: URL = {
#if SWIFT_PACKAGE
        let bundle = Bundle.module
#else
        let bundle = Bundle(for: MarkdownView.self)
#endif
        return bundle.url(forResource: "styled",
                          withExtension: "html") ??
        bundle.url(forResource: "styled",
                   withExtension: "html",
                   subdirectory: "MarkdownView.bundle")!
    }()
    
    static var nonStyledHtmlUrl: URL = {
#if SWIFT_PACKAGE
        let bundle = Bundle.module
#else
        let bundle = Bundle(for: MarkdownView.self)
#endif
        return bundle.url(forResource: "non_styled",
                          withExtension: "html") ??
        bundle.url(forResource: "non_styled",
                   withExtension: "html",
                   subdirectory: "MarkdownView.bundle")!
    }()
    
    func escape(markdown: String) -> String? {
        return markdown.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics)
    }
    
    func makeWebView(with configuration: WKWebViewConfiguration) -> MarkdownWebView {
        let wv = MarkdownWebView(frame: self.bounds, configuration: configuration)
        wv.scrollView.isScrollEnabled = self.isScrollEnabled
        wv.translatesAutoresizingMaskIntoConstraints = false
        wv.navigationDelegate = self
        addSubview(wv)
        wv.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        wv.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        wv.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
        wv.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.backgroundColor = .clear
        
        wv.updateHeightHandler = { [weak self] height in
            guard height != self?.intrinsicContentHeight ?? 0 else { return }
            self?.onRendered?(height)
            self?.intrinsicContentHeight = height
        }
        
        wv.selectionHandler = { [weak self] data in
            if let text = data["text"] as? String,
               let x = data["x"] as? Double,
               let y = data["y"] as? Double {
                self?.showCustomMenu(text: text, at: CGPoint(x: x, y: y))
            }
        }
        
        return wv
    }
    
    func makeContentController(css: String?,
                               plugins: [String]?,
                               stylesheets: [URL]?,
                               markdown: String?,
                               enableImage: Bool?) -> WKUserContentController {
        let controller = WKUserContentController()
        
        if let css = css {
            let styleInjection = WKUserScript(source: styleScript(css), injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            controller.addUserScript(styleInjection)
        }
        
        plugins?.forEach({ plugin in
            let scriptInjection = WKUserScript(source: usePluginScript(plugin), injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            controller.addUserScript(scriptInjection)
        })
        
        stylesheets?.forEach({ url in
            let linkInjection = WKUserScript(source: linkScript(url), injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            controller.addUserScript(linkInjection)
        })
        
        if let markdown = markdown {
            let escapedMarkdown = self.escape(markdown: markdown) ?? ""
            let divId = "contents"
            let imageOption = (enableImage ?? true) ? "true" : "false"
            let script = "window.showMarkdown('\(divId)','\(escapedMarkdown)', \(imageOption));"
            let userScript = WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            controller.addUserScript(userScript)
        }
        
        return controller
    }
}
