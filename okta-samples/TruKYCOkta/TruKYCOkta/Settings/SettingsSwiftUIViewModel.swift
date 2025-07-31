//
//  SettingsSwiftUIModel.swift
//  SampleApp
//
//  Created by Sanjay Krishnamurthy on 7/29/25.
//

import Foundation
import Combine
import DeviceAuthenticator
import OktaLogger
import UIKit

struct AlertContext: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

class SettingsSwiftUIViewModel: ObservableObject {
    private let deviceAuthenticator: DeviceAuthenticatorProtocol
    private let webAuthenticator: OktaWebAuthProtocol
    private let pushNotificationService: PushNotificationService
    private let logger: OktaLogger?

    private var deviceEnrollment: AuthenticatorEnrollmentProtocol?

    @Published var isEnrolled: Bool = false
    @Published var isProcessing: Bool = false
    @Published var activeAlert: AlertContext? = nil

    init(deviceAuthenticator: DeviceAuthenticatorProtocol,
         webAuthenticator: OktaWebAuthProtocol,
         pushNotificationService: PushNotificationService,
         logger: OktaLogger?) {
        self.deviceAuthenticator = deviceAuthenticator
        self.webAuthenticator = webAuthenticator
        self.pushNotificationService = pushNotificationService
        self.logger = logger
        self.deviceEnrollment = deviceAuthenticator.allEnrollments().first
        self.isEnrolled = self.deviceEnrollment != nil
    }

    func didToggleEnrollment(_ isOn: Bool) {
        isOn ? enableEnrollment() : deleteEnrollment()
    }

    func enableEnrollment() {
        pushNotificationService.requestNotificationsPermissionsIfNeeded { [weak self] in
            self?.getAccessToken { token in
                self?.performEnrollment(accessToken: token)
            }
        }
    }

    func deleteEnrollment() {
        guard let enrollment = deviceEnrollment else {
            showAlert(title: "Failed to delete", message: "No enrollment to delete")
            logger?.error(eventName: LoggerEvent.enrollmentDelete.rawValue, message: "No enrollment to delete")
            return
        }
        getAccessToken { [weak self] token in
            self?.performEnrollmentDeletion(enrollment: enrollment, accessToken: token)
        }
    }

    func signOut(from window: UIWindow) {
        guard let enrollment = deviceEnrollment else {
            doSignOut(from: window)
            return
        }

        webAuthenticator.getAccessToken { [weak self] result in
            switch result {
            case .success(let token):
                self?.deviceAuthenticator.delete(enrollment: enrollment,
                                                 authenticationToken: AuthToken.bearer(token.accessToken)) { error in
                    if let error = error {
                        try? enrollment.deleteFromDevice()
                        self?.logger?.error(eventName: LoggerEvent.enrollmentDelete.rawValue, message: error.localizedDescription)
                    }
                    self?.doSignOut(from: window)
                }
            case .failure(let error):
                self?.logger?.error(eventName: LoggerEvent.account.rawValue, message: error.localizedDescription)
                self?.doSignOut(from: window)
            }
        }
    }

    private func doSignOut(from window: UIWindow) {
        webAuthenticator.signOut(from: window) { [weak self] result in
            if case .failure(let error) = result {
                self?.logger?.error(eventName: LoggerEvent.webSignIn.rawValue, message: error.localizedDescription)
            }

            DispatchQueue.main.async {
                if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
                   let rootCoordinator = appDelegate.rootCoordinator {
                    RootCoordinator.resetAppUIOnSignOut(using: rootCoordinator, on: window)
                }
            }
        }
    }

    private func getAccessToken(completion: @escaping (String) -> Void) {
        webAuthenticator.getAccessToken { [weak self] result in
            switch result {
            case .success(let token):
                completion(token.accessToken)
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.showAlert(title: "Error", message: "Error getting access token")
                    self?.logger?.error(eventName: LoggerEvent.account.rawValue, message: error.localizedDescription)
                }
            }
        }
    }

    private func performEnrollment(accessToken: String) {
        guard let orgUrl = webAuthenticator.baseURL else {
            showAlert(title: "Error creating config", message: "Base URL should not be nil")
            return
        }
        guard let clientId = webAuthenticator.clientId else {
            showAlert(title: "Error creating config", message: "ClientId should not be nil")
            return
        }

        let config = DeviceAuthenticatorConfig(orgURL: orgUrl, oidcClientId: clientId)
        var deviceToken = DeviceToken.empty

        if let pushToken = UserDefaults.deviceToken() {
            deviceToken = .tokenData(pushToken)
        } else {
            logger?.warning(eventName: LoggerEvent.enrollment.rawValue, message: "Device token is nil")
        }

        let enrollmentParams = EnrollmentParameters(deviceToken: deviceToken)
        DispatchQueue.main.async {
            self.isProcessing = true
        }

        deviceAuthenticator.enroll(authenticationToken: AuthToken.bearer(accessToken),
                                   authenticatorConfig: config,
                                   enrollmentParameters: enrollmentParams) { [weak self] result in
            DispatchQueue.main.async {
                self?.isProcessing = false
                switch result {
                case .success(let enrollment):
                    self?.deviceEnrollment = enrollment
                    self?.isEnrolled = true
                    self?.showAlert(title: "Enrolled Successfully", message: "This device is now a push authenticator.")
                case .failure(let error):
                    self?.isEnrolled = false
                    self?.showAlert(title: "Enrollment failed", message: error.localizedDescription)
                    self?.logger?.error(eventName: LoggerEvent.enrollment.rawValue, message: error.localizedDescription)
                }
            }
        }
    }

    private func performEnrollmentDeletion(enrollment: AuthenticatorEnrollmentProtocol, accessToken: String) {
        isProcessing = true
        deviceAuthenticator.delete(enrollment: enrollment, authenticationToken: AuthToken.bearer(accessToken)) { [weak self] error in
            DispatchQueue.main.async {
                self?.isProcessing = false
                if let error = error {
                    self?.showAlert(title: "Failed to delete", message: error.localizedDescription)
                    self?.logger?.error(eventName: LoggerEvent.enrollmentDelete.rawValue, message: error.localizedDescription)
                } else {
                    self?.deviceEnrollment = nil
                    self?.isEnrolled = false
                    self?.showAlert(title: "Deleted Successfully", message: "Enrollment has been removed.")
                }
            }
        }
    }

    private func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            self.activeAlert = AlertContext(title: title, message: message)
        }
    }
}
