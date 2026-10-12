import Flutter
import UIKit
import GoogleMaps
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var rideAlertPlayer: AVAudioPlayer?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
      
    if let apiKey = Bundle.main.object(forInfoDictionaryKey: "IosMapsApiKey") as? String {
        GMSServices.provideAPIKey(apiKey)
    }

    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "moto/notification_channel",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        if call.method == "stopRideAlertSound" {
          self?.rideAlertPlayer?.stop()
          self?.rideAlertPlayer = nil
          result(true)
          return
        }
        guard call.method == "playRideAlertSound" else {
          result(FlutterMethodNotImplemented)
          return
        }
        do {
          guard let url = Bundle.main.url(
            forResource: "moto_notification",
            withExtension: "wav"
          ) else {
            result(false)
            return
          }
          self?.rideAlertPlayer = try AVAudioPlayer(contentsOf: url)
          self?.rideAlertPlayer?.prepareToPlay()
          self?.rideAlertPlayer?.play()
          result(true)
        } catch {
          result(FlutterError(code: "sound_failed", message: nil, details: nil))
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
