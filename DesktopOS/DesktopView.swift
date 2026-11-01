import SwiftUI
import WebKit

extension View {
    func place(_ r: CGRect) -> some View {
        frame(width: r.width, height: r.height).position(x: r.midX, y: r.midY)
    }
}

/// El escritorio completo. Se dibuja en el monitor externo (y como vista previa en el iPhone).
struct DesktopView: View {
    @ObservedObject var model: DesktopModel

    var body: some View {
        GeometryReader { geo in
            let s = geo.size
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [Color(red: 0.10, green: 0.20, blue: 0.45),
                                        Color(red: 0.45, green: 0.20, blue: 0.55)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)

                ForEach(0..<AppKind.allCases.count, id: \.self) { i in
                    let k = AppKind.allCases[i]
                    IconView(kind: k, selected: model.selectedIcon == k).place(Layout.iconRect(i))
                }

                ForEach(model.windows) { w in
                    WindowView(w: w, focused: model.windows.last?.id == w.id)
                        .place(w.frame)
                        .opacity(w.minimized ? 0 : 1)
                }

                if model.startOpen { StartMenu(size: s) }
                Taskbar(model: model, size: s)

                Image(systemName: "cursorarrow")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 1.5)
                    .position(x: model.cursor.x + 8, y: model.cursor.y + 11)
            }
            .frame(width: s.width, height: s.height)
            .onAppear { model.screenSize = s }
            .onChange(of: s) { _, new in model.screenSize = new }
        }
        .ignoresSafeArea()
        .background(Color.black)
    }
}

struct IconView: View {
    let kind: AppKind
    let selected: Bool
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: kind.icon).font(.system(size: 38)).foregroundColor(kind.color)
            Text(kind.title).font(.system(size: 13)).foregroundColor(.white)
        }
        .frame(width: 92, height: 96)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(selected ? 0.25 : 0)))
    }
}

struct StartMenu: View {
    let size: CGSize
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.12).opacity(0.95)).place(Layout.menuRect(size))
            ForEach(0..<AppKind.allCases.count, id: \.self) { i in
                let k = AppKind.allCases[i]
                HStack(spacing: 12) {
                    Image(systemName: k.icon).foregroundColor(k.color).frame(width: 28)
                    Text(k.title).foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .place(Layout.menuRow(i, size))
            }
        }
    }
}

struct Taskbar: View {
    @ObservedObject var model: DesktopModel
    let size: CGSize
    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Color(white: 0.08).opacity(0.92))
                .place(CGRect(x: 0, y: size.height - Layout.taskH, width: size.width, height: Layout.taskH))

            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 22)).foregroundColor(.white)
                .place(Layout.startButton(size))

            ForEach(Array(model.taskbarWindows.enumerated()), id: \.element.id) { i, w in
                let active = model.windows.last?.id == w.id && !w.minimized
                Image(systemName: w.kind.icon)
                    .font(.system(size: 20)).foregroundColor(w.kind.color)
                    .frame(width: 46, height: 40)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(active ? 0.22 : 0.08)))
                    .place(Layout.taskItem(i, size))
            }

            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                Text(ctx.date, style: .time).foregroundColor(.white).font(.system(size: 15))
            }
            .place(CGRect(x: size.width - 100, y: size.height - Layout.taskH, width: 90, height: Layout.taskH))
        }
    }
}

// MARK: - Ventanas

struct WindowView: View {
    let w: DWindow
    let focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Image(systemName: w.kind.icon).foregroundColor(w.kind.color).padding(.leading, 10)
                Text(w.kind.title).font(.system(size: 14, weight: .medium)).padding(.leading, 6)
                Spacer()
                ctrl("minus")
                ctrl(w.maximized ? "square.on.square" : "square")
                ctrl("xmark")
            }
            .foregroundColor(.white)
            .frame(height: Layout.titleH)
            .background(Color(white: focused ? 0.24 : 0.14))

            content.frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
        }
        .frame(width: w.frame.width, height: w.frame.height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.2), lineWidth: 1))
        .shadow(color: .black.opacity(focused ? 0.5 : 0.25), radius: focused ? 18 : 8)
    }

    private func ctrl(_ name: String) -> some View {
        Image(systemName: name).font(.system(size: 12, weight: .semibold)).frame(width: Layout.btnW, height: Layout.titleH)
    }

    @ViewBuilder private var content: some View {
        switch w.kind {
        case .notes: NotesView(s: w.session as! NotesSession)
        case .calculator: CalcView(s: w.session as! CalcSession)
        case .browser: BrowserView(s: w.session as! BrowserSession)
        case .files: FilesView(s: w.session as! FilesSession)
        }
    }
}

struct NotesView: View {
    @ObservedObject var s: NotesSession
    var body: some View {
        Text(s.text + "▏")
            .font(.system(size: 16, design: .monospaced))
            .foregroundColor(.black)
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(red: 1, green: 0.98, blue: 0.85))
    }
}

struct CalcView: View {
    @ObservedObject var s: CalcSession
    var body: some View {
        VStack(spacing: 0) {
            Text(s.display)
                .font(.system(size: 40, weight: .light)).foregroundColor(.white)
                .lineLimit(1).minimumScaleFactor(0.4)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 16)
                .frame(height: CalcSession.displayH)
            ForEach(0..<5, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { c in
                        let label = CalcSession.rows[r][c]
                        Text(label)
                            .font(.system(size: 22)).foregroundColor(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(c == 3 ? Color.orange : Color(white: 0.28))
                            .overlay(Rectangle().stroke(Color.black.opacity(0.5), lineWidth: 0.5))
                    }
                }
            }
        }
        .background(Color(white: 0.1))
    }
}

struct WebHost: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct BrowserView: View {
    @ObservedObject var s: BrowserSession
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(["chevron.left", "chevron.right", "arrow.clockwise"], id: \.self) { n in
                    Image(systemName: n).frame(width: 40, height: BrowserSession.toolbarH)
                }
                Text(s.urlText + (s.editingURL ? "▏" : ""))
                    .font(.system(size: 14)).lineLimit(1)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 30)
                    .background(RoundedRectangle(cornerRadius: 15).fill(Color.white.opacity(s.editingURL ? 0.3 : 0.15)))
                    .padding(.trailing, 8)
            }
            .foregroundColor(.white)
            .frame(height: BrowserSession.toolbarH)
            .background(Color(white: 0.2))

            WebHost(webView: s.webView)
        }
    }
}

struct FilesView: View {
    @ObservedObject var s: FilesSession
    var body: some View {
        VStack(spacing: 0) {
            Text(s.path == s.root ? "Documentos" : "Documentos/" + s.path.lastPathComponent)
                .font(.system(size: 14, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .frame(height: FilesSession.headerH)
                .background(Color(white: 0.92))

            VStack(spacing: 0) {
                ForEach(Array(s.rows.enumerated()), id: \.offset) { _, url in
                    let name = url?.lastPathComponent ?? ".."
                    let dir = url == nil || s.isDir(url!)
                    HStack(spacing: 8) {
                        Image(systemName: dir ? "folder.fill" : "doc.text").foregroundColor(dir ? .orange : .gray)
                        Text(name).foregroundColor(.black)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .frame(height: FilesSession.rowH)
                    .background(isSelected(url) ? Color.blue.opacity(0.25) : Color.clear)
                }
                Spacer(minLength: 0)
            }
        }
        .background(Color.white)
    }

    private func isSelected(_ url: URL?) -> Bool {
        guard let sel = s.selected else { return false }
        return url == nil ? sel.lastPathComponent == ".." : sel == url
    }
}
