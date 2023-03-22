
import UIKit
import Photos

class CameraViewController: UIViewController {
    
    let cameraWorkController = CameraWorkController()
    
    //  override var prefersStatusBarHidden: Bool { return true }
    
    @IBOutlet weak var captureButton: UIButton! { didSet {
        captureButton.layer.borderColor = UIColor.systemGreen.cgColor
        captureButton.layer.borderWidth = 2
        captureButton.layer.cornerRadius = captureButton.frame.size.height / 2
    }}
    
    @IBOutlet weak var capturePreviewView: UIView! // предварительный просмотр видеовыхода, создаваемого камерами устройства
    
    // Позволяет пользователю перевести камеру в режим фотосъемки.
    @IBOutlet weak var toggleFlashButton: UIButton!
    @IBOutlet weak var toggleCameraButton: UIButton!
  
    @IBAction func toggleFlash(_ sender: UIButton) { // включение и выключение вспышки
        if cameraWorkController.flashMode == .on {
            cameraWorkController.flashMode = .off
            toggleFlashButton.setImage(#imageLiteral(resourceName: "Flash Off Icon"), for: .normal)
        }
        
        else {
            cameraWorkController.flashMode = .on
            toggleFlashButton.setImage(#imageLiteral(resourceName: "Flash On Icon"), for: .normal)
        }
        
        flashlight()
    }
    
    func flashlight() { // вспышка через факел (тк AVCaptureDevice.FlashMode { get set }, устарел )
        let device = AVCaptureDevice.default(for: AVMediaType.video)
        if (device?.hasTorch)! {
            do {
                try device?.lockForConfiguration()
                if (device?.torchMode == AVCaptureDevice.TorchMode.on) {
                    device?.torchMode = AVCaptureDevice.TorchMode.off
                } else {
                    do {
                        try device?.setTorchModeOn(level: 1.0) // можно добавить скролл посветки 
                    } catch {
                        print(error)
                    }
                }
                device?.unlockForConfiguration()
            } catch {
                print(error)
            }
        }
    }
    
    @IBAction func switchCameras(_ sender: UIButton) {
        do {
            try cameraWorkController.switchCameras()
        }
        catch {
            print(error)
        }
        switch cameraWorkController.currentCameraPosition {
        case .some(.front):
            toggleCameraButton.setImage(#imageLiteral(resourceName: "Front Camera Icon"), for: .normal)
        case .some(.rear):
            toggleCameraButton.setImage(#imageLiteral(resourceName: "Rear Camera Icon"), for: .normal)
        case .none:
            return
        }
    }
    
    // делаем снимок и сохраняем его в библиотеке
    @IBAction func captureImage(_ sender: UIButton) {
        cameraWorkController.captureImage {(image, error) in
            guard let image = image else {
                print(error ?? "Image capture error")
                return
            }
            try? PHPhotoLibrary.shared().performChangesAndWait {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        func configureCameraController() {
            cameraWorkController.prepare {(error) in
                if let error = error {
                    print(error)
                }
                try? self.cameraWorkController.displayPreview(on: self.capturePreviewView)
            }
        }
        configureCameraController()
    }
}
