//
//  OnboardingManager.swift
//  Beiwe
//
//  Created by Keary Griffin on 4/4/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import ResearchKit
import UserNotifications


enum StepIds : String {
    case Permission = "PermissionsStep"
    case WaitForPermissions = "WaitForPermissions"
    case WarningStep = "WarningStep"
    case VisualConsent = "VisualConsentStep"
    case ConsentReview = "ConsentReviewStep"
}

class WaitForPermissionsRule : ORKStepNavigationRule {
    let nextTask: ((ORKTaskResult) -> String)
    init(nextTask: @escaping ((_ taskResult: ORKTaskResult) -> String)) {
        self.nextTask = nextTask

        super.init(coder: NSCoder())
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func identifierForDestinationStep(with taskResult: ORKTaskResult)  -> String {
        return self.nextTask(taskResult)
    }
}

class ConsentManager : NSObject, ORKTaskViewControllerDelegate {


    var retainSelf: AnyObject?;
    var consentViewController: ORKTaskViewController!;
    var consentDocument: ORKConsentDocument!;
    var permissionsGranted: Bool = false;

    var PermissionsStep: ORKStep {
        let instructionStep = ORKInstructionStep(identifier: StepIds.Permission.rawValue)
        instructionStep.title = NSLocalizedString("permission_alert_title", comment: "")
        instructionStep.text = NSLocalizedString("permission_location_and_notification_message_long", comment: "")
        return instructionStep;
    }

    var WarningStep: ORKStep {
        let instructionStep = ORKInstructionStep(identifier: StepIds.WarningStep.rawValue)
        instructionStep.title = NSLocalizedString("permission_warning_alert_title", comment: "")
        instructionStep.text = NSLocalizedString("permission_warning_alert_text", comment: "")
        return instructionStep;
    }



    override init() {
        super.init();

        // Set up permissions

        var steps = [ORKStep]();


        if (!hasRequiredPermissions()) {
            steps += [PermissionsStep];
            steps += [ORKWaitStep(identifier: StepIds.WaitForPermissions.rawValue)];
            steps += [WarningStep];
        }

        consentDocument = ORKConsentDocument()
        consentDocument.title = NSLocalizedString("consent_document_title", comment: "")

        let studyConsentSections = StudyManager.sharedInstance.currentStudy?.studySettings?.consentSections ?? [:];


        let overviewSection = ORKConsentSection(type: .overview);
        if let welcomeStudySection = studyConsentSections["welcome"], !welcomeStudySection.text.isEmpty {
            overviewSection.summary = welcomeStudySection.text
            if (!welcomeStudySection.more.isEmpty) {
                overviewSection.content = welcomeStudySection.more
            }
        } else {
            overviewSection.summary = NSLocalizedString("study_welcome_message", comment: "")
        }

        let consentSectionTypes: [(ORKConsentSectionType, String)] = [
            (.dataGathering, "data_gathering"),
            (.privacy, "privacy"),
            (.dataUse, "data_use"),
            (.timeCommitment, "time_commitment"),
            (.studySurvey, "study_survey"),
            (.studyTasks, "study_tasks"),
            (.withdrawing, "withdrawing")
        ]


        var hasAdditionalConsent = false;
        var consentSections: [ORKConsentSection] = [overviewSection];
        for (contentSectionType, bwType) in consentSectionTypes {
            if let bwSection = studyConsentSections[bwType], !bwSection.text.isEmpty {
                hasAdditionalConsent = true;
                let consentSection = ORKConsentSection(type: contentSectionType)
                consentSection.summary = bwSection.text
                if (!bwSection.more.isEmpty) {
                    consentSection.content = bwSection.more
                }
                consentSections.append(consentSection);
            }
        }

        consentDocument.addSignature(ORKConsentSignature(forPersonWithTitle: nil, dateFormatString: nil, identifier: "ConsentDocumentParticipantSignature"))

        consentDocument.sections = consentSections        //TODO: signature
        
        let visualConsentStep = ORKVisualConsentStep(identifier: StepIds.VisualConsent.rawValue, document: consentDocument)
        steps += [visualConsentStep]

        //let signature = consentDocument.signatures!.first!

        if (hasAdditionalConsent) {
            let reviewConsentStep = ORKConsentReviewStep(identifier: StepIds.ConsentReview.rawValue, signature: nil, in: consentDocument)

            reviewConsentStep.text = NSLocalizedString("review_consent_text", comment: "")
            reviewConsentStep.reasonForConsent = NSLocalizedString("review_consent_reason", comment: "")

            steps += [reviewConsentStep]
        }

        let task = ORKNavigableOrderedTask(identifier: "ConsentTask", steps: steps)
        //let waitForPermissionRule = WaitForPermissionsRule(coder: NSCoder())
        //task.setNavigationRule(waitForPermissionRule!, forTriggerStepIdentifier: StepIds.WaitForPermissions.rawValue)
        task.setNavigationRule(WaitForPermissionsRule() { [weak self] taskResult -> String in
            if (self?.permissionsGranted == true) {
                print("Yeah, permissions are granted!")
                return StepIds.VisualConsent.rawValue
            } else {
                print("No, permissions are NOT granted.")
                return StepIds.WarningStep.rawValue
            }

            }, forTriggerStepIdentifier: StepIds.WaitForPermissions.rawValue)
        consentViewController = ORKTaskViewController(task: task, taskRun: nil);
        consentViewController.showsProgressInNavigationBar = false;
        consentViewController.delegate = self;
        retainSelf = self;
    }

    func closeOnboarding() {
        AppDelegate.sharedInstance().transitionToCurrentAppState();
        retainSelf = nil;
    }

    func hasRequiredPermissions() -> Bool {
//        return self.permissionsGranted  // TODO: previously used (pscope.statusNotifications() == .authorized && pscope.statusLocationAlways() == .authorized)
        return false;  // TODO: fix this
    }

    /* ORK Delegates */

    func taskViewController(_ taskViewController: ORKTaskViewController, didFinishWith reason: ORKTaskViewControllerFinishReason, error: Error?) {
        //Handle results with taskViewController.result
        //taskViewController.dismissViewControllerAnimated(true, completion: nil)
        if (reason == ORKTaskViewControllerFinishReason.discarded) {
            StudyManager.sharedInstance.leaveStudy().then { _ -> Void in
                self.closeOnboarding();
            }
        } else {
            StudyManager.sharedInstance.setConsented().then { _ -> Void in
                self.closeOnboarding();
            }
        }
    }

    func taskViewController(_ taskViewController: ORKTaskViewController, didChange result: ORKTaskResult) {

        return;
    }

    func taskViewController(_ taskViewController: ORKTaskViewController, shouldPresent step: ORKStep) -> Bool {
        /*
        if let identifier = StepIds(rawValue: step.identifier) {
            switch(identifier) {
            case .WarningStep:
                if (pscope.statusLocationAlways() == .Authorized) {
                    taskViewController.goForward();
                    return false;
                }
            default: break
            }
        }
        */
        return true;

    }

    func taskViewController(_ taskViewController: ORKTaskViewController, learnMoreForStep stepViewController: ORKStepViewController) {
        // Present modal...
        let refreshAlert = UIAlertController(title: "Learning more!", message: "You're smart now", preferredStyle: UIAlertControllerStyle.alert)

        refreshAlert.addAction(UIAlertAction(title: NSLocalizedString("ok_button_text", comment: ""), style: .default, handler: { (action: UIAlertAction!) in
        }))


        consentViewController.present(refreshAlert, animated: true, completion: nil)
    }

    func taskViewController(_ taskViewController: ORKTaskViewController, hasLearnMoreFor step: ORKStep) -> Bool {
        return false;
    }

    func taskViewController(_ taskViewController: ORKTaskViewController, viewControllerFor step: ORKStep) -> ORKStepViewController? {
        return nil;
    }

    func taskViewController(_ taskViewController: ORKTaskViewController, stepViewControllerWillAppear stepViewController: ORKStepViewController) {
        stepViewController.cancelButtonItem!.title = NSLocalizedString("unregister_alert_title", comment: "")

        if let identifier = StepIds(rawValue: stepViewController.step?.identifier ?? "") {
            switch(identifier) {
            case .WaitForPermissions:
                print("Here we are in the .WaitForPermission step");

                let center = UNUserNotificationCenter.current()
                center.requestAuthorization(options: [.sound, .alert, .badge]) { (granted, error) in  // TODO: .sound may be unnecessary
                    if error == nil {
                        print("Did not error during the permissions request");
                        center.getNotificationSettings { settings in
                            if settings.authorizationStatus == .authorized {
                                print("Yeah, seem to be authorized.");
                                self.permissionsGranted = true
                                stepViewController.goForward();
                            } else {
                                print("Seems to have been declined.");
                                self.permissionsGranted = false
                                stepViewController.goForward();
                            }
                        }
                    }
                    else {
                        print("Error during the permissions request");
                    }
                }
            case .Permission:
                print("Here we are in the .Permission step");
                stepViewController.continueButtonTitle = NSLocalizedString("continue_to_permissions_button_title", comment: "");
            case .WarningStep:
                log.info("Here we are in the .WarningStep");
                // TODO: make the 4 lines below work
//                if self.permissionsGranted == true {  // TODO: previously, this used if (pscope.statusLocationAlways() == .authorized)
//                    stepViewController.goForward();
//                } else {
//                    stepViewController.continueButtonTitle = NSLocalizedString("continue_button_title", comment: "");
//                }
            case .VisualConsent:
                print("Here we are in the .VisualConsent step");
                if (hasRequiredPermissions()) {
                    stepViewController.backButtonItem = nil;
                }
            default: break;
            }
        }

        //stepViewController.continueButtonTitle = "Go!"
    }
}
