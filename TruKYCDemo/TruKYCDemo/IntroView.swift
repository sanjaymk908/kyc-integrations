//
//  IntroView.swift
//  TruKYCDemo
//
//  Created by Sanjay Krishnamurthy on 7/18/25.
//

import SwiftUI

struct IntroView: View {
    @Binding var showKYC: Bool

    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "person.text.rectangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            Text("Welcome to TruSources.ai")
                .font(.largeTitle).fontWeight(.semibold).padding(.bottom, 4)
            Text("On-device KYC SDK\n\nVerifies your identity and age in 2 simple steps:\n1. Liveness check (selfie)\n2. ID document scan\n\n🔒 No data ever leaves your device.")
                .multilineTextAlignment(.center)
                .font(.body)
            Button(action: { showKYC = true }) {
                Text("Start KYC")
                    .font(.headline)
                    .frame(width: 200, height: 48)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
}
