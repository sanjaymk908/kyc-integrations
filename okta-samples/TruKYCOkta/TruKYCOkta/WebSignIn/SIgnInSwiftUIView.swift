//
//  SIgnInSwiftUIView.swift
//  SampleApp
//
//  Created by Sanjay Krishnamurthy on 7/30/25.
//

// SignInSwiftUIView.swift

import SwiftUI

struct SignInSwiftUIView: View {
    let onSignInTapped: () -> Void

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)

                Text("Welcome to TruKYC")
                    .font(.headline)

                Button(action: onSignInTapped) {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.blue, lineWidth: 2)
            )
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}
