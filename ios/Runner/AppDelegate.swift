import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Key is defined in ios/Secrets.xcconfig (git-ignored) → Info.plist MapsApiKey.
    // Never hardcode the real key here.
    let mapsApiKey = Bundle.main.object(forInfoDictionaryKey: "MapsApiKey") as? String ?? ""
    GMSServices.provideAPIKey(mapsApiKey)

    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    // Pre-warm the Maps Metal renderer so the first trip map tab opens without
    // a multi-second main-thread stall.
    //
    // Why asyncAfter: creating GMSMapView blocks the main thread while Metal
    // shaders compile. Doing it inline here would hit the iOS Watchdog (5-second
    // launch limit).  1.5 s defers it to the login screen where a brief freeze
    // is least disruptive; by the time the user opens a trip the SDK is warm.
    //
    // Why NOT sendSubviewToBack: CoreAnimation skips rendering occluded views,
    // so Metal shaders would never compile. The 1×1 view stays on TOP of the
    // Flutter layer (visible to the compositor) so a real draw call is issued.
    // One logical pixel in the corner is imperceptible to users.
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
      guard let window = self?.window else { return }
      let warmup = GMSMapView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
      window.addSubview(warmup)

      // Add a marker and a polyline so their Metal shader pipelines compile now
      // rather than on the user's first real map open.  A blank map only compiles
      // tile shaders; marker and polyline shaders are separate PSOs that fire on
      // first draw of those element types.
      let marker = GMSMarker()
      marker.position = CLLocationCoordinate2D(latitude: 0, longitude: 0)
      marker.map = warmup

      let path = GMSMutablePath()
      path.add(CLLocationCoordinate2D(latitude: -0.001, longitude: -0.001))
      path.add(CLLocationCoordinate2D(latitude:  0.001, longitude:  0.001))
      let polyline = GMSPolyline(path: path)
      polyline.strokeWidth = 4
      polyline.map = warmup

      DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
        warmup.removeFromSuperview()
      }
    }

    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
