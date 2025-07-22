//
//  AuthenticationManager.swift
//  TruKYCDemo
//
//  Created by Sanjay Krishnamurthy on 7/21/25.
//

import Foundation
import OktaIdxAuth
import UIKit

@MainActor
final class AuthenticationManager: ObservableObject {
    enum AuthStep {
        case loading
        case passwordLogin       // <-- initial
        case truKYCCheck
        case finished
        case error(String)
    }

    @Published var currentStep: AuthStep = .passwordLogin
    private var flow: InteractionCodeFlow?
    private var response: Response?

    func start() {
        Task {
            do {
                let config = OktaAppConfig.load()
                flow = InteractionCodeFlow(
                    issuerURL: URL(string: config.issuer)!,
                    clientId: config.clientId,
                    scope: config.scopes.joined(separator: " "),
                    redirectUri: URL(string: config.redirectUri)!
                )
                response = try await flow?.start()

                guard let response = response else {
                    currentStep = .error("No response from server.")
                    return
                }

                // Instead of waiting or checking identify remediation here,
                // just set passwordLogin as initial state so UI can prompt for creds immediately
                currentStep = .passwordLogin

            } catch {
                currentStep = .error("Failed to start login: \(error.localizedDescription)")
            }
        }
    }

    func submitPassword(username: String, password: String) {
        Task {
            do {
                guard var response = response else {
                    currentStep = .error("Login flow not initialized.")
                    return
                }

                // IDENTIFY remediation step - provide username and password
                if let identify = response.remediations[.identify] {
                    identify["identifier"]?.value = username
                    identify["credentials.passcode"]?.value = password
                    self.response = try await identify.proceed()
                    response = self.response!

                    if response.isLoginSuccessful {
                        try await completeLogin(response)
                        return
                    }
                }

                // PASSWORD challenge remediation step
                if let passwordChallenge = response.remediations[.challengeAuthenticator],
                   passwordChallenge.authenticators.contains(where: { $0.type == .password }) {
                    passwordChallenge["credentials.passcode"]?.value = password
                    self.response = try await passwordChallenge.proceed()
                    response = self.response!

                    if response.isLoginSuccessful {
                        try await completeLogin(response)
                        return
                    }
                }

                // Select TruKYC Face Authenticator if available
                if let selectAuth = response.remediations[.selectAuthenticatorAuthenticate],
                   let field = selectAuth["authenticator"],
                   let option = field.options?.first(where: { $0.label == "TruKYC Face Authenticator" }) {
                    field.selectedOption = option
                    self.response = try await selectAuth.proceed()
                    currentStep = .truKYCCheck
                    return
                }

                currentStep = .error("Unexpected remediation after password.")

            } catch {
                currentStep = .error("Login failed: \(error.localizedDescription)")
            }
        }
    }

    func startTruKYC() {
        guard let challenge = response?.remediations[.challengeAuthenticator],
              challenge.authenticators.contains(where: { $0.displayName == "TruKYC Face Authenticator" }),
              let tokenField = challenge["credentials.kycToken"],
              let presenter = UIApplication.rootViewController()
        else {
            currentStep = .error("TruKYC challenge not found.")
            return
        }

        TruKYCHandler.shared.performBiometric(from: presenter) { [weak self] result in
            Task {
                do {
                    guard let self = self else { return }

                    switch result {
                    case .success(let kycResult):
                        guard kycResult.isSelfieReal && kycResult.isUserAbove21 else {
                            self.currentStep = .error("KYC criteria not met.")
                            return
                        }

                        tokenField.value = "truKYC-verified"
                        self.response = try await challenge.proceed()

                        if let final = self.response, final.isLoginSuccessful {
                            try await self.completeLogin(final)
                        } else {
                            self.currentStep = .error("Login incomplete after KYC.")
                        }

                    case .failure(let err):
                        self.currentStep = .error("KYC failed: \(err.localizedDescription)")
                    }
                } catch {
                    self?.currentStep = .error("KYC challenge failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func completeLogin(_ response: Response) async throws {
        _ = try await response.finish()
        currentStep = .finished
    }
}

