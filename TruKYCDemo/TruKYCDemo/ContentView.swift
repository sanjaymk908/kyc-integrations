//
//  ContentView.swift
//  TruKYCDemo
//
//  Created by Sanjay Krishnamurthy on 7/18/25.
//

import SwiftUI
import Dist // Replace with actual module name if needed

struct ContentView: View {
    @State private var showKYC = false
    @State private var result: KYCResult?

    var body: some View {
        ZStack {
            if let result = result {
                ResultView(result: result) {
                    self.result = nil
                }
                .transition(.move(edge: .bottom))
            } else if showKYC {
                TruKYCSwiftUI { kycResult in
                    self.result = kycResult
                    self.showKYC = false
                }
                .edgesIgnoringSafeArea(.all)
                .transition(.move(edge: .bottom))
            } else {
                IntroView(showKYC: $showKYC)
                    .transition(.opacity)
            }
        }
        .animation(.spring(), value: result != nil || showKYC)
    }

    // MARK: - Visual ResultView with Icons & Stats

    private struct ResultView: View {
        let result: KYCResult
        let onDismiss: () -> Void

        var body: some View {
            ScrollView {
                VStack(spacing: 32) {
                    Text("KYC Result")
                        .font(.largeTitle)
                        .padding(.top)

                    HStack(spacing: 32) {
                        VStack {
                            Image(systemName: result.isSelfieReal ? "checkmark.seal.fill" : "gearshape.2.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 48, height: 48)
                                .foregroundColor(result.isSelfieReal ? .green : .red)
                            Text("Selfie Real")
                        }

                        VStack {
                            Image(systemName: result.isUserAbove21 ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 48, height: 48)
                                .foregroundColor(result.isUserAbove21 ? .green : .red)
                            Text("Above 21")
                        }

                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("🔢 Real (Tru): \(formatAsPercent(result.realProb))")
                        Text("🔢 Fake (Tru): \(formatAsPercent(result.fakeProb))")
                        Text("🍎 Real (Apple): \(formatAsPercent(result.realProbAppleAPI))")
                        Text("🍎 Fake (Apple): \(formatAsPercent(result.fakeProbAppleAPI))")
                        Text("🧩 Selfie/ID Match: \(formatAsPercent(result.selfieIDprofileMatchProb))")
                        if result.isUserAbove21 == false {
                            Text("❌ Failure Reason: \(result.failureReason.displayString)")
                        }
                    }
                    .padding(.horizontal)
                    .font(.body)

                    Button(action: onDismiss) {
                        Label("Dismiss", systemImage: "arrow.uturn.backward.circle.fill")
                            .font(.title2)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(15)
                    }
                    .padding(.bottom)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal)
            }
            .background(Color(UIColor.systemBackground))
        }
        
        private func formatAsPercent(_ value: Double) -> String {
            return String(format: "%.1f%%", value * 100)
        }
    }
}

extension ClientAPI.AgeVerificationResult {
    var displayString: String {
        switch self {
        case .inDeterminate: return "Inconclusive"
        case .above21: return "User is above 21"
        case .below21: return "User is under 21"
        case .expiredID: return "ID is expired"
        case .selfieIDProfileMismatch: return "Selfie and ID don't match"
        case .failedToReadID: return "Could not read ID"
        case .selfieInaccurate: return "Unclear or fake selfie"
        case .internalError: return "Internal error"
        @unknown default: return "Unknown reason"
        }
    }
}

