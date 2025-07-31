//
//  SettingsLandingView.swift
//  SampleApp
//
//  Created by Sanjay Krishnamurthy on 7/29/25.
//

import SwiftUI

struct SettingsLandingView: View {
    @ObservedObject var viewModel: SettingsSwiftUIViewModel
    var onSignOut: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Image(systemName: "person.text.rectangle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.blue)

                    Text("TruKYC")
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                }
                .padding(.top, 40)

                Form {
                    Section {
                        Toggle(isOn: Binding(
                            get: { viewModel.isEnrolled },
                            set: { newValue in
                                viewModel.didToggleEnrollment(newValue)
                            })) {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.checkmark")
                                    .foregroundColor(.blue)
                                Text("Enable Enrollment")
                            }
                        }
                        .disabled(viewModel.isProcessing)
                    }

                    Section {
                        Button(action: onSignOut) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundColor(.red)
                                Text("Sign Out")
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
            }
            .alert(item: $viewModel.activeAlert) { alertContext in
                Alert(title: Text(alertContext.title),
                      message: Text(alertContext.message),
                      dismissButton: .default(Text("OK")) {
                          viewModel.activeAlert = nil
                      })
            }
        }
    }
}
