//
//  AppDelegate.swift
//  Beiwe
//
//  Created by Keary Griffin on 3/10/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Sentry
import UIKit
import Fabric
import Crashlytics
import PromiseKit
import CoreMotion;
import ReachabilitySwift
import ResearchKit
import XCGLogger
import EmitterKit
import Foundation
import Firebase

let log = XCGLogger(identifier: "advancedLogger", includeDefaultDestinations: false)

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, CLLocationManagerDelegate {
    
    var window: UIWindow?
    var storyboard: UIStoryboard?;
    var modelVersionId = "";
    let motionManager = CMMotionManager();
    var reachability: Reachability?;
    var currentRootView: String? = "launchScreen";
    var isLoggedIn: Bool = false;
    var timeEnteredBackground: Date?;
    var canOpenTel = false;
    let debugEnabled  = _isDebugAssertConfiguration();
    let lockEvent = EmitterKit.Event<Bool>();
    let gcmMessageIDKey = "gcm.message_id"
    
    var locationPermission: Bool = false;
    // manager needed to ask for location permissions
    let locManager: CLLocationManager = CLLocationManager()
    
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        Fabric.with([Crashlytics.self])
        
        // Create a destination for the system console log (via NSLog)
        let systemLogDestination = AppleSystemLogDestination(owner: log, identifier: "advancedLogger.systemLogDestination")
        
        // Optionally set some configuration options
        systemLogDestination.outputLevel = debugEnabled ? .debug : .warning
        systemLogDestination.showLogIdentifier = false
        systemLogDestination.showFunctionName = false // true
        systemLogDestination.showThreadName = true
        systemLogDestination.showLevel = false // true
        systemLogDestination.showFileName = false // true
        systemLogDestination.showLineNumber = false // true
        systemLogDestination.showDate = true
        
        // Add the destination to the logger
        log.add(destination: systemLogDestination)
        
        let crashlyticsLogDestination = XCGCrashlyticsLogDestination(owner: log, identifier: "advancedlogger.crashlyticsDestination")
        crashlyticsLogDestination.outputLevel = .debug
        crashlyticsLogDestination.showLogIdentifier = false
        crashlyticsLogDestination.showFunctionName = false // true
        crashlyticsLogDestination.showThreadName = true
        crashlyticsLogDestination.showLevel = false // true
        crashlyticsLogDestination.showFileName = false // true
        crashlyticsLogDestination.showLineNumber = false // true
        crashlyticsLogDestination.showDate = true
        
        // Add the destination to the logger
        log.add(destination: crashlyticsLogDestination)
        
        
        log.info("applicationDidFinishLaunching")
        log.logAppDetails()
        
        AppEventManager.sharedInstance.didLaunch(launchOptions: launchOptions);
        
        do {
            reachability = try Reachability()
            try reachability!.startNotifier()
        } catch {
            log.error("Unable to create or start Reachability")
        }
        log.info("AppUUID: \(PersistentAppUUID.sharedInstance.uuid)");
        let uiDevice = UIDevice.current;
        modelVersionId = UIDevice.current.model + "/" + UIDevice.current.systemVersion;
        log.info("name: \(uiDevice.name)");
        log.info("systemName: \(uiDevice.systemName)");
        log.info("systemVersion: \(uiDevice.systemVersion)");
        log.info("model: \(uiDevice.model)");
        log.info("platform: \(platform())");
        
        canOpenTel = UIApplication.shared.canOpenURL(URL(string: "tel:6175551212")!);
        
        
        /* Colors */
        
        //let rkAppearance = UIView.my_appearanceWhenContained(in: ORKTaskViewController.self)
        let rkAppearance = UIView.appearance(whenContainedInInstancesOf: [ORKTaskViewController.self])
        rkAppearance.tintColor = AppColors.tintColor;
        //rkAppearance.backgroundColor = UIColor.clearColor() // AppColors.gradientBottom;
        
        /*
         let stepAppearance = UIView.my_appearanceWhenContainedIn(ORKStepViewController.self)
         stepAppearance.tintColor = AppColors.tintColor;
         stepAppearance.backgroundColor = UIColor.clearColor() // AppColors.gradientBottom;
         */
        
        /*
         UIView.appearanceWhenContainedInInstancesOfClasses([ORKTaskViewController.self]).tintColor = AppColors.tintColor
         */
        
        //UIView.appearance().tintColor = AppColors.tintColor;
        
        storyboard = UIStoryboard(name: "Main", bundle: Bundle.main);
        
        self.window = UIWindow(frame: UIScreen.main.bounds);
        self.window?.rootViewController = UIStoryboard(name: "LaunchScreen", bundle: Bundle.main).instantiateViewController(withIdentifier: "launchScreen");
        /* Gradient background so we can use "clear" RK views */
        /*
         let backView = GradientView(frame: UIScreen.mainScreen().bounds)
         backView.topColor = AppColors.gradientBottom
         backView.bottomColor = UIColor.whiteColor()
         self.window?.insertSubview(backView, atIndex: 0)
         */
        
        
        self.window!.makeKeyAndVisible()
        
        Recline.shared.open().then { _ -> Promise<Bool> in
            print("Database opened");
            return StudyManager.sharedInstance.loadDefaultStudy();
        }.done { _ -> Void in
            self.transitionToCurrentAppState();
        }.catch { err -> Void in
            print("Database open failed.");
        }
        //launchScreen
        /*
         //self.window!.backgroundColor = UIColor.whiteColor()
         
         self.window?.rootViewController = OnboardViewController();
         
         
         
         }
         */
        
        // initialize Sentry
        do {
            let dsn = Configuration.sharedInstance.settings["sentry-dsn"] as? String ?? "dev"
            if dsn == "release" {
                Client.shared = try Client(dsn: SentryKeys.release_dsn)
            }
            else if dsn == "dev" {
                Client.shared = try Client(dsn: SentryKeys.development_dsn)
            } else {
                throw "Invalid Sentry configuration"
            }
            try Client.shared?.startCrashHandler()
        } catch let error {
            print("\(error)")
        }
        
        // initialize Firebase
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        application.registerForRemoteNotifications()
        
        return true
    }
    
    func changeRootViewControllerWithIdentifier(_ identifier:String!) {
        if (identifier == currentRootView) {
            return;
        }
        let desiredViewController:UIViewController = (self.storyboard?.instantiateViewController(withIdentifier: identifier))!;
        
        changeRootViewController(desiredViewController, identifier: identifier);
    }
    
    func changeRootViewController(_ desiredViewController: UIViewController, identifier: String? = nil) {
        currentRootView = identifier;
        
        let snapshot:UIView = (self.window?.snapshotView(afterScreenUpdates: true))!
        desiredViewController.view.addSubview(snapshot);
        
        self.window?.rootViewController = desiredViewController;
        
        UIView.animate(withDuration: 0.3, animations: {() in
            snapshot.layer.opacity = 0;
            snapshot.layer.transform = CATransform3DMakeScale(1.5, 1.5, 1.5);
        }, completion: {
            (value: Bool) in
            snapshot.removeFromSuperview();
        });
    }
    
    func transitionToCurrentAppState() {
        
        
        if let currentStudy = StudyManager.sharedInstance.currentStudy {
            if (currentStudy.participantConsented) {
                StudyManager.sharedInstance.startStudyDataServices();
            }
            if (!isLoggedIn) {
                // Load up the log in view
                changeRootViewControllerWithIdentifier("login");
            } else {
                // We are logged in, so if we've completed onboarding load main interface
                // Otherwise continue onboarding.
                if (currentStudy.participantConsented) {
                    changeRootViewControllerWithIdentifier("mainView");
                } else {
                    changeRootViewController(ConsentManager().consentViewController);
                }
                
            }
            
        } else {
            // If there is no study loaded, then it's obvious.  We need the onboarding flow
            // from the beginning.
            changeRootViewController(OnboardingManager().onboardingViewController);
        }
    }
    
    static func sharedInstance() -> AppDelegate{
        return UIApplication.shared.delegate as! AppDelegate
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
        log.info("applicationWillResignActive")
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        log.info("applicationDidEnterBackground")
        timeEnteredBackground = Date();
        AppEventManager.sharedInstance.logAppEvent(event: "background", msg: "Application entered background")
        
    }
    
    func checkPasswordAndLogin(_ password: String) -> Bool {
        if let storedPassword = PersistentPasswordManager.sharedInstance.passwordForStudy(), storedPassword.count > 0 {
            if (password == storedPassword) {
                ApiManager.sharedInstance.password = storedPassword;
                isLoggedIn = true;
                return true;
            }
            
        }
        
        return false;
        
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        log.info("applicationWillEnterForeground")
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
        print("ApplicationWillEnterForeground");
        if let timeEnteredBackground = timeEnteredBackground, let currentStudy = StudyManager.sharedInstance.currentStudy, let studySettings = currentStudy.studySettings, isLoggedIn == true {
            let loginExpires = timeEnteredBackground.addingTimeInterval(Double(studySettings.secondsBeforeAutoLogout));
            if (loginExpires.compare(Date()) == ComparisonResult.orderedAscending) {
                // expired.  Log 'em out
                isLoggedIn = false;
                transitionToCurrentAppState();
            }
        } else {
            isLoggedIn = false;
        }
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        log.info("applicationDidBecomeActive")
        AppEventManager.sharedInstance.logAppEvent(event: "foreground", msg: "Application entered foreground")
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        log.info("applicationWillTerminate")
        AppEventManager.sharedInstance.logAppEvent(event: "terminate", msg: "Application terminating")
        
        let dispatchGroup = DispatchGroup();
        
        dispatchGroup.enter()
        StudyManager.sharedInstance.stop().done(on: DispatchQueue.global(qos: .default)) { _ in
            dispatchGroup.leave()
        }.catch(on: DispatchQueue.global(qos: .default)) {_ in
            dispatchGroup.leave()
        }
        
        dispatchGroup.wait();
        log.info("applicationWillTerminate exiting")
    }
    
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        log.info("applicationDidReceiveMemoryWarning")
        AppEventManager.sharedInstance.logAppEvent(event: "memory_warn", msg: "Application received memory warning")
    }
    
    func displayCurrentMainView() {
        //
        
        var view: String;
        if let _ = StudyManager.sharedInstance.currentStudy {
            view = "initialStudyView";
        } else {
            view = "registerView";
        }
        self.window = UIWindow(frame: UIScreen.main.bounds)
        
        self.window?.rootViewController = storyboard!.instantiateViewController(withIdentifier: view) as UIViewController?;
        
        self.window!.makeKeyAndVisible()
        
    }
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        log.info("applicationWillFinishLaunchingWithOptions")
        return true;
        
    }
    
    func applicationProtectedDataDidBecomeAvailable(_ application: UIApplication) {
        log.info("applicationProtectedDataDidBecomeAvailable");
        lockEvent.emit(false);
        AppEventManager.sharedInstance.logAppEvent(event: "unlocked", msg: "Phone/keystore unlocked")
    }
    
    func applicationProtectedDataWillBecomeUnavailable(_ application: UIApplication) {
        log.info("applicationProtectedDataWillBecomeUnavailable");
        lockEvent.emit(true);
        AppEventManager.sharedInstance.logAppEvent(event: "locked", msg: "Phone/keystore locked")
        
    }
    /* Crashlytics functions -- future */
    
    func setDebuggingUser(_ username: String) {
        // TODO: Use the current user's information
        // You can call any combination of these three methods
        //Crashlytics.sharedInstance().setUserEmail("user@fabric.io")
        Crashlytics.sharedInstance().setUserIdentifier(username);
        //Crashlytics.sharedInstance().setUserName("Test User")
    }
    
    func crash() {
        Crashlytics.sharedInstance().crash()
    }
    
    // this function gets called when CLAuthorization status changes
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            // If status has not yet been determied, ask for authorization
            manager.requestAlwaysAuthorization()
            break
        case .authorizedWhenInUse:
            // If authorized when in use
            locationPermission = false
            break
        case .authorizedAlways:
            // If always authorized
            locationPermission = true
            break
        case .restricted:
            // If restricted by e.g. parental controls. User can't enable Location Services
            locationPermission = false
            break
        case .denied:
            // If user denied your app access to Location Services, but can grant access from Settings.app
            locationPermission = false
            break
        default:
            break
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for notifications: \(error.localizedDescription)")
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
        // If you are receiving a notification message while your app is in the background,
        // this callback will not be fired till the user taps on the notification launching the application.
        // TODO: Handle data of notification
        
        print("Tuck: recieved notification 1")
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        
        // Print full message.
        print(userInfo)
    }
    
    // called when recieving notification while app is in foreground
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // If you are receiving a notification message while your app is in the background,
        // this callback will not be fired till the user taps on the notification launching the application.
        // TODO: Handle data of notification
        
        print("Tuck: recieved notification 2")
        log.info("Push notification recieved")
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        
        // Print full message.
        print(userInfo)
        if let survey_ids = userInfo["survey_ids"] {
            let surveyIds = survey_ids as! [String]
            for surveyId in surveyIds {
                if !(StudyManager.sharedInstance.currentStudy?.surveyExists(surveyId: surveyId) ?? false) {
                    log.info("Recieved notification for new survey \(surveyId)")
                } else {
                    log.info("Recieved notification for survey \(surveyId)")
                }
            }
            downloadSurveys()
            setAvailableSurveys(surveyIds: surveyIds)
        }
        
        completionHandler(UIBackgroundFetchResult.newData)
    }
    
    func sendFCMToken(fcmToken: String) {
        let fcmTokenRequest = FCMTokenRequest(fcmToken: fcmToken)
        ApiManager.sharedInstance.makePostRequest(fcmTokenRequest).catch {
            (error) in
            log.error("Error registering FCM token: \(error)")
        }
    }
    
    // downloads all of the surveys in the study
    func downloadSurveys() {
        let getSingleSurveyRequest = GetSurveysRequest()
        log.info("Requesting surveys")
        ApiManager.sharedInstance.arrayPostRequest(getSingleSurveyRequest).done {
            (surveys, _) in
            StudyManager.sharedInstance.currentStudy?.pushSurveys = surveys
            // set badge number
        } .catch {
            (error) in
            log.error("Error downloading surveys: \(error)")
        }
    }
    
    func setAvailableSurveys(surveyIds: [String]) {
        for surveyId in surveyIds {
            if let survey = StudyManager.sharedInstance.currentStudy?.getSurvey(surveyId: surveyId) {
                StudyManager.sharedInstance.currentStudy?.availableSurveys[surveyId] = survey
            }
        }
        // set badge number
        UIApplication.shared.applicationIconBadgeNumber = StudyManager.sharedInstance.currentStudy?.availableSurveys.count as! Int
    }
    
}

extension String: LocalizedError {
    public var errorDescription: String? { return self }
}

// [START ios_10_message_handling]
@available(iOS 10, *)
extension AppDelegate : UNUserNotificationCenterDelegate {
    
    // Receive displayed notifications for iOS 10 devices.
    // Is called when recieving a notifcation while app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        print("Tuck: recieved notificaiton 3: \(notification.request.content)")
        
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        
        // Print full message.
        print(userInfo)
        
        // Change this to your preferred presentation option
        completionHandler([])
    }
    
    // Is caleld when tapping on notification when app is in background
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("Tuck: recieved notificaiton 4: \(response.notification.request.content)")
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        
        // Print full message.
        print(userInfo)
        
        completionHandler()
    }
}
// [END ios_10_message_handling]

extension AppDelegate : MessagingDelegate {
    // [START refresh_token]
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String) {
        print("Tuck: Firebase registration token: \(fcmToken)")
        
        let dataDict:[String: String] = ["token": fcmToken]
        NotificationCenter.default.post(name: Notification.Name("FCMToken"), object: nil, userInfo: dataDict)
        // Note: This callback is fired at each app startup and whenever a new token is generated.
        
        // TODO: thread this sleep statement
        // wait until user is registered to send FCM token
        //    while ApiManager.sharedInstance.patientId == "" {
        //        sleep(1)
        //        print("sleep")
        //    }
        sendFCMToken(fcmToken: fcmToken)
    }
    // [END refresh_token]
    // [START ios_10_data_message]
    // Receive data messages on iOS 10+ directly from FCM (bypassing APNs) when the app is in the foreground.
    // To enable direct data messages, you can set Messaging.messaging().shouldEstablishDirectChannel to true.
    func messaging(_ messaging: Messaging, didReceive remoteMessage: MessagingRemoteMessage) {
        print("Received data message: \(remoteMessage.appData)")
    }
    // [END ios_10_data_message]
}


