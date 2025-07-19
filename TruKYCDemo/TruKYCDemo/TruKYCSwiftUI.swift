//
//  TruKYCSwiftUI.swift
//  TruKYCDemo
//
//  Created by Sanjay Krishnamurthy on 7/18/25.
//

import SwiftUI
import Dist

struct TruKYCSwiftUI: UIViewControllerRepresentable {
    class Coordinator: NSObject, ClientAPIDelegate {
        func completedKYC(result: Dist.KYCResult) {
            parent.onCompletion(result)
        }
        
        var parent: TruKYCSwiftUI

        init(parent: TruKYCSwiftUI) {
            self.parent = parent
        }
    }

    var onCompletion: (KYCResult) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        ClientAPI.shared.delegate = context.coordinator
        // Use fullScreen: false for embedding
        return ClientAPI.shared.start(fullScreen: false)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
