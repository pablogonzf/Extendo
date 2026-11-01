import SwiftUI
import UIKit

@main
struct DesktopOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ControlView()
        }
    }
}

/// Decide qué hace cada escena: la principal (iPhone) la gestiona SwiftUI,
/// la del monitor externo muestra el escritorio.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        if connectingSceneSession.role == .windowExternalDisplayNonInteractive {
            config.delegateClass = ExternalSceneDelegate.self
        }
        return config
    }
}

/// Se crea cuando conectas un monitor y se destruye al desconectarlo.
final class ExternalSceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: DesktopView(model: .shared))
        window.isHidden = false
        self.window = window
        DesktopModel.shared.externalConnected = true
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        window = nil
        DesktopModel.shared.externalConnected = false
    }
}
