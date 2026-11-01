import SwiftUI

// MARK: - Apps

enum AppKind: String, CaseIterable, Identifiable {
    case notes, browser, files, calculator

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notes: return "Notas"
        case .browser: return "Navegador"
        case .files: return "Archivos"
        case .calculator: return "Calculadora"
        }
    }

    var icon: String {
        switch self {
        case .notes: return "note.text"
        case .browser: return "globe"
        case .files: return "folder.fill"
        case .calculator: return "plusminus.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .notes: return .yellow
        case .browser: return .blue
        case .files: return .orange
        case .calculator: return .green
        }
    }

    var defaultSize: CGSize {
        switch self {
        case .notes: return CGSize(width: 560, height: 400)
        case .browser: return CGSize(width: 900, height: 600)
        case .files: return CGSize(width: 520, height: 400)
        case .calculator: return CGSize(width: 320, height: 460)
        }
    }

    func makeSession() -> Session {
        switch self {
        case .notes: return NotesSession()
        case .browser: return BrowserSession()
        case .files: return FilesSession()
        case .calculator: return CalcSession()
        }
    }
}

enum KeyInput {
    case text(String), backspace, enter, tab, left, right, up, down
}

/// Estado de cada ventana abierta. Las coordenadas de `click` son locales
/// al contenido (sin la barra de título).
class Session: NSObject, ObservableObject {
    override init() { super.init() }
    func click(at p: CGPoint, size: CGSize, double: Bool) {}
    func key(_ k: KeyInput) {}
    func scroll(dx: CGFloat, dy: CGFloat, at p: CGPoint) {}
}

struct DWindow: Identifiable {
    let id = UUID()
    let seq: Int
    let kind: AppKind
    var frame: CGRect
    var minimized = false
    var maximized = false
    var restoreFrame: CGRect?
    let session: Session
}

// MARK: - Geometría compartida entre dibujo y detección de clics

enum Layout {
    static let titleH: CGFloat = 34
    static let taskH: CGFloat = 52
    static let btnW: CGFloat = 40
    static let menuW: CGFloat = 260
    static let menuRowH: CGFloat = 48

    static func iconRect(_ i: Int) -> CGRect {
        CGRect(x: 24, y: 24 + CGFloat(i) * 108, width: 92, height: 96)
    }
    static func startButton(_ s: CGSize) -> CGRect {
        CGRect(x: 8, y: s.height - taskH + 6, width: 44, height: 40)
    }
    static func taskItem(_ i: Int, _ s: CGSize) -> CGRect {
        CGRect(x: 64 + CGFloat(i) * 52, y: s.height - taskH + 6, width: 46, height: 40)
    }
    static func menuRect(_ s: CGSize) -> CGRect {
        let h = CGFloat(AppKind.allCases.count) * menuRowH + 16
        return CGRect(x: 8, y: s.height - taskH - h - 8, width: menuW, height: h)
    }
    static func menuRow(_ i: Int, _ s: CGSize) -> CGRect {
        let m = menuRect(s)
        return CGRect(x: m.minX + 8, y: m.minY + 8 + CGFloat(i) * menuRowH, width: m.width - 16, height: menuRowH)
    }
    static func closeBtn(_ f: CGRect) -> CGRect { CGRect(x: f.maxX - btnW, y: f.minY, width: btnW, height: titleH) }
    static func maxBtn(_ f: CGRect) -> CGRect { CGRect(x: f.maxX - 2 * btnW, y: f.minY, width: btnW, height: titleH) }
    static func minBtn(_ f: CGRect) -> CGRect { CGRect(x: f.maxX - 3 * btnW, y: f.minY, width: btnW, height: titleH) }
    static func grip(_ f: CGRect) -> CGRect { CGRect(x: f.maxX - 18, y: f.maxY - 18, width: 18, height: 18) }
}

// MARK: - Modelo del escritorio

final class DesktopModel: ObservableObject {
    static let shared = DesktopModel()

    @Published var windows: [DWindow] = []
    @Published var cursor = CGPoint(x: 400, y: 300)
    @Published var screenSize = CGSize(width: 1280, height: 720)
    @Published var startOpen = false
    @Published var selectedIcon: AppKind?
    @Published var externalConnected = false
    @Published var mouseConnected = false
    @Published var keyboardConnected = false

    private enum Drag { case move(UUID, CGPoint), resize(UUID) }
    private var drag: Drag?
    private var seq = 0
    private var lastClick: (time: Date, key: String)?

    var taskbarWindows: [DWindow] { windows.sorted { $0.seq < $1.seq } }

    // MARK: Ventanas

    func open(_ kind: AppKind, session: Session? = nil) {
        let n = windows.count % 6
        let origin = CGPoint(x: 140 + CGFloat(n) * 32, y: 50 + CGFloat(n) * 32)
        seq += 1
        windows.append(DWindow(seq: seq, kind: kind,
                               frame: CGRect(origin: origin, size: kind.defaultSize),
                               session: session ?? kind.makeSession()))
    }

    func focus(_ id: UUID) {
        guard let i = windows.firstIndex(where: { $0.id == id }) else { return }
        var w = windows.remove(at: i)
        w.minimized = false
        windows.append(w)
    }

    func close(_ id: UUID) { windows.removeAll { $0.id == id } }

    func minimize(_ id: UUID) {
        guard let i = windows.firstIndex(where: { $0.id == id }) else { return }
        windows[i].minimized = true
    }

    func toggleMax(_ id: UUID) {
        guard let i = windows.firstIndex(where: { $0.id == id }) else { return }
        if windows[i].maximized {
            windows[i].frame = windows[i].restoreFrame ?? windows[i].frame
            windows[i].maximized = false
        } else {
            windows[i].restoreFrame = windows[i].frame
            windows[i].frame = CGRect(x: 0, y: 0, width: screenSize.width, height: screenSize.height - Layout.taskH)
            windows[i].maximized = true
        }
    }

    // MARK: Entrada (ratón / trackpad / teclado)

    func moveCursor(dx: CGFloat, dy: CGFloat) {
        cursor.x = min(max(0, cursor.x + dx), screenSize.width - 1)
        cursor.y = min(max(0, cursor.y + dy), screenSize.height - 1)
        guard let d = drag else { return }
        switch d {
        case .move(let id, let off):
            if let i = windows.firstIndex(where: { $0.id == id }) {
                windows[i].frame.origin = CGPoint(x: cursor.x - off.x, y: max(0, cursor.y - off.y))
            }
        case .resize(let id):
            if let i = windows.firstIndex(where: { $0.id == id }) {
                let f = windows[i].frame
                windows[i].frame.size = CGSize(width: max(280, cursor.x - f.minX + 9),
                                               height: max(180, cursor.y - f.minY + 9))
            }
        }
    }

    func mouseUp() { drag = nil }

    func mouseDown() {
        let p = cursor, s = screenSize

        if startOpen {
            for (i, k) in AppKind.allCases.enumerated() where Layout.menuRow(i, s).contains(p) {
                open(k); startOpen = false; return
            }
            if Layout.menuRect(s).contains(p) { return }
            if !Layout.startButton(s).contains(p) { startOpen = false }
        }

        if p.y >= s.height - Layout.taskH {
            if Layout.startButton(s).contains(p) { startOpen.toggle(); return }
            for (i, w) in taskbarWindows.enumerated() where Layout.taskItem(i, s).contains(p) {
                if w.minimized || windows.last?.id != w.id { focus(w.id) } else { minimize(w.id) }
                return
            }
            return
        }

        for w in windows.reversed() where !w.minimized && w.frame.contains(p) {
            focus(w.id)
            let f = w.frame
            if Layout.closeBtn(f).contains(p) {
                close(w.id)
            } else if Layout.maxBtn(f).contains(p) {
                toggleMax(w.id)
            } else if Layout.minBtn(f).contains(p) {
                minimize(w.id)
            } else if p.y - f.minY < Layout.titleH {
                if isDouble("t\(w.id)") { toggleMax(w.id) }
                else if !w.maximized { drag = .move(w.id, CGPoint(x: p.x - f.minX, y: p.y - f.minY)) }
            } else if Layout.grip(f).contains(p) && !w.maximized {
                drag = .resize(w.id)
            } else {
                let local = CGPoint(x: p.x - f.minX, y: p.y - f.minY - Layout.titleH)
                let size = CGSize(width: f.width, height: f.height - Layout.titleH)
                w.session.click(at: local, size: size, double: isDouble("c\(w.id)"))
            }
            return
        }

        for (i, k) in AppKind.allCases.enumerated() where Layout.iconRect(i).contains(p) {
            if isDouble(k.rawValue) { open(k); selectedIcon = nil } else { selectedIcon = k }
            return
        }
        selectedIcon = nil
    }

    func scroll(dx: CGFloat, dy: CGFloat) {
        for w in windows.reversed() where !w.minimized && w.frame.contains(cursor) {
            let local = CGPoint(x: cursor.x - w.frame.minX, y: cursor.y - w.frame.minY - Layout.titleH)
            w.session.scroll(dx: dx, dy: dy, at: local)
            return
        }
    }

    func key(_ k: KeyInput) {
        guard let w = windows.last(where: { !$0.minimized }) else { return }
        w.session.key(k)
    }

    private func isDouble(_ key: String) -> Bool {
        let now = Date()
        if let l = lastClick, l.key == key, now.timeIntervalSince(l.time) < 0.45 {
            lastClick = nil
            return true
        }
        lastClick = (now, key)
        return false
    }
}
