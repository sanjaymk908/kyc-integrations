//
//  LoginView.swift
//  TruKYCDemo
//
//  Created by Sanjay Krishnamurthy on 7/21/25.
//

import SwiftUI
import UIKit

struct LoginView: View {
    @StateObject private var authManager = AuthenticationManager()
    @State private var username = "trukycuser1"
    @State private var password = "OktaTest1$"

    var body: some View {
        VStack(spacing: 24) {
            switch authManager.currentStep {
            case .loading:
                ProgressView("Checking authentication...")

            case .passwordLogin:
                VStack(spacing: 12) {
                    TextField("Okta Username", text: $username)
                        .textFieldStyle(.roundedBorder)
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                    Button("Sign In") {
                        authManager.submitPassword(username: username, password: password)
                    }
                    .font(.headline)
                }

            case .truKYCCheck:
                Button("Start TruKYC Verification") {
                    authManager.startTruKYC()
                }
                .padding()
                .background(Color.blue.opacity(0.2))
                .cornerRadius(8)

            case .finished:
                Text("✅ Authentication Successful!")
                    .font(.title)

            case .error(let message):
                VStack {
                    Text("❌ \(message)").foregroundColor(.red)
                    Button("Retry") {
                        authManager.start()
                    }
                }
            }
        }
        .padding()
        .onAppear {
            authManager.start()
        }
    }
}

extension UIApplication {
    static func rootViewController() -> UIViewController? {
        return UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .rootViewController
    }
}
