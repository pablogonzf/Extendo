import GameController

/// Lee un ratón y un teclado físicos conectados al iPhone (Bluetooth o USB)
/// y los convierte en eventos del escritorio.
final class InputManager {
    static let shared = InputManager()
    private var started = false
    private var model: DesktopModel { .shared }

    func start() {
        guard !started else { return }
        started = true
        let nc = NotificationCenter.default
        nc.addObserver(forName: .GCMouseDidConnect, object: nil, queue: .main) { [weak self] n in
            if let m = n.object as? GCMouse { self?.setup(mouse: m) }
        }
        nc.addObserver(forName: .GCMouseDidDisconnect, object: nil, queue: .main) { [weak self] _ in
            self?.model.mouseConnected = !GCMouse.mice().isEmpty
        }
        nc.addObserver(forName: .GCKeyboardDidConnect, object: nil, queue: .main) { [weak self] n in
            if let k = n.object as? GCKeyboard { self?.setup(keyboard: k) }
        }
        nc.addObserver(forName: .GCKeyboardDidDisconnect, object: nil, queue: .main) { [weak self] _ in
            self?.model.keyboardConnected = GCKeyboard.coalesced != nil
        }
        for m in GCMouse.mice() { setup(mouse: m) }
        if let k = GCKeyboard.coalesced { setup(keyboard: k) }
    }

    // MARK: Ratón

    private let sensitivity: CGFloat = 1.5

    private func setup(mouse: GCMouse) {
        guard let input = mouse.mouseInput else { return }
        model.mouseConnected = true
        input.mouseMovedHandler = { [weak self] _, dx, dy in
            guard let self else { return }
            DispatchQueue.main.async {
                // Si el cursor va invertido en vertical, cambia el signo de dy.
                self.model.moveCursor(dx: CGFloat(dx) * self.sensitivity, dy: CGFloat(-dy) * self.sensitivity)
            }
        }
        input.leftButton.pressedChangedHandler = { [weak self] _, _, pressed in
            DispatchQueue.main.async { pressed ? self?.model.mouseDown() : self?.model.mouseUp() }
        }
        input.scroll.valueChangedHandler = { [weak self] _, x, y in
            DispatchQueue.main.async {
                // Si el scroll va al revés, cambia el signo de y.
                self?.model.scroll(dx: CGFloat(x) * 20, dy: CGFloat(-y) * 20)
            }
        }
    }

    // MARK: Teclado (códigos HID, distribución de teclas física tipo US)

    private func setup(keyboard: GCKeyboard) {
        guard let input = keyboard.keyboardInput else { return }
        model.keyboardConnected = true
        input.keyChangedHandler = { [weak self] kb, _, code, pressed in
            guard pressed else { return }
            let shift = (kb.button(forKeyCode: .leftShift)?.isPressed ?? false)
                || (kb.button(forKeyCode: .rightShift)?.isPressed ?? false)
            if let k = Self.map(code.rawValue, shift: shift) {
                DispatchQueue.main.async { self?.model.key(k) }
            }
        }
    }

    private static let punctuation: [Int: (String, String)] = [
        44: (" ", " "), 45: ("-", "_"), 46: ("=", "+"), 47: ("[", "{"), 48: ("]", "}"),
        49: ("\\", "|"), 51: (";", ":"), 52: ("'", "\""), 53: ("`", "~"),
        54: (",", "<"), 55: (".", ">"), 56: ("/", "?"),
    ]
    private static let shiftedDigits = Array("!@#$%^&*()")

    private static func map(_ code: Int, shift: Bool) -> KeyInput? {
        switch code {
        case 4...29:
            let c = Character(UnicodeScalar(UInt8(97 + code - 4)))
            return .text(shift ? String(c).uppercased() : String(c))
        case 30...38:
            return .text(shift ? String(shiftedDigits[code - 30]) : String(code - 29))
        case 39:
            return .text(shift ? String(shiftedDigits[9]) : "0")
        case 40: return .enter
        case 42: return .backspace
        case 43: return .tab
        case 79: return .right
        case 80: return .left
        case 81: return .down
        case 82: return .up
        default:
            if let p = punctuation[code] { return .text(shift ? p.1 : p.0) }
            return nil
        }
    }
}
