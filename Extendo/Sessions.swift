import SwiftUI
import WebKit

// MARK: - Notas

final class NotesSession: Session {
    @Published var text: String

    init(text: String = "") {
        self.text = text
        super.init()
    }

    override func key(_ k: KeyInput) {
        switch k {
        case .text(let s): text += s
        case .enter: text += "\n"
        case .tab: text += "    "
        case .backspace: if !text.isEmpty { text.removeLast() }
        default: break
        }
    }
}

// MARK: - Calculadora

final class CalcSession: Session {
    static let rows = [["C", "±", "%", "÷"],
                       ["7", "8", "9", "×"],
                       ["4", "5", "6", "−"],
                       ["1", "2", "3", "+"],
                       ["0", ".", "⌫", "="]]
    static let displayH: CGFloat = 90

    @Published var display = "0"
    private var acc: Double?
    private var op: String?
    private var fresh = true

    override func click(at p: CGPoint, size: CGSize, double: Bool) {
        guard p.y >= Self.displayH else { return }
        let cellH = (size.height - Self.displayH) / 5
        let cellW = size.width / 4
        let r = Int((p.y - Self.displayH) / cellH), c = Int(p.x / cellW)
        guard (0..<5).contains(r), (0..<4).contains(c) else { return }
        press(Self.rows[r][c])
    }

    override func key(_ k: KeyInput) {
        switch k {
        case .text(let s):
            let map = ["*": "×", "/": "÷", "-": "−", "+": "+", "=": "=", ".": "."]
            if let t = map[s] { press(t) }
            else if s.count == 1, s.first!.isNumber { press(s) }
        case .enter: press("=")
        case .backspace: press("⌫")
        default: break
        }
    }

    private func press(_ b: String) {
        switch b {
        case "C":
            display = "0"; acc = nil; op = nil; fresh = true
        case "±":
            if let v = Double(display) { display = fmt(-v) }
        case "%":
            if let v = Double(display) { display = fmt(v / 100); fresh = true }
        case "⌫":
            if fresh { return }
            display.removeLast()
            if display.isEmpty || display == "-" { display = "0"; fresh = true }
        case "÷", "×", "−", "+", "=":
            let v = Double(display) ?? 0
            if let a = acc, let o = op, !fresh {
                let r = apply(a, o, v)
                display = fmt(r)
                acc = r
            } else {
                acc = v
            }
            op = (b == "=") ? nil : b
            fresh = true
        default:
            if fresh {
                display = (b == ".") ? "0." : b
                fresh = false
            } else if b == "." {
                if !display.contains(".") { display += "." }
            } else {
                display = (display == "0") ? b : display + b
            }
        }
    }

    private func apply(_ a: Double, _ o: String, _ b: Double) -> Double {
        switch o {
        case "+": return a + b
        case "−": return a - b
        case "×": return a * b
        case "÷": return b == 0 ? .nan : a / b
        default: return b
        }
    }

    private func fmt(_ v: Double) -> String {
        if v.isNaN || v.isInfinite { return "Error" }
        if v == v.rounded() && abs(v) < 1e15 { return String(Int(v)) }
        return String(format: "%.10g", v)
    }
}

// MARK: - Navegador

final class BrowserSession: Session, WKNavigationDelegate {
    static let toolbarH: CGFloat = 44

    let webView: WKWebView
    @Published var urlText = ""
    @Published var editingURL = false

    override init() {
        webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        super.init()
        webView.navigationDelegate = self
        load("https://duckduckgo.com")
    }

    func load(_ input: String) {
        let s = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return }
        let str: String
        if s.contains("://") { str = s }
        else if s.contains(".") && !s.contains(" ") { str = "https://" + s }
        else { str = "https://duckduckgo.com/?q=" + (s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s) }
        if let url = URL(string: str) { webView.load(URLRequest(url: url)) }
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) { syncURL() }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { syncURL() }
    private func syncURL() {
        if !editingURL { urlText = webView.url?.absoluteString ?? "" }
    }

    override func click(at p: CGPoint, size: CGSize, double: Bool) {
        if p.y < Self.toolbarH {
            switch p.x {
            case ..<40: webView.goBack()
            case ..<80: webView.goForward()
            case ..<120: webView.reload()
            default: editingURL = true
            }
        } else {
            editingURL = false
            syncURL()
            let js = "(function(){var e=document.elementFromPoint(\(Int(p.x)),\(Int(p.y - Self.toolbarH)));if(e){if(e.focus)e.focus();e.click();}})()"
            webView.evaluateJavaScript(js)
        }
    }

    override func scroll(dx: CGFloat, dy: CGFloat, at p: CGPoint) {
        webView.evaluateJavaScript("window.scrollBy(\(Int(dx)),\(Int(dy)))")
    }

    override func key(_ k: KeyInput) {
        if editingURL {
            switch k {
            case .text(let s): urlText += s
            case .backspace: if !urlText.isEmpty { urlText.removeLast() }
            case .enter: editingURL = false; load(urlText)
            default: break
            }
            return
        }
        switch k {
        case .text(let s): webView.evaluateJavaScript("document.execCommand('insertText',false,\(lit(s)))")
        case .backspace: webView.evaluateJavaScript("document.execCommand('delete')")
        case .enter:
            webView.evaluateJavaScript(#"""
            (function(){var e=document.activeElement;
            if(e&&e.form){e.form.requestSubmit?e.form.requestSubmit():e.form.submit();}
            else if(e&&e.tagName==='TEXTAREA'){document.execCommand('insertText',false,'\n');}})()
            """#)
        case .up: webView.evaluateJavaScript("window.scrollBy(0,-80)")
        case .down: webView.evaluateJavaScript("window.scrollBy(0,80)")
        default: break
        }
    }

    private func lit(_ s: String) -> String {
        (try? JSONEncoder().encode(s)).flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
    }
}

// MARK: - Archivos (carpeta Documentos de la app; visible desde la app Archivos de iOS)

final class FilesSession: Session {
    static let headerH: CGFloat = 40
    static let rowH: CGFloat = 30

    let root: URL
    @Published var path: URL
    @Published var entries: [URL] = []
    @Published var selected: URL?

    override init() {
        root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        path = root
        super.init()
        seed()
        reload()
    }

    /// nil = fila ".." (subir un nivel)
    var rows: [URL?] {
        var r: [URL?] = path == root ? [] : [nil]
        r.append(contentsOf: entries.map { Optional($0) })
        return r
    }

    func isDir(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }

    private func seed() {
        let fm = FileManager.default
        let items = (try? fm.contentsOfDirectory(atPath: root.path)) ?? []
        guard items.isEmpty else { return }
        try? "¡Bienvenido a Extendo!\n\nHaz doble clic en este archivo para abrirlo en Notas."
            .write(to: root.appendingPathComponent("Bienvenido.txt"), atomically: true, encoding: .utf8)
        try? fm.createDirectory(at: root.appendingPathComponent("Documentos"), withIntermediateDirectories: true)
    }

    func reload() {
        let list = (try? FileManager.default.contentsOfDirectory(
            at: path, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
        entries = list.sorted {
            let a = isDir($0), b = isDir($1)
            if a != b { return a }
            return $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending
        }
    }

    override func click(at p: CGPoint, size: CGSize, double: Bool) {
        guard p.y >= Self.headerH else { return }
        let idx = Int((p.y - Self.headerH) / Self.rowH)
        let r = rows
        guard idx >= 0, idx < r.count else { selected = nil; return }
        if double { activate(r[idx]) } else { selected = r[idx] ?? URL(fileURLWithPath: "..") }
    }

    private func activate(_ url: URL?) {
        selected = nil
        guard let url = url else {
            path = path.deletingLastPathComponent()
            reload()
            return
        }
        if isDir(url) {
            path = url
            reload()
        } else if let text = try? String(contentsOf: url, encoding: .utf8) {
            DesktopModel.shared.open(.notes, session: NotesSession(text: text))
        }
    }
}
