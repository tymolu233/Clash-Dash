@preconcurrency
import SwiftUI
import WebKit

struct LuCIWebView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: LuCIWebViewModel
    
    init(server: ClashServer) {
        _viewModel = StateObject(wrappedValue: LuCIWebViewModel(server: server))
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("正在加载...")
            } else if let error = viewModel.error {
                VStack {
                    Text("加载失败")
                        .font(.headline)
                        .padding(.bottom, 4)
                    Text(error)
                        .foregroundColor(.secondary)
                }
            } else {
                WebView(url: viewModel.url, token: viewModel.token)
            }
        }
        .navigationTitle("网页访问")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("完成") {
                    dismiss()
                }
            }
        }
        .task {
            await viewModel.loadWebView()
        }
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    let token: String
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "cookieHandler" {
                _ = message.body as? String
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.cookie") { _, _ in }
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            _ = navigationAction.request.allHTTPHeaderFields
            decisionHandler(.allow)
        }
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let controller = WKUserContentController()
        configuration.userContentController = controller
        
        let cookieScript = """
        function setCookie(name, value, path) {
            document.cookie = name + '=' + value + ';path=' + path;
            window.webkit.messageHandlers.cookieHandler.postMessage('设置 Cookie: ' + name + '=' + value);
        }
        
        setCookie('sysauth', '\(token)', '/');
        setCookie('sysauth_http', '\(token)', '/');
        
        window.webkit.messageHandlers.cookieHandler.postMessage('当前所有 Cookie: ' + document.cookie);
        """
        
        let userScript = WKUserScript(
            source: cookieScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        controller.addUserScript(userScript)
        
        controller.add(context.coordinator, name: "cookieHandler")
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        
        let cookieProperties: [HTTPCookiePropertyKey: Any] = [
            .domain: url.host ?? "",
            .path: "/",
            .name: "sysauth",
            .value: token,
            .secure: "TRUE",
            .expires: NSDate(timeIntervalSinceNow: 3600)
        ]
        
        if let cookie = HTTPCookie(properties: cookieProperties) {
            HTTPCookieStorage.shared.setCookie(cookie)
        }
        
        let httpCookieProperties: [HTTPCookiePropertyKey: Any] = [
            .domain: url.host ?? "",
            .path: "/",
            .name: "sysauth_http",
            .value: token,
            .secure: "TRUE",
            .expires: NSDate(timeIntervalSince1970: Date().timeIntervalSince1970 + 3600)
        ]
        
        if let cookie = HTTPCookie(properties: httpCookieProperties) {
            HTTPCookieStorage.shared.setCookie(cookie)
        }
        
        if let storedCookies = HTTPCookieStorage.shared.cookies {
            for _ in storedCookies { }
        }
        
        if let cookies = HTTPCookieStorage.shared.cookies {
            let cookieData = try? NSKeyedArchiver.archivedData(
                withRootObject: cookies,
                requiringSecureCoding: false
            )
            UserDefaults.standard.set(cookieData, forKey: "LuCIWebViewCookies")
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        var request = URLRequest(url: url)
        let cookieHeader = "sysauth=\(token); sysauth_http=\(token)"
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.httpShouldHandleCookies = true
        
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            for _ in cookies { }
        }
        
        webView.load(request)
    }
    
    static func dismantleUIView(_ uiView: WKWebView, coordinator: ()) {
        HTTPCookieStorage.shared.removeCookies(since: Date(timeIntervalSince1970: 0))
        
        WKWebsiteDataStore.default().removeData(
            ofTypes: [WKWebsiteDataTypeCookies],
            modifiedSince: Date(timeIntervalSince1970: 0)
        ) { }
        
        UserDefaults.standard.removeObject(forKey: "LuCIWebViewCookies")
    }
}

class LuCIWebViewModel: ObservableObject {
    @Published var isLoading = true
    @Published var error: String?
    @Published var url: URL!
    @Published var token: String = ""
    
    private let server: ClashServer
    private var serverViewModel: ServerViewModel?
    
    init(server: ClashServer) {
        self.server = server
    }
    
    @MainActor
    func loadWebView() async {
        isLoading = true
        error = nil
        
        do {
            // 在主线程初始化 ServerViewModel
            if serverViewModel == nil {
                serverViewModel = ServerViewModel()
            }
            
            guard let serverViewModel = serverViewModel else {
                throw NetworkError.invalidResponse(message: "无法初始化服务器视图模型")
            }
            
            // 获取认证 token
            guard let username = server.openWRTUsername,
                  let password = server.openWRTPassword else {
                throw NetworkError.unauthorized(message: "未设置 OpenWRT 用户名或密码")
            }
            
            token = try await serverViewModel.getAuthToken(server, username: username, password: password)
            
            // 构建 URL
            let scheme = server.openWRTUseSSL ? "https" : "http"
            guard let openWRTUrl = server.openWRTUrl else {
                throw NetworkError.invalidURL
            }
            let baseURL = "\(scheme)://\(openWRTUrl):\(server.openWRTPort ?? "80")"
            
            let path: String
            if server.luciPackage == .openClash {
                path = "/cgi-bin/luci/admin/services/openclash/client"
            } else {
                // 判断是否使用 nikki
                let isNikki = try await serverViewModel.isUsingNikki(server, token: token)
                path = isNikki ? "/cgi-bin/luci/admin/services/nikki" : "/cgi-bin/luci/admin/services/mihomo"
            }
            
            guard let finalURL = URL(string: baseURL + path) else {
                throw NetworkError.invalidURL
            }
            
            url = finalURL
            isLoading = false
            
        } catch {
            isLoading = false
            if let networkError = error as? NetworkError {
                self.error = networkError.localizedDescription
            } else {
                self.error = error.localizedDescription
            }
        }
    }
} 
