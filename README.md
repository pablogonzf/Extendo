# Extendo

App de iOS que, al conectar un monitor por USB-C, dibuja en él un escritorio simulado
(ventanas, barra de tareas, menú de inicio y mini-apps). El iPhone hace de trackpad, y
también puedes conectarle un ratón y un teclado.

## Abrir en Xcode

```bash
brew install xcodegen
cd Extendo
xcodegen generate
open Extendo.xcodeproj
```

En Xcode: Signing & Capabilities → elige tu Team, ejecuta en un iPhone real.
(Sin XcodeGen: crea un proyecto iOS App con SwiftUI, borra su ContentView y App,
arrastra los `.swift` de `Extendo/`, y en Info añade
`Application Scene Manifest → Enable Multiple Windows = YES`.)

## Uso

1. Abre la app en el iPhone y luego conecta el monitor (iPhone 15 o posterior para USB-C con vídeo).
2. El monitor muestra el escritorio. Doble clic en un icono o usa el menú de inicio.
3. Mueve el cursor con el trackpad de la pantalla del iPhone o con un ratón; toca para hacer clic.
4. "Vista previa" muestra el escritorio en el iPhone para probar sin monitor.

## Mini-apps

Notas, Navegador (WebKit; clic, scroll y escribir en páginas), Archivos (carpeta Documentos
de la app, visible desde la app Archivos de iOS) y Calculadora.

## Limitaciones

- iOS no lanza la app al conectar el monitor: ábrela antes.
- El monitor es "no interactivo": por eso el cursor y los clics están implementados a mano.
- El teclado se mapea como distribución física tipo US.
- Si el cursor o el scroll van invertidos, cambia el signo en `InputManager.swift`.
