import UIKit
import Flutter
import AuthenticationServices
import SafariServices
import Firebase
import FirebaseMessaging
import FirebaseAuth
import FirebaseFirestore
import WidgetKit

@available(iOS 13.0, *)
@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    
    var viewController: FlutterViewController?
    var uriEvent: UriEventChannelHandler?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FirebaseApp.configure()
        do {
            try Auth.auth().useUserAccessGroup("B66Z929S96.net.chikach.submon")
        } catch let error as NSError {
            print(error)
        }
        
        viewController = window?.rootViewController as? FlutterViewController
        
        MainMethodChannelHandler(viewController: viewController!).register()
        MessagingMethodChannelHandler(viewController: viewController!, appDelegate: self).register()
        
        uriEvent = UriEventChannelHandler(binaryMessenger: viewController!.binaryMessenger)
        
        initNotificationCategories()
        
        Messaging.messaging().delegate = self
        application.registerForRemoteNotifications()
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        uriEvent?.eventSink?(url.absoluteString)
        return true
    }
    
    override func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.badge, .sound, .alert])
    }
    
    override func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // TODO: Separate on notification action tapped from on notification content tapped
        let userInfo = response.notification.request.content.userInfo
        print(userInfo)
        print("Action identifier: \(response.actionIdentifier)")
        
        switch response.notification.request.content.categoryIdentifier {
        case "reminder":
            if response.actionIdentifier == "openCreateNewPage" {
                openUrl(url: "submon:///create-submission")
            }
            break;
            
        case "digestive":
            if response.actionIdentifier == "openFocusTimer" {
                openUrl(url: "submon:///focus-timer?digestiveId=\(userInfo["digestiveId"])")
            } else {
                if (userInfo["submissionId"] as? String? != "-1") {
                    openUrl(url: "submon:///submission?id=\(userInfo["submissionId"])")
                } else {
                    openUrl(url: "submon:///tab/digestive")
                }
            }
            
        case "timetable":
            openUrl(url: "submon:///tab/timetable")
            
        default: break
        }
        completionHandler()
    }
    
    private func openUrl(url: String) {
        UIApplication.shared.open(URL(string: url)!, options: [:], completionHandler: nil)
    }
    
    func initNotificationCategories() {
        let notificationCenter = UNUserNotificationCenter.current()
        
        notificationCenter.setNotificationCategories([
            UNNotificationCategory(identifier: "reminder", actions: [
                UNNotificationAction(identifier: "openCreateNewPage", title: "新規作成", options: [.foreground])
            ], intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: "timetable", actions: [], intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: "digestive", actions: [
                UNNotificationAction(identifier: "openFocusTimerPage", title: "集中タイマー", options: [.foreground]),
            ], intentIdentifiers: [], options: [])
        ])
        
        notificationCenter.getNotificationSettings(completionHandler: { (settings) in
            if (settings.authorizationStatus == .authorized) {
                notificationCenter.delegate = self
            }
        })
    }
}

extension AppDelegate : MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        NotificationCenter.default.post(name: Notification.Name("FCMToken"), object: nil, userInfo: ["token": fcmToken ?? ""])
        
        if fcmToken != nil, let user = Auth.auth().currentUser {
//            Firestore.firestore().document("users/\(user.uid)").setData(["notificationTokens": FieldValue.arrayUnion([fcmToken!])], merge: true)
        }
    }
}
