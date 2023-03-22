

import UIKit
import AVFoundation

class CameraWorkController: NSObject {
    
    var captureSession: AVCaptureSession? // сессия
    
    var currentCameraPosition: CameraPosition? // определение расположения камеры
    
    var frontCamera: AVCaptureDevice? // фронтальная камера
    var frontCameraInput: AVCaptureDeviceInput?
    
    var photoOutput: AVCapturePhotoOutput? // данные сессии захвата
    
    var rearCamera: AVCaptureDevice? // задняя камера
    var rearCameraInput: AVCaptureDeviceInput?
    
    var previewLayer: AVCaptureVideoPreviewLayer? //  слой предварительного просмотра captureSession

    var flashMode = AVCaptureDevice.FlashMode.off // переключение вспышки
    var photoCaptureCompletionBlock: ((UIImage?, Error?) -> Void)? // работа с захватом изображения

}

extension CameraWorkController {
    
    //MARK: - создание и настройка новой сессии захвата
    func prepare(completionHandler: @escaping (Error?) -> Void) {
        //MARK: - 1. Создание сеанса захвата
        func createCaptureSession() {
            self.captureSession = AVCaptureSession()
        }
        
        //MARK: - 2. Получение и настройка необходимых устройств захвата
        // ~~ 1 ~~ найти все широкоугольные камеры, доступные на текущем устройстве, преобразовать их в массив неопциональных экземпляров (если камеры не доступны - выдается ошибка)
        func configureCaptureDevices() throws {
            let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .unspecified)
            
            let cameras = (session.devices.compactMap { $0 })
            guard !cameras.isEmpty else { throw CameraWorkControllerError.noCamerasAvailable }
            
            // ~~ 2 ~~ просмотр доступных камер (найденных выше), определение фронтальной и задней камеры, доп настройка задней камеры на автофокусировку (параллельное отслеживание ошибок)
            for camera in cameras {
                if camera.position == .front {
                    self.frontCamera = camera
                }
                
                if camera.position == .back {
                    self.rearCamera = camera
                    
                    try camera.lockForConfiguration()
                    camera.focusMode = .continuousAutoFocus
                    camera.unlockForConfiguration()
                }
            }
        }
        
        //MARK: - 3. Создание входов с помощью устройств захвата
        func configureDeviceInputs() throws {
            // ~~ 3 ~~ гарантирует наличие captureSession, если нет - выдаем ошибку
            guard let captureSession = self.captureSession else { throw CameraWorkControllerError.captureSessionIsMissing }
            
            // ~~ 4 ~~ Эти операторы if отвечают за создание необходимых входных данных устройства захвата для поддержки захвата фотографий. AVFoundation допускает только один ввод с камеры для каждого сеанса захвата одновременно. Поскольку задняя камера традиционно используется по умолчанию, мы пытаемся создать входные данные с нее и добавить их в сеанс захвата. Если это не удастся, мы вернемся к фронтальной камере. Если и это не удается, мы выдаем ошибку.
            if let rearCamera = self.rearCamera {
                self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
                
                if captureSession.canAddInput(self.rearCameraInput!) { captureSession.addInput(self.rearCameraInput!) }
                
                self.currentCameraPosition = .rear
            }
            
            else if let frontCamera = self.frontCamera {
                self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
                
                if captureSession.canAddInput(self.frontCameraInput!) { captureSession.addInput(self.frontCameraInput!) }
                else { throw CameraWorkControllerError.inputsAreInvalid }
                
                self.currentCameraPosition = .front
            }
            
            else { throw CameraWorkControllerError.noCamerasAvailable }
        }
        
        //MARK: - 4. Настройка объекта вывода фотографий для обработки захваченных изображений
        func configurePhotoOutput() throws {
            
            guard let captureSession = self.captureSession else { throw CameraWorkControllerError.captureSessionIsMissing }
            
            self.photoOutput = AVCapturePhotoOutput()
            //    self.photoOutput!.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecJPEG])], completionHandler: nil)
            self.photoOutput!.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecType.jpeg])], completionHandler: nil) // вывод фото в формате jpeg для своего кодека
            
            if captureSession.canAddOutput(self.photoOutput!) { // добавдяет захват фото в нашу сессию
                captureSession.addOutput(self.photoOutput!) }
            
            captureSession.startRunning() // начинаем захват
        }
        
        DispatchQueue(label: "prepare").async {
            do {
                createCaptureSession()
                try configureCaptureDevices()
                try configureDeviceInputs()
                try configurePhotoOutput()
            }
            
            catch {
                DispatchQueue.main.async {
                    completionHandler(error)
                }
                return
            }
            
            DispatchQueue.main.async {
                completionHandler(nil)
            }
        }
    }
    
    //MARK: - создание предварительного просмотра захвата и его отображение в предоставленном представлении
    func displayPreview(on view: UIView) throws {
        guard let captureSession = self.captureSession, captureSession.isRunning else { throw CameraWorkControllerError.captureSessionIsMissing }
        
        self.previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        self.previewLayer?.connection?.videoOrientation = .portrait
        
        view.layer.insertSublayer(self.previewLayer!, at: 0)
        self.previewLayer?.frame = view.frame
    }
    
    func switchCameras() throws {
        // гарантирует наличие сеанса захвата, до переключения камеры. Также проверяет наличие активной камеры
        guard let currentCameraPosition = currentCameraPosition, let captureSession = self.captureSession, captureSession.isRunning else { throw CameraWorkControllerError.captureSessionIsMissing }
         
        // настройка сеанса захвата
        captureSession.beginConfiguration()
         
        // переключение на фронтальную камеру (Обе функции имеют чрезвычайно схожие реализации. Они начинают с получения массива всех входных данных в сеансе захвата и обеспечения возможности переключения на камеру запроса. Затем они создают необходимое устройство ввода, удаляют старое и добавляют новое. Наконец, они устанавливают CurrentCameraPosition так, чтобы класс CameraWorkController знал об изменениях)
        func switchToFrontCamera() throws {
            guard let rearCameraInput = self.rearCameraInput, captureSession.inputs.contains(rearCameraInput),
                let frontCamera = self.frontCamera else { throw CameraWorkControllerError.invalidOperation }
            
            self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
            
            captureSession.removeInput(rearCameraInput)
            
            if captureSession.canAddInput(self.frontCameraInput!) {
                captureSession.addInput(self.frontCameraInput!)
                self.currentCameraPosition = .front
            }
            else {
                throw CameraWorkControllerError.invalidOperation
            }
        }
        
        // переключение на заднюю камеру
        func switchToRearCamera() throws {
            guard let frontCameraInput = self.frontCameraInput, captureSession.inputs.contains(frontCameraInput),
                let rearCamera = self.rearCamera else { throw CameraWorkControllerError.invalidOperation }
            
            self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
            
            captureSession.removeInput(frontCameraInput)
            
            if captureSession.canAddInput(self.rearCameraInput!) {
                captureSession.addInput(self.rearCameraInput!)
                self.currentCameraPosition = .rear
            }
            else { throw CameraWorkControllerError.invalidOperation }
        }
         
        // переключение между камерами, в зависимости от активной камеры в момент переключения
        switch currentCameraPosition {
        case .front:
            try switchToRearCamera()
        case .rear:
            try switchToFrontCamera()
        }
         
        // фиксация или сохранение сессии захвата после ее настройки
        captureSession.commitConfiguration()
    }
    
    // захват изображения с контроллера камеры
    func captureImage(completion: @escaping (UIImage?, Error?) -> Void) {
        guard let captureSession = captureSession, captureSession.isRunning else { completion(nil, CameraWorkControllerError.captureSessionIsMissing); return }
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = self.flashMode
        
        self.photoOutput?.capturePhoto(with: settings, delegate: self)
        self.photoCaptureCompletionBlock = completion
    }
}

extension CameraWorkController: AVCapturePhotoCaptureDelegate {
    public func photoOutput(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?,
                        resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Swift.Error?) {
        if let error = error { self.photoCaptureCompletionBlock?(nil, error) }
            
        else if let buffer = photoSampleBuffer, let data = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: buffer, previewPhotoSampleBuffer: nil),
            let image = UIImage(data: data) {
            self.photoCaptureCompletionBlock?(image, nil)
        }
            
        else {
            self.photoCaptureCompletionBlock?(nil, CameraWorkControllerError.unknown)
        }
    }
}

extension CameraWorkController {
    // управление ошибками на сеансе захвата
    enum CameraWorkControllerError: Swift.Error {
        case captureSessionAlreadyRunning
        case captureSessionIsMissing
        case inputsAreInvalid
        case invalidOperation
        case noCamerasAvailable
        case unknown
    }
    
    // определение расположения камер
    public enum CameraPosition {
        case front // фронтальная
        case rear // задняя (есть автофокусировка - надо учесть)
    }
}
