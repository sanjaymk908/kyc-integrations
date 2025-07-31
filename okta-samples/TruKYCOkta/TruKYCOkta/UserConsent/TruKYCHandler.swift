//
//  TruKYCHandler.swift
//  SampleApp
//
//  Created by Sanjay Krishnamurthy on 7/28/25.
//

import UIKit
import Dist

final class TruKYCHandler: NSObject {
    static let shared = TruKYCHandler()
    private var completionHandler: ((Result<KYCResult, TruKYCError>) -> Void)?
    private weak var rootKYCViewController: UIViewController?
    private weak var startingViewController: UIViewController?  // Track original VC

    func performBiometric(from presenter: UIViewController,
                          completion: @escaping (Result<KYCResult, TruKYCError>) -> Void) {
        self.completionHandler = completion
        ClientAPI.shared.delegate = self

        // Capture top-most VC at start to know where to stop dismissal later
        self.startingViewController = topViewController(startingFrom: presenter)

        let kycVC = ClientAPI.shared.start(fullScreen: true)
        self.rootKYCViewController = kycVC

        let topPresenter = startingViewController!

        if topPresenter.presentedViewController == nil {
            topPresenter.present(kycVC, animated: true)
        } else {
            print("⚠️ TruKYCHandler: Already presenting another VC. Aborting KYC presentation.")
        }
    }

    // MARK: - Utility to find top-most presenter

    private func topViewController(startingFrom root: UIViewController?) -> UIViewController {
        var top = root

        while let presented = top?.presentedViewController {
            top = presented
        }

        return top ?? UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? UIViewController()
    }

    /// Dismiss modals until we return to the originally tracked VC or no more presented VCs
    private func dismissToStartingViewController(completion: @escaping () -> Void) {
        guard var current = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            completion()
            return
        }

        func dismissNext() {
            if current === startingViewController || current.presentedViewController == nil {
                completion()
                return
            }

            if let presented = current.presentedViewController {
                presented.dismiss(animated: true) {
                    current = self.topViewController(startingFrom: current)
                    dismissNext()
                }
            } else {
                completion()
            }
        }

        dismissNext()
    }
}

// MARK: - Delegate Callback

extension TruKYCHandler: ClientAPIDelegate {
    func completedKYC(result: KYCResult) {
        dismissToStartingViewController { [weak self] in
            guard let self = self else { return }

            if result.isSelfieReal && result.isUserAbove21 {
                self.completionHandler?(.success(result))
            } else {
                let error: TruKYCError

                switch result.failureReason {
                case .selfieInaccurate:
                    error = .selfieUnclear
                case .expiredID:
                    error = .idExpired
                case .selfieIDProfileMismatch:
                    error = .profileMismatch
                case .failedToReadID:
                    error = .internalError("ID not readable.")
                case .internalError:
                    error = .internalError("Internal SDK problem.")
                case .inDeterminate:
                    error = .unknown
                default:
                    error = .unknown
                }

                self.completionHandler?(.failure(error))
            }

            self.completionHandler = nil
            self.rootKYCViewController = nil
            self.startingViewController = nil
        }
    }
}
