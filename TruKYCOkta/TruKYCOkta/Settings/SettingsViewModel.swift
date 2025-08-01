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
import DeviceAuthenticator
import OktaLogger
import UIKit

protocol SettingsViewUpdatable: AnyObject {
    func showAlert(alertTitle: String, alertText: String)
    func updateView(shouldShowSpinner: Bool)
}

protocol SettingsViewModelProtocol {
    var title: String { get }
    var view: SettingsViewUpdatable? { get }
}

enum EnrollmentError: Error {
    case accessTokenError, baseUrlError, clientIdError, deviceAuthenticatorError(DeviceAuthenticatorError?)

    var description: String {
        switch self {
        case .accessTokenError:
            return "Error getting access token"
        case .baseUrlError:
            return "Base url should not be nil"
        case .clientIdError:
            return "ClientId should not be nil"
        case .deviceAuthenticatorError(let error):
            return "DeviceAuthenticator error \(error?.localizedDescription ?? "")"
        }
    }

    static let errorTitle = "Failed to enroll"
    static let authConfigErrorTitle = "Error creating config"
}

enum EnrollmentDeleteError: Error {
    case noEnrollmentDeleteError, accessTokenError, deviceAuthenticatorError(DeviceAuthenticatorError?)

    var description: String {
        switch self {
        case .noEnrollmentDeleteError:
            return "No enrollment to delete"
        case .accessTokenError:
            return "Error getting access token"
        case .deviceAuthenticatorError(let error):
            return "DeviceAuthenticator error \(error?.localizedDescription ?? "")"
        }
    }
    static let errorTitle = "Failed to delete"
}


class SettingsViewModel: SettingsViewModelProtocol {

    private let authenticator: DeviceAuthenticatorProtocol
    private let webAuthenticator: OktaWebAuthProtocol
    private let pushNotificationService: PushNotificationService
    private let logger: OktaLogger?
    var title: String = "Security Settings"
    weak var view: SettingsViewUpdatable?
    private var deviceEnrollment: AuthenticatorEnrollmentProtocol?

    init(deviceauthenticator: DeviceAuthenticatorProtocol,
         webAuthenticator: OktaWebAuthProtocol,
         pushNotificationService: PushNotificationService,
         settingsView: SettingsViewUpdatable,
         logger: OktaLogger? = nil) {
        self.authenticator = deviceauthenticator
        self.webAuthenticator = webAuthenticator
        self.pushNotificationService = pushNotificationService
        self.view = settingsView
        self.logger = logger
        deviceEnrollment = authenticator.allEnrollments().first
    }

    private var deviceAuthenticatorConfig: DeviceAuthenticatorConfig? {
        guard let url = webAuthenticator.baseURL else {
            logger?.error(eventName: EnrollmentError.authConfigErrorTitle, message: EnrollmentError.baseUrlError.description)
            view?.showAlert(alertTitle: EnrollmentError.authConfigErrorTitle, alertText: EnrollmentError.baseUrlError.description)
            return nil
        }
        guard let clientId = webAuthenticator.clientId else {
            logger?.error(eventName: EnrollmentError.authConfigErrorTitle, message: EnrollmentError.clientIdError.description)
            view?.showAlert(alertTitle: EnrollmentError.authConfigErrorTitle, alertText: EnrollmentError.clientIdError.description)
            return nil
        }
        return DeviceAuthenticatorConfig(orgURL: url, oidcClientId: clientId)
    }

    private func getAccessToken(completion: @escaping (String) -> Void) {
        // Fetching a valid access token. WebAuthenticator will try to refresh it if expired.
        webAuthenticator.getAccessToken { [weak self] result in
            switch result {
            case .success(let token):
                completion(token.accessToken)
            case .failure(let error):
                self?.logger?.error(eventName: LoggerEvent.account.rawValue, message: error.localizedDescription)
                self?.view?.showAlert(alertTitle: "Error", alertText: EnrollmentError.accessTokenError.description)
                self?.view?.updateView(shouldShowSpinner: false)
            }
        }
    }

    private func didEnableEnrollmentToggle() {
        pushNotificationService.requestNotificationsPermissionsIfNeeded { [weak self] in
            self?.beginEnrollment()
        }
    }

    private func beginEnrollment() {
        getAccessToken { token in
            self.enrollDeviceAuthenticator(with: token)
        }
    }
    
    private func printDeviceToken(_ deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("📱 Push Device Token: \(tokenString)")
    }

    private func enrollDeviceAuthenticator(with accessToken: String) {

        let authToken = AuthToken.bearer(accessToken)

        guard let deviceAuthenticatorConfig = deviceAuthenticatorConfig else { return }

        var deviceToken = DeviceToken.empty
        if let pushToken = UserDefaults.deviceToken() {
            deviceToken = .tokenData(pushToken)
            printDeviceToken(pushToken)
        } else {
            logger?.warning(eventName: LoggerEvent.enrollment.rawValue, message: "Device token is nil")
        }
        let enrollmentParams = EnrollmentParameters(deviceToken: deviceToken)

        view?.updateView(shouldShowSpinner: true)

        /**

         - You may want to fetch the authenticator policy via `authenticator.downloadPolicy()` method before calling enroll to start the enrollment flow.
         - If policy *requires* user verification capabilities to be enabled for the enrollment then UI flow should force the user to enable device biometrics and give permissions to the app to use biometrics.
         - If policy *prefers* user verification capabilities then UI flow may suggest the user to additionally enable user verification for the enrollment.
         - Once the policy is evaluated by the app it can call enroll API with relevant enrollment settings.
         */

        authenticator.enroll(authenticationToken: authToken,
                             authenticatorConfig: deviceAuthenticatorConfig,
                             enrollmentParameters: enrollmentParams) { [weak self] result in

            switch result {
            case .success(let authenticator):
                self?.deviceEnrollment = authenticator
                self?.logger?.info(eventName: LoggerEvent.enrollment.rawValue, message: "Success enrolling this device, enrollment ID - \(authenticator.enrollmentId)")
                self?.view?.showAlert(alertTitle: "Enrolled Successfully", alertText: "You can now use this app as push authenticator")
            case .failure(let error):
                self?.logger?.error(eventName: EnrollmentError.deviceAuthenticatorError(error).description, message: error.localizedDescription)
                self?.view?.showAlert(alertTitle: EnrollmentError.errorTitle, alertText: error.localizedDescription)
            }
            self?.view?.updateView(shouldShowSpinner: false)
        }
    }
    
    private func enrollmentCompleted() {

    }

    private func beginEnrollmentDeletion() {
        guard let enrollment = deviceEnrollment else {
            view?.showAlert(alertTitle: EnrollmentDeleteError.errorTitle, alertText: EnrollmentDeleteError.noEnrollmentDeleteError.description)
            logger?.error(eventName: LoggerEvent.enrollmentDelete.rawValue, message: EnrollmentDeleteError.noEnrollmentDeleteError.description)
            return
        }
        getAccessToken { token in
            self.deleteEnrollment(enrollment: enrollment, accessToken: token)
        }
    }

    private func deleteEnrollment(enrollment: AuthenticatorEnrollmentProtocol, accessToken: String) {
        let authToken = AuthToken.bearer(accessToken)
        view?.updateView(shouldShowSpinner: true)
        authenticator.delete(enrollment: enrollment, authenticationToken: authToken) { [weak self] error in
            if let error = error {
                self?.view?.showAlert(alertTitle: EnrollmentDeleteError.errorTitle, alertText: error.localizedDescription)
                self?.logger?.error(eventName: LoggerEvent.enrollmentDelete.rawValue, message: error.localizedDescription)
            } else {
                self?.deviceEnrollment = nil
                self?.view?.showAlert(alertTitle: "Deletion Successfully", alertText: "Success removing this device as a push authenticator")
            }
            self?.view?.updateView(shouldShowSpinner: false)
        }
    }
}
