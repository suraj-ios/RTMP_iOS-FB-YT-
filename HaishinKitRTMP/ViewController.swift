//
//  ViewController.swift
//  HaishinKitRTMP
//
//  Created by Suraj Singh on 23/08/21.
//

import UIKit
import HaishinKit
import Photos
import UIKit
import VideoToolbox

class ViewController: UIViewController {

    @IBOutlet private weak var lfView: MTHKView!
    @IBOutlet private weak var liveIconView: UIImageView!
    private var rtmpConnection = RTMPConnection()
    private var rtmpStream: RTMPStream!
    private var rtmpStreamLayer: RTMPStream!
    private var sharedObject: RTMPSharedObject!
    private var currentPosition: AVCaptureDevice.Position = .back
    private var retryCount: Int = 0
    
    var serverUrl_FaceBook = "rtmps://live-api-s.facebook.com:443/rtmp/"
    var streamKey_FaceBook = "FB-284036693528071-0-AbysY99Gb__eSSuJ"
    
    var serverUrl_YouTube = "rtmp://a.rtmp.youtube.com/live2"
    var streamKey_YouTube = "tefr-g2jx-g82f-v3cz-fe54"
    
    var serverUrl:String = ""
    var streamKey:String = ""
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        self.serverUrl = self.serverUrl_YouTube
        self.streamKey = self.streamKey_YouTube
        
        
        rtmpStream = RTMPStream(connection: rtmpConnection)
        rtmpStreamLayer = RTMPStream(connection: rtmpConnection)
        
        if let orientation = DeviceUtil.videoOrientation(by: UIApplication.shared.statusBarOrientation) {
            rtmpStream.orientation = orientation
        }
        
        rtmpStream.captureSettings = [
            .sessionPreset: AVCaptureSession.Preset.hd1280x720,
            .continuousAutofocus: true,
            .continuousExposure: true
            // .preferredVideoStabilizationMode: AVCaptureVideoStabilizationMode.auto
        ]
        
        rtmpStream.videoSettings = [
            .width: 720,
            .height: 1280
        ]
        
        rtmpStreamLayer.captureSettings = [
            .sessionPreset: AVCaptureSession.Preset.hd1280x720,
            .continuousAutofocus: true,
            .continuousExposure: true
            // .preferredVideoStabilizationMode: AVCaptureVideoStabilizationMode.auto
        ]
        
        rtmpStreamLayer.videoSettings = [
            .width: 720,
            .height: 1280
        ]
        
        //rtmpStream.mixer.recorder.delegate = ExampleRecorderDelegate.shared
        
        NotificationCenter.default.addObserver(self, selector: #selector(on(_:)), name: UIDevice.orientationDidChangeNotification, object: nil)
        
    }
    
    @objc
    private func on(_ notification: Notification) {
        guard let orientation = DeviceUtil.videoOrientation(by: UIApplication.shared.statusBarOrientation) else {
            return
        }
        rtmpStream.orientation = orientation
    }
    
    override func viewWillAppear(_ animated: Bool) {
        logger.info("viewWillAppear")
        super.viewWillAppear(animated)
        
        self.NotScreenCaptureSession()
        self.screenCaptureSessionFunc()
        
    }
    
    func NotScreenCaptureSession(){
        self.rtmpStream.attachAudio(AVCaptureDevice.default(for: .audio)) { error in
            logger.warn(error.description)
        }
        self.rtmpStream.attachScreen(ScreenCaptureSession(viewToCapture: self.view))
        self.rtmpStream.attachCamera(DeviceUtil.device(withPosition: self.currentPosition)) { error in
            logger.warn(error.description)
        }
        
        self.rtmpStream.addObserver(self, forKeyPath: "currentFPS", options: .new, context: nil)
        
        lfView?.attachStream(self.rtmpStream)
    }
    
    func screenCaptureSessionFunc(){
        
        self.rtmpStreamLayer.attachAudio(AVCaptureDevice.default(for: .audio)) { error in
            logger.warn(error.description)
        }
                
        self.rtmpStreamLayer.attachScreen(ScreenCaptureSession(viewToCapture: self.view))
                
        self.rtmpStreamLayer.attachCamera(DeviceUtil.device(withPosition: self.currentPosition)) { error in
            logger.warn(error.description)
        }
        
        self.rtmpStreamLayer.attachScreen(ScreenCaptureSession(shared: UIApplication.shared)) //viewToCapture: view
        self.rtmpStreamLayer.receiveAudio = true
        
        self.rtmpStreamLayer.addObserver(self, forKeyPath: "currentFPS", options: .new, context: nil)
        
        lfView?.attachStream(self.rtmpStreamLayer)
        
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        logger.info("viewWillDisappear")
        super.viewWillDisappear(animated)
        rtmpStream.removeObserver(self, forKeyPath: "currentFPS")
        rtmpStream.close()
        rtmpStream.dispose()
    }

    @IBAction func on(publish: UIButton) {
        
        if publish.isSelected {
            UIApplication.shared.isIdleTimerDisabled = false
            rtmpConnection.close()
            rtmpConnection.removeEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
        //publish.setTitle("●", for: [])
        } else {
            UIApplication.shared.isIdleTimerDisabled = true
            rtmpConnection.addEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
            rtmpConnection.connect(self.serverUrl)
            //publish.setTitle("■", for: [])
        }
        publish.isSelected.toggle()
    }
    
    @objc
        private func rtmpStatusHandler(_ notification: Notification) {
        let e = Event.from(notification)
        guard let data: ASObject = e.data as? ASObject, let code: String = data["code"] as? String else {
            return
        }
        //logger.info(code)
        switch code {
        case RTMPConnection.Code.connectSuccess.rawValue:
            retryCount = 0
            //rtmpStream!.publish(self.streamKey)
            
            DispatchQueue.main.asyncAfter(deadline: .now()){
                //self.rtmpStream!.publish(self.streamKey)
                self.rtmpStreamLayer!.publish(self.streamKey)
            }
            
            // sharedObject!.connect(rtmpConnection)
        case RTMPConnection.Code.connectFailed.rawValue, RTMPConnection.Code.connectClosed.rawValue:
            rtmpConnection.connect(self.serverUrl_FaceBook)
            retryCount += 1
        default:
            break
        }
    }
    
    @objc private func rtmpErrorHandler(_ notification: Notification) {
        logger.error(notification)
        rtmpConnection.connect(self.serverUrl)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if Thread.isMainThread {
            print("\(rtmpStream.currentFPS)")
        }
    }
    
}
