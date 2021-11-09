//
//  ViewController.swift
//  KirbyCamera2
//
//  Created by kt on 2021/05/27.
//

import UIKit
import AVFoundation
import Photos

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, UIGestureRecognizerDelegate {
    
    var input: AVCaptureDeviceInput!
    var output: AVCaptureVideoDataOutput!
    var session: AVCaptureSession!
    var camera: AVCaptureDevice!
    var imageView: UIImageView!
    var audioPlayer: AVAudioPlayer?
    
    @IBOutlet weak var wdBtn: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()
        styleCaptureButton()
        
        PHPhotoLibrary.requestAuthorization({_ in })

        // 画面タップでピントをあわせる
        
        
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        setupDisplay()
        setupCamera()
    }
    
    @IBAction func wdShutter(_ sender: Any) {
        customSound()
        takeStillPicture()
    }
    
    func takeStillPicture(){
        if var _:AVCaptureConnection =
            output.connection(with: AVMediaType.video){
            // アルバムに追加
            UIImageWriteToSavedPhotosAlbum(self.imageView.image!,
                                           self, nil, nil)
        }
    }
    
    func customSound(){
        guard let path = Bundle.main.path(forResource: "Hi_Kirby", ofType: "mp3") else {
            print("音源が見つからないよ"); return
        }
        do {
            try audioPlayer = AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
            audioPlayer?.play()
        }catch{
            print("audioError")
        }
    }
    
    func styleCaptureButton() {
        wdBtn.layer.borderColor = UIColor.white.cgColor
        wdBtn.layer.borderWidth = 5
        wdBtn.clipsToBounds = true
        wdBtn.layer.cornerRadius = min(wdBtn.frame.width, wdBtn.frame.height) / 2
    }

    
    func setupDisplay(){
        //スクリーンの幅
        let screenWidth = UIScreen.main.bounds.size.width;
        //スクリーンの高さ
        let screenHeight = UIScreen.main.bounds.size.height;
        
        // プレビュー用のビューを生成
        imageView = UIImageView()
        
        var topPadding:CGFloat = 0
        //var bottomPadding:CGFloat = 0
        var leftPadding:CGFloat = 0
        var rightPadding:CGFloat = 0
        
        // iPhone X , X以外は0となる
        if #available(iOS 11.0, *) {
            let window = UIApplication.shared.windows.first { $0.isKeyWindow }
            topPadding = window!.safeAreaInsets.top
            leftPadding = window!.safeAreaInsets.left
            rightPadding = window!.safeAreaInsets.right
        }
        
        // portrait
        let safeAreaWidth = screenWidth - leftPadding - rightPadding
        //let safeAreaHeight = (screenHeight) - topPadding - bottomPadding
        
        // カメラ画像サイズはsessionPresetによって変わる
        // とりあえず16:9のportraitとして設定
        let rect = CGRect(x: leftPadding, y: topPadding,
                          width: safeAreaWidth, height: safeAreaWidth/9*16)
        
        // frame をCGRectで作った矩形に合わせる
        imageView.frame = rect
        imageView.center = CGPoint(x: screenWidth/2, y: screenHeight/2)
    }
    
    func setupCamera(){
        // AVCaptureSession: キャプチャに関する入力と出力の管理
        session = AVCaptureSession()
        
        // sessionPreset: キャプチャ・クオリティの設定
        session.sessionPreset = AVCaptureSession.Preset.high
        // session.sessionPreset = AVCaptureSessionPresetPhoto
        // session.sessionPreset = AVCaptureSessionPresetHigh
        // session.sessionPreset = AVCaptureSessionPresetMedium
        // session.sessionPreset = AVCaptureSessionPresetLow
        
        // 背面・前面カメラの選択
        camera = AVCaptureDevice.default(
            AVCaptureDevice.DeviceType.builtInWideAngleCamera,
            for: AVMediaType.video,
            position: .back) // position: .front
        
        // カメラからの入力データ
        do {
            input = try AVCaptureDeviceInput(device: camera) as AVCaptureDeviceInput
        } catch let error as NSError {
            print(error)
        }
        
        // 入力をセッションに追加
        if(session.canAddInput(input)) {
            session.addInput(input)
        }
        
        // AVCaptureStillImageOutput:静止画
        // AVCaptureMovieFileOutput:動画ファイル
        // AVCaptureAudioFileOutput:音声ファイル
        // AVCaptureVideoDataOutput:動画フレームデータ
        // AVCaptureAudioDataOutput:音声データ
        
        // AVCaptureVideoDataOutput:動画フレームデータを出力に設定
        output = AVCaptureVideoDataOutput()
        // 出力をセッションに追加
        if(session.canAddOutput(output)) {
            session.addOutput(output)
        }
        
        // ピクセルフォーマットを 32bit BGR + A とする
        output.videoSettings =
            [kCVPixelBufferPixelFormatTypeKey as AnyHashable as!
                String : Int(kCVPixelFormatType_32BGRA)]
        
        // フレームをキャプチャするためのサブスレッド用のシリアルキューを用意
        output.setSampleBufferDelegate(self, queue: DispatchQueue.main)
        
        output.alwaysDiscardsLateVideoFrames = true
        
        // ビデオ出力に接続
//        let connection  = output.connection(with: AVMediaType.video)
        
        session.startRunning()
        
        // deviceをロックして設定
        // swift 2.0
        do {
            try camera.lockForConfiguration()
            // フレームレート
            camera.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: 30)
            
            camera.unlockForConfiguration()
        } catch _ {
        }
    }
    
    // 新しいキャプチャの追加で呼ばれる
    func captureOutput(_ captureOutput: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        
        // キャプチャしたsampleBufferからUIImageを作成
        let image:UIImage = self.captureImage(sampleBuffer)
        
        // 画像を画面に表示
        DispatchQueue.main.async {
            self.imageView.image = image
            
            // UIImageViewをビューに追加
            self.view.addSubview(self.imageView)
        }
    }
    
    // sampleBufferからUIImageを作成
    func captureImage(_ sampleBuffer:CMSampleBuffer) -> UIImage{
        
        // Sampling Bufferから画像を取得
        let imageBuffer:CVImageBuffer =
            CMSampleBufferGetImageBuffer(sampleBuffer)!
        
        // pixel buffer のベースアドレスをロック
        CVPixelBufferLockBaseAddress(imageBuffer,
                                     CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        
        let baseAddress:UnsafeMutableRawPointer =
            CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0)!
        
        let bytesPerRow:Int = CVPixelBufferGetBytesPerRow(imageBuffer)
        let width:Int = CVPixelBufferGetWidth(imageBuffer)
        let height:Int = CVPixelBufferGetHeight(imageBuffer)
        
        
        // 色空間
        let colorSpace:CGColorSpace = CGColorSpaceCreateDeviceRGB()
        
        //let bitsPerCompornent:Int = 8
        // swift 2.0
        let newContext:CGContext = CGContext(data: baseAddress,
                                             width: width, height: height, bitsPerComponent: 8,
                                             bytesPerRow: bytesPerRow, space: colorSpace,
                                             bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue|CGBitmapInfo.byteOrder32Little.rawValue)!
        
        let imageRef:CGImage = newContext.makeImage()!
        let resultImage = UIImage(cgImage: imageRef,
                                  scale: 1.0, orientation: UIImage.Orientation.right)
        
        return resultImage
    }
    
    
}

