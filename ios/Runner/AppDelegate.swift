import AuthenticationServices
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Lesson reminders: without a delegate iOS neither shows a reminder while
    // the app is open nor reports a tap on one back to Dart.
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "WebAuthPlugin") {
      WebAuthPlugin.register(with: registrar)
    }
  }
}


/// Google sign-in for Docs sync: the system sign-in sheet
/// (`ASWebAuthenticationSession`), which shares Safari's cookies so a student
/// already signed in to Google only picks the account. Dart side:
/// `lib/sync/web_authenticator.dart`.
final class WebAuthPlugin: NSObject, FlutterPlugin, ASWebAuthenticationPresentationContextProviding {
  private var session: ASWebAuthenticationSession?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "recorder/web_auth", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(WebAuthPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "bundleId":
      result(Bundle.main.bundleIdentifier)
    case "authenticate":
      authenticate(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func authenticate(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
      let link = args["url"] as? String,
      let url = URL(string: link),
      let scheme = args["callbackScheme"] as? String
    else {
      result(FlutterError(code: "BAD_ARGS", message: "url and callbackScheme are required", details: nil))
      return
    }
    if session != nil {
      result(FlutterError(code: "BUSY", message: "A sign-in is already open", details: nil))
      return
    }
    let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) {
      [weak self] callback, error in
      DispatchQueue.main.async {
        self?.session = nil
        if let callback = callback {
          result(callback.absoluteString)
        } else if let error = error as? ASWebAuthenticationSessionError,
          error.code == .canceledLogin
        {
          result(FlutterError(code: "CANCELED", message: "Sign-in was cancelled", details: nil))
        } else {
          result(
            FlutterError(
              code: "FAILED", message: error?.localizedDescription ?? "Sign-in failed", details: nil))
        }
      }
    }
    session.presentationContextProvider = self
    // Keep Safari's Google cookies: signing in again is one tap, not a password.
    session.prefersEphemeralWebBrowserSession = false
    self.session = session
    if !session.start() {
      self.session = nil
      result(FlutterError(code: "FAILED", message: "The sign-in sheet did not open", details: nil))
    }
  }

  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
    return windows.first(where: { $0.isKeyWindow }) ?? windows.first ?? ASPresentationAnchor()
  }
}
