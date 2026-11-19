import Cocoa
import CoreAudio
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    TrashChannel.register(with: flutterViewController.engine.binaryMessenger)
    AudioRouteChannel.register(with: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}

/// Canal « lafleur/trash » : met un fichier à la Corbeille (récupérable), jamais d'effacement définitif.
enum TrashChannel {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "lafleur/trash", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "trash", let path = call.arguments as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      do {
        try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
        result(nil)
      } catch {
        result(FlutterError(code: "trash", message: error.localizedDescription, details: path))
      }
    }
  }
}

/// Canal « lafleur/audio » : la sortie son par défaut est-elle un appareil virtuel (Jump Desktop…) ?
/// « isVirtual » répond tout de suite ; « changed » est envoyé à chaque changement de sortie par défaut.
enum AudioRouteChannel {
  static var channel: FlutterMethodChannel?

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "lafleur/audio", binaryMessenger: messenger)
    self.channel = channel
    channel.setMethodCallHandler { call, result in
      guard call.method == "isVirtual" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(defaultOutputIsVirtual())
    }
    var addr = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain)
    AudioObjectAddPropertyListenerBlock(
      AudioObjectID(kAudioObjectSystemObject), &addr, DispatchQueue.main
    ) { _, _ in
      AudioRouteChannel.channel?.invokeMethod("changed", arguments: defaultOutputIsVirtual())
    }
  }

  /// Vrai si la sortie par défaut est virtuelle, ou si on ne peut pas le savoir.
  static func defaultOutputIsVirtual() -> Bool {
    var device = AudioDeviceID(0)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    var addr = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain)
    guard AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &device) == noErr,
      device != 0
    else { return true }
    var transport = UInt32(0)
    size = UInt32(MemoryLayout<UInt32>.size)
    addr.mSelector = kAudioDevicePropertyTransportType
    guard AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &transport) == noErr
    else { return true }
    return transport == kAudioDeviceTransportTypeVirtual
  }
}
