
import UIKit
import AVFoundation

class AssetStore { // класс помощник
    let video1: AVAsset // типБ отвечающих за медиа файл
    let video2: AVAsset
    let video3: AVAsset
    let music1: AVAsset
    let music2: AVAsset
    
    init(video1: AVAsset, video2: AVAsset, video3: AVAsset, music1: AVAsset, music2: AVAsset) {
        self.video1 = video1
        self.video2 = video2
        self.video3 = video3
        self.music1 = music1
        self.music2 = music2
    }
    
    static func asset(_ resource: String, type: String) -> AVAsset {
        guard let path = Bundle.main.path(forResource: resource, ofType: type)  else { fatalError() } // получим путь
        let url = URL(fileURLWithPath: path) // из пути создадим URL
        return AVAsset(url: url) // вернем AVAasset
    }
    
    static func test() -> AssetStore {
        return AssetStore(video1: asset("video1", type: "mp4"),
                          video2: asset("video3", type: "mp4"),
                          video3: asset("video2", type: "mp4"),
                          music1: asset("christmas-story", type: "mp3"),
                          music2: asset("christmas-day", type: "mp3")
        )
    }
    
    //MARK: - функция, создающая композицию
    func compose() -> (AVAsset, AVVideoComposition) {
        
        let composition = AVMutableComposition() // класс композиции
        let videoComposition = AVMutableVideoComposition(propertiesOf: composition) // инструкции для нашей композиции (как будет происходить проигрывание наших двух треков (не содержит видеофайлы, а содержит только инструкции как происходит взаимодействие)
        
        //  videoComposition.renderSize = CGSize(width: 828, height: 1792)
        
        let videoSize = video1.tracks(withMediaType: .video)[0].naturalSize
        videoComposition.renderSize = CGSize(width: videoSize.width, height: videoSize.height)
        
        
        //MARK: - добавление видео и аудио дорожек
        guard let videoTrack1 = composition.addMutableTrack(withMediaType: .video, preferredTrackID: Int32(kCMPersistentTrackID_Invalid)) else { fatalError() }
        guard let videoTrack2 = composition.addMutableTrack(withMediaType: .video, preferredTrackID: Int32(kCMPersistentTrackID_Invalid)) else { fatalError() }
        guard let videoTrack3 = composition.addMutableTrack(withMediaType: .video, preferredTrackID: Int32(kCMPersistentTrackID_Invalid)) else { fatalError() }
        guard let audioTrack1 = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: Int32(kCMPersistentTrackID_Invalid)) else { fatalError() }
        guard let audioTrack2 = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: Int32(kCMPersistentTrackID_Invalid)) else { fatalError() }
        
        //MARK: - переход
        let transitionDuration = CMTime(seconds: 2, preferredTimescale: 600) //визуальный эффекта при переходе от одного видео к другому
        
        //MARK: - вставим треки на наши видеодорожки
        try? videoTrack1.insertTimeRange(CMTimeRange(start: CMTime.zero, duration: video1.duration), of: video1.tracks(withMediaType: .video)[0], at: CMTime.zero)
        
        try? videoTrack2.insertTimeRange(CMTimeRange(start: CMTime.zero, duration: video2.duration), of: video2.tracks(withMediaType: .video)[0], at: video1.duration - transitionDuration)
        
        try? videoTrack3.insertTimeRange(CMTimeRange(start: CMTime.zero, duration: video3.duration), of: video3.tracks(withMediaType: .video)[0], at: video1.duration + video2.duration - transitionDuration) // или нужно 2 transitionDuration вычесть
        
        try? audioTrack1.insertTimeRange(CMTimeRange(start: CMTime.zero, duration: video1.duration), of: music1.tracks(withMediaType: .audio)[0], at: CMTime.zero)
        
        try? audioTrack2.insertTimeRange(CMTimeRange(start: CMTime.zero, duration: video2.duration + video3.duration), of: music2.tracks(withMediaType: .audio)[0], at: video1.duration - transitionDuration) // здесь наложение музыки на transitionDuration для красоты, тк без налождения возникает некрасивый провал в соединении музкомов
        
        //MARK: - инструкции отрезков
        // инструкция первого отрезка
        let passThroughInstruction1 = AVMutableVideoCompositionInstruction()
        passThroughInstruction1.timeRange = CMTimeRange(start: CMTime.zero, duration: video1.duration - transitionDuration)
        
        // инструкция второго отрезка
        let passThroughInstruction2 = AVMutableVideoCompositionInstruction()
        passThroughInstruction2.timeRange = CMTimeRange(start: video1.duration, duration: video2.duration)
        
        // инструкция третьего отрезка
        let passThroughInstruction3 = AVMutableVideoCompositionInstruction()
        passThroughInstruction3.timeRange = CMTimeRange(start: video1.duration + video2.duration, duration: video3.duration)
        
        //MARK: - инструкция перехода отрезка 1 на 2
        //MARK: - переход между video1 и video2 (между первым и вторым — изначально второе видео добавляется слева от первого, за экраном. Оба видео сдвигаются вправо так, что первое видео становится полностью за экраном (справа), а второе — в центре экрана)
        let instruction1 = AVMutableVideoCompositionInstruction()
        
        instruction1.timeRange = CMTimeRange(start: video1.duration - transitionDuration, duration: transitionDuration)
        let fadeInInstruсtion1 = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack1)
        
        let video1pos1 = CGAffineTransform(translationX: 0, y: 0)
        let video1pos2 = CGAffineTransform(translationX: videoComposition.renderSize.width, y: 0)
        fadeInInstruсtion1.setTransformRamp(fromStart: video1pos1, toEnd: video1pos2, timeRange: instruction1.timeRange)
        let passThroughLayerInstruction1 = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack1)
        
        passThroughLayerInstruction1.setTransform(videoTrack1.preferredTransform, at: CMTime.zero)
        passThroughInstruction1.layerInstructions = [passThroughLayerInstruction1]
        
        let fadeOutInstruction1 = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack2)
        let video2pos1 = CGAffineTransform(translationX: -videoComposition.renderSize.width, y: 0)
        let video2pos2 = CGAffineTransform(translationX: 0, y: 0)
        fadeOutInstruction1.setTransformRamp(fromStart: video2pos1, toEnd: video2pos2, timeRange: instruction1.timeRange)
        let passThroughLayerInstruction2 = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack2)
        
        passThroughLayerInstruction2.setTransform(videoTrack2.preferredTransform, at: CMTime.zero)
        passThroughInstruction2.layerInstructions = [passThroughLayerInstruction2]
        
        //MARK: - переход между video2 и video3 (между вторым и третьим — третье изначально добавляется в центре экрана со скейлом 0.001 и увеличивается до полноценного размера, полностью закрывая второе видео)
        let instruction2 = AVMutableVideoCompositionInstruction()
        instruction2.timeRange = CMTimeRange(start: video1.duration + video2.duration, duration: transitionDuration)
        let video3Instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack3)
        
        let video2Size = video2.tracks(withMediaType: .video)[0].naturalSize
        let video3Size = video3.tracks(withMediaType: .video)[0].naturalSize
        let w = video2Size.width / video3Size.width
        let h = video2Size.height / video3Size.height
        let video3scale1 = CGAffineTransform(scaleX: 0.001, y: 0.001) // (scaleX: 0.001, y: 0.001)
        let video3scale2 = CGAffineTransform(scaleX: w, y: h)
        
        video3Instruction.setTransformRamp(fromStart: video3scale1, toEnd: video3scale2, timeRange: instruction2.timeRange)
        passThroughInstruction3.layerInstructions.append(video3Instruction)
        
        //MARK: - video composition instructions
        instruction1.layerInstructions = [fadeInInstruсtion1, fadeOutInstruction1, video3Instruction]
        
        videoComposition.instructions = [passThroughInstruction1, instruction1, passThroughInstruction2, passThroughInstruction3]
        
        return (composition, videoComposition) // вернем композицию
    }
    
    //MARK: - выгрузка и сохранение
    func export(asset: AVAsset, composition: AVVideoComposition, completion: @escaping (Bool) -> Void){
        guard let documentDirectory = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask).first else { fatalError("documentDirectory") }

        let url = documentDirectory.appendingPathComponent("video-\(arc4random()).mov")

        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else { fatalError("exporter") }

        exporter.outputURL = url
        exporter.outputFileType = .mov
        exporter.videoComposition = composition

        exporter.exportAsynchronously {
            // print(exporter.error)
            DispatchQueue.main.async {
                completion(exporter.status == .completed)
                print("Full Path: \(url.absoluteString.dropFirst(7))")
            }
        }
    }
}

class VideoViewController: UIViewController {
    
    static let shared = VideoViewController()

    let store = AssetStore.test()
    
  //  let queueStepByStep = OperationQueue() // очередь, для того чтобы после проигрывания видео удалить его со слоя
    
    @IBOutlet weak var playerView: UIView! // вью для слоя для воспроизведения видео (вынесла на отдельное вью)
    
    @IBAction func playMovie(_ sender: UIButton) {
      
            let (asset, videoComposition) = self.store.compose()
            self.startPlaying(asset: asset, videoComposition: videoComposition) // проиграем композицию
//            self.player.pause()
//            self.playerLayer.removeFromSuperlayer()
        
    }
    
    @IBAction func saveMovie(_ sender: Any) {
        store.export(asset: store.compose().0, composition: store.compose().1) { success in
            print("Saved: \(success)")
        }
    }
        
    var player = AVPlayer()
    var playerLayer = AVPlayerLayer() // слой проигрывания
    
    func startPlaying(asset: AVAsset, videoComposition: AVVideoComposition) { // проигрывание
        let playerItem = AVPlayerItem(asset: asset) // создадим playerItem
        playerItem.videoComposition = videoComposition
        player = AVPlayer(playerItem: playerItem) // положим его в player
        playerLayer = AVPlayerLayer(player: player) // и положим все на слой
        //  playerLayer.frame = CGRect(origin: .zero, size: videoSize)
        playerLayer.frame = playerView.bounds
        playerView.layer.addSublayer(playerLayer) // на наш вью в лэйер добавим саблэйер, в котором playerLayer
        
        player.play() // и проиграем
    }
}
