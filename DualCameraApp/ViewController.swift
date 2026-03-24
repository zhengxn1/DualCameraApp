import UIKit
import AVFoundation

class ViewController: UIViewController {

    // MARK: - Camera
    private let cameraManager = DualCameraManager()

    // MARK: - UI
    private lazy var backCameraView: UIView = makePreviewContainer()
    private lazy var frontCameraView: UIView = makePreviewContainer()

    private lazy var backLabel: UILabel = makeLabel("后置摄像头")
    private lazy var frontLabel: UILabel = makeLabel("前置摄像头")

    private lazy var divider: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.white.withAlphaComponent(0.4)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var captureButton: UIButton = {
        let btn = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 52, weight: .thin)
        btn.setImage(UIImage(systemName: "camera.circle.fill", withConfiguration: config), for: .normal)
        btn.tintColor = .white
        btn.backgroundColor = UIColor.white.withAlphaComponent(0.25)
        btn.layer.cornerRadius = 40
        btn.clipsToBounds = true
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(captureTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var statusLabel: UILabel = {
        let lbl = UILabel()
        lbl.textColor = .white
        lbl.font = .systemFont(ofSize: 14, weight: .medium)
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.color = .white
        ai.hidesWhenStopped = true
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        setupLayout()
        setupCamera()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cameraManager.startSession()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cameraManager.stopSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        cameraManager.backPreviewLayer?.frame = backCameraView.bounds
        cameraManager.frontPreviewLayer?.frame = frontCameraView.bounds
    }

    // MARK: - Navigation
    private func setupNavigationBar() {
        title = "双摄同拍"
        navigationController?.navigationBar.barTintColor = .black
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationController?.navigationBar.tintColor = .white
        view.backgroundColor = .black
    }

    // MARK: - Layout
    private func setupLayout() {
        [backCameraView, divider, frontCameraView, captureButton, statusLabel, activityIndicator].forEach {
            view.addSubview($0)
        }
        backCameraView.addSubview(backLabel)
        frontCameraView.addSubview(frontLabel)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            // Back view: top half
            backCameraView.topAnchor.constraint(equalTo: safe.topAnchor),
            backCameraView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backCameraView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backCameraView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.44),

            // Divider
            divider.topAnchor.constraint(equalTo: backCameraView.bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 2),

            // Front view: second half
            frontCameraView.topAnchor.constraint(equalTo: divider.bottomAnchor),
            frontCameraView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            frontCameraView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            frontCameraView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.44),

            // Labels
            backLabel.topAnchor.constraint(equalTo: backCameraView.topAnchor, constant: 12),
            backLabel.leadingAnchor.constraint(equalTo: backCameraView.leadingAnchor, constant: 16),
            frontLabel.topAnchor.constraint(equalTo: frontCameraView.topAnchor, constant: 12),
            frontLabel.leadingAnchor.constraint(equalTo: frontCameraView.leadingAnchor, constant: 16),

            // Capture button
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -16),
            captureButton.widthAnchor.constraint(equalToConstant: 80),
            captureButton.heightAnchor.constraint(equalToConstant: 80),

            // Status & indicator
            statusLabel.bottomAnchor.constraint(equalTo: captureButton.topAnchor, constant: -10),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -6),
        ])
    }

    // MARK: - Camera Setup
    private func setupCamera() {
        cameraManager.requestPermissions { [weak self] granted in
            guard let self else { return }
            guard granted else {
                self.showPermissionAlert()
                return
            }
            do {
                try self.cameraManager.setupSession()
                self.attachPreviewLayers()
                self.cameraManager.startSession()
                self.cameraManager.onPhotoCaptured = { [weak self] _, _ in
                    self?.onCaptureComplete()
                }
                self.cameraManager.onError = { [weak self] message in
                    self?.showAlert(title: "拍摄错误", message: message)
                }
            } catch let e as DualCameraError {
                self.showAlert(title: "初始化失败", message: e.localizedDescription)
            } catch {
                self.showAlert(title: "错误", message: error.localizedDescription)
            }
        }
    }

    private func attachPreviewLayers() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let back = self.cameraManager.backPreviewLayer {
                back.frame = self.backCameraView.bounds
                self.backCameraView.layer.insertSublayer(back, at: 0)
            }
            if let front = self.cameraManager.frontPreviewLayer {
                front.frame = self.frontCameraView.bounds
                self.frontCameraView.layer.insertSublayer(front, at: 0)
            }
            self.backCameraView.bringSubviewToFront(self.backLabel)
            self.frontCameraView.bringSubviewToFront(self.frontLabel)
        }
    }

    // MARK: - Actions
    @objc private func captureTapped() {
        captureButton.isEnabled = false
        activityIndicator.startAnimating()
        statusLabel.text = "正在同时拍摄..."
        cameraManager.capturePhotos()

        // Safety timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.captureButton.isEnabled = true
            self?.activityIndicator.stopAnimating()
        }
    }

    private func onCaptureComplete() {
        captureButton.isEnabled = true
        activityIndicator.stopAnimating()
        statusLabel.text = "前后置照片已保存到相册"
        flashScreen()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.statusLabel.text = ""
        }
    }

    // MARK: - Helpers
    private func flashScreen() {
        let flash = UIView(frame: view.bounds)
        flash.backgroundColor = .white
        flash.alpha = 0
        view.addSubview(flash)
        UIView.animate(withDuration: 0.08) { flash.alpha = 0.9 } completion: { _ in
            UIView.animate(withDuration: 0.25) { flash.alpha = 0 } completion: { _ in
                flash.removeFromSuperview()
            }
        }
    }

    private func showAlert(title: String, message: String) {
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            self?.present(alert, animated: true)
        }
    }

    private func showPermissionAlert() {
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(
                title: "需要权限",
                message: "请在「设置 > 隐私」中允许访问摄像头和相册",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "去设置", style: .default) { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            })
            alert.addAction(UIAlertAction(title: "取消", style: .cancel))
            self?.present(alert, animated: true)
        }
    }

    // MARK: - Factory
    private func makePreviewContainer() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor(white: 0.1, alpha: 1)
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    private func makeLabel(_ text: String) -> UILabel {
        let lbl = UILabel()
        lbl.text = "  \(text)  "
        lbl.textColor = .white
        lbl.font = .systemFont(ofSize: 13, weight: .semibold)
        lbl.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        lbl.layer.cornerRadius = 6
        lbl.clipsToBounds = true
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }
}
