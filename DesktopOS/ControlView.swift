import SwiftUI

/// Pantalla del iPhone: estado + trackpad. El escritorio se ve en el monitor.
struct ControlView: View {
    @ObservedObject private var model = DesktopModel.shared
    @State private var last: CGPoint?
    @State private var moved: CGFloat = 0
    @State private var scrollLast: CGFloat?
    @State private var dragMode = false
    @State private var preview = false

    private let sensitivity: CGFloat = 1.8

    var body: some View {
        VStack(spacing: 12) {
            statusRow

            if preview && !model.externalConnected {
                GeometryReader { geo in
                    let scale = geo.size.width / 1280
                    DesktopView(model: model)
                        .frame(width: 1280, height: 720)
                        .scaleEffect(scale, anchor: .topLeading)
                        .frame(width: 1280 * scale, height: 720 * scale, alignment: .topLeading)
                }
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack(spacing: 12) {
                trackpad
                scrollStrip
            }

            HStack {
                Toggle("Arrastrar", isOn: $dragMode).toggleStyle(.button)
                Toggle("Vista previa", isOn: $preview).toggleStyle(.button).disabled(model.externalConnected)
                Spacer()
                Button("Abrir menú") { model.startOpen.toggle() }
            }
        }
        .padding()
        .onAppear {
            InputManager.shared.start()
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }

    private var statusRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            row("display", model.externalConnected ? "Monitor conectado" : "Conecta un monitor por USB-C", model.externalConnected)
            row("computermouse", model.mouseConnected ? "Ratón conectado" : "Sin ratón (usa el trackpad)", model.mouseConnected)
            row("keyboard", model.keyboardConnected ? "Teclado conectado" : "Sin teclado", model.keyboardConnected)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ icon: String, _ text: String, _ ok: Bool) -> some View {
        Label(text, systemImage: icon).foregroundColor(ok ? .green : .secondary).font(.subheadline)
    }

    private var trackpad: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.secondarySystemBackground))
            .overlay(Text("Trackpad\ntoca = clic").multilineTextAlignment(.center).foregroundColor(.secondary))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if let l = last {
                            let dx = v.location.x - l.x, dy = v.location.y - l.y
                            moved += abs(dx) + abs(dy)
                            model.moveCursor(dx: dx * sensitivity, dy: dy * sensitivity)
                        } else {
                            moved = 0
                            if dragMode { model.mouseDown() }
                        }
                        last = v.location
                    }
                    .onEnded { _ in
                        if dragMode { model.mouseUp() }
                        else if moved < 6 { model.mouseDown(); model.mouseUp() }
                        last = nil
                    }
            )
    }

    private var scrollStrip: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.tertiarySystemBackground))
            .frame(width: 56)
            .overlay(Image(systemName: "arrow.up.and.down").foregroundColor(.secondary))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if let l = scrollLast { model.scroll(dx: 0, dy: -(v.location.y - l) * 3) }
                        scrollLast = v.location.y
                    }
                    .onEnded { _ in scrollLast = nil }
            )
    }
}
