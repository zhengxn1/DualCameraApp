import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        let rootVC = ViewController()
        let navController = UINavigationController(rootViewController: rootVC)
        navController.navigationBar.isTranslucent = false
        navController.navigationBar.barStyle = .black
        navController.navigationBar.barTintColor = .black

        window.rootViewController = navController
        window.makeKeyAndVisible()
        self.window = window
    }
}
