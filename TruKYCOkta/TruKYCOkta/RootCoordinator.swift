/*
* Copyright (c) 2022-Present, Okta, Inc. and/or its affiliates. All rights reserved.
* The Okta software accompanied by this notice is provided pursuant to the Apache License, Version 2.0 (the "License.")
*
* You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0.
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
* WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
*
* See the License for the specific language governing permissions and limitations under the License.
*/

import Foundation
import UIKit
import DeviceAuthenticator
import OktaLogger
import SwiftUI

class RootCoordinator {

    let deviceAuthenticator: DeviceAuthenticatorProtocol
    let oktaWebAuthenticator: OktaWebAuthProtocol
    let pushNotificationService: PushNotificationService
    var remediationEventsHandler: RemediationEventsHandlerProtocol
    var logger: OktaLogger?
    var navController: UINavigationController?

    init(deviceAuthenticator: DeviceAuthenticatorProtocol,
         oktaWebAuthenticator: OktaWebAuthProtocol,
         pushNotificationService: PushNotificationService,
         remediationEventsHandler: RemediationEventsHandlerProtocol,
         oktaLogger: OktaLogger?) {
        self.deviceAuthenticator = deviceAuthenticator
        self.oktaWebAuthenticator = oktaWebAuthenticator
        self.pushNotificationService = pushNotificationService
        self.logger = oktaLogger
        self.remediationEventsHandler = remediationEventsHandler
    }

    func begin(on window: UIWindow?) {
        guard let window = window else { return }
        if oktaWebAuthenticator.isSignedIn {
            beginSwiftUISettingsFlow(on: window)
        } else {
            beginSignInFlow(on: window)
        }
    }

    private func beginSwiftUISettingsFlow(on window: UIWindow) {
        let settingsViewModel = SettingsSwiftUIViewModel(
            deviceAuthenticator: deviceAuthenticator,
            webAuthenticator: oktaWebAuthenticator,
            pushNotificationService: pushNotificationService,
            logger: logger
        )
        let settingsView = SettingsLandingView(viewModel: settingsViewModel, onSignOut: {
            self.beginSignOut()
        })
        let hostingController = UIHostingController(rootView: settingsView)
        navController = UINavigationController(rootViewController: hostingController)
        window.rootViewController = navController
        window.makeKeyAndVisible()
    }

    private func beginSignInFlow(on window: UIWindow?) {
        guard let window = window else { return }

        let viewModel = SignInViewModel(deviceAuthenticator: deviceAuthenticator,
                                        oktaWebAuthProtocol: oktaWebAuthenticator,
                                        logger: logger)

        let signInView = SignInSwiftUIView {
            viewModel.onSignInTapped(on: window)
        }

        let hostingVC = UIHostingController(rootView: signInView)
        viewModel.didSignIn = { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.begin(on: window)
                }
            }
        }

        let navController = UINavigationController(rootViewController: hostingVC)
        window.rootViewController = navController
        self.navController = navController
        window.makeKeyAndVisible()
    }

    func beginUserConsentFlow(remediationStep: RemediationStepUserConsent) {
        guard let nav = navController else {
            remediationStep.provide(.denied)
            return
        }
        guard let presenter = nav.topViewController  else { return }
        TruKYCHandler.shared.performBiometric(from: presenter) { [weak self] result in
            Task {
                do {
                    guard let self = self else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        presenter.dismiss(animated: true)
                    }
                    switch result {
                    case .success(let kycResult):
                        guard kycResult.isSelfieReal && kycResult.isUserAbove21 else {
                            remediationStep.provide(.denied)
                            return
                        }
                        remediationStep.provide(.approved)
                    case .failure(let error):
                        self.logger?.error(eventName: LoggerEvent.trukyc.rawValue, message: error.userMessage)
                        remediationStep.provide(.denied)
                    }
                }
            }
        }
    }

    func handleChallengeResponse(userResponse: PushChallengeUserResponse) {
        guard userResponse != .userNotResponded else {
            // Here you would handle if the user didn't respond to the challenge
            return
        }
        guard let nav = navController else { return }
        showVerificationAlert(didApprove: userResponse == .userApproved, nav: nav)
    }

    private func showVerificationAlert(didApprove: Bool, nav: UINavigationController) {
        var alertTitle: String
        var alertText: String
        if didApprove {
            alertTitle = "Authorization OK!"
            alertText = "Thanks for securely verifying your identity."
        } else {
            alertTitle = "We've logged this attempt to sign in"
            alertText = "The details of this attempt have been logged for security review."
        }

        let alert = UIAlertController(title: alertTitle, message: alertText, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default))

        if let topVC = topViewController(startingFrom: nav) {
            if topVC.presentedViewController == nil {
                topVC.present(alert, animated: true)
            } else {
                logger?.info(eventName: LoggerEvent.userVerification.rawValue, message: "⚠️ Skipping alert — another view controller is already presented.")
            }
        }
    }

    private func topViewController(startingFrom root: UIViewController?) -> UIViewController? {
        var top = root

        // Traverse through presented view controllers
        while let presented = top?.presentedViewController {
            top = presented
        }

        // If top is a navigation controller, get the visible view controller
        if let nav = top as? UINavigationController {
            return nav.visibleViewController
        }

        // If top is a tab bar controller, get the selected view controller
        if let tab = top as? UITabBarController {
            return tab.selectedViewController
        }

        return top
    }

    private func beginSignOut() {
        guard let window = navController?.navigationBar.window else { return }

        /*
         Depending on your app's behavior, you may want to delete the current enrollment from both server and device when signing out of the User's session. This to avoid receiving the wrong push notifications for the next user that may sign in into your app.
         For this sample app, we are doing this by removing the existing enrollment via the SDK's `delete` API and signing out on completion.
         */
        guard let enrollment = deviceAuthenticator.allEnrollments().first else {
            signOut(from: window)
            return
        }

        oktaWebAuthenticator.getAccessToken {[weak self] result in
            switch result {
            case .success(let token):
                self?.logger?.info(eventName: LoggerEvent.enrollment.rawValue, message: "Success got token \(token)")
                // TruKYC NOTE :- Do not remove enrollments for re-signin flow
                self?.deviceAuthenticator.delete(enrollment: enrollment, authenticationToken: AuthToken.bearer(token.accessToken), completion: { error in
                    self?.signOut(from: window)

                    if case .serverAPIError = error {
                        try? enrollment.deleteFromDevice()
                    }
                    self?.logger?.error(eventName: LoggerEvent.enrollmentDelete.rawValue, message: error?.localizedDescription)
                })
            case .failure(let error):
                self?.signOut(from: window)
                self?.logger?.error(eventName: LoggerEvent.account.rawValue, message: error.errorDescription)
            }
        }

    }

    private func signOut(from window: UIWindow) {
        oktaWebAuthenticator.signOut(from: window) { [weak self] result in
            if case .failure(let error) = result {
                self?.logger?.error(eventName: LoggerEvent.webSignIn.rawValue, message: error.localizedDescription)
                self?.begin(on: window)
            }
            self?.navController?.popViewController(animated: true)
            self?.begin(on: window)
        }
    }
}

extension RootCoordinator {
    static func resetAppUIOnSignOut(using coordinator: RootCoordinator, on window: UIWindow) {
        DispatchQueue.main.async {
            coordinator.begin(on: window)
        }
    }
}
