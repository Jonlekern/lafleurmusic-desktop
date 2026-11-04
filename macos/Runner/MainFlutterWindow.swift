import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    TrashChannel.register(with: flutterViewController.engine.binaryMessenger)

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
