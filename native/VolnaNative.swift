
// ---------- Волна: native part (appended to AppDelegate.swift by native/patch-ios.sh) ----------
// 1. Audio session "playback": music keeps playing with the screen locked or the app in the background.
// 2. System volume: the page can read it, follow the hardware buttons and change it with its own slider.
// (AVFoundation and MediaPlayer are imported at the top of the file by the patch script.)

@objc(VolnaNativePlugin)
public class VolnaNativePlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "VolnaNativePlugin"
    public let jsName = "VolnaNative"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "getVolume", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setVolume", returnType: CAPPluginReturnPromise)
    ]

    private var volumeObserver: NSKeyValueObservation?
    private var volumeView: MPVolumeView?

    public override func load() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true)

        // hardware buttons and Control Centre change outputVolume: tell the page
        volumeObserver = session.observe(\.outputVolume, options: [.new]) { [weak self] _, change in
            guard let v = change.newValue else { return }
            self?.notifyListeners("volume", data: ["value": Double(v)])
        }

        // the only public way to set the system volume is the slider inside MPVolumeView;
        // keeping one (invisible) on screen also replaces the system volume pop-up with the app's own
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let host = self.bridge?.viewController?.view else { return }
            let v = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 10, height: 10))
            v.alpha = 0.01
            v.isUserInteractionEnabled = false
            host.addSubview(v)
            self.volumeView = v
        }

        // after a phone call or Siri, make the session active again
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .ended else { return }
            try? AVAudioSession.sharedInstance().setActive(true)
        }
    }

    @objc func getVolume(_ call: CAPPluginCall) {
        call.resolve(["value": Double(AVAudioSession.sharedInstance().outputVolume)])
    }

    @objc func setVolume(_ call: CAPPluginCall) {
        let value = Float(max(0, min(1, call.getDouble("value") ?? 0.5)))
        DispatchQueue.main.async { [weak self] in
            guard let slider = self?.volumeView?.subviews.compactMap({ $0 as? UISlider }).first else {
                call.reject("volume control not ready"); return
            }
            slider.setValue(value, animated: false)
            slider.sendActions(for: .valueChanged)
            call.resolve(["value": Double(value)])
        }
    }
}

// the app's screen: the standard Capacitor one plus the plugin above
class VolnaViewController: CAPBridgeViewController {
    override open func capacitorDidLoad() {
        bridge?.registerPluginInstance(VolnaNativePlugin())
    }
}
