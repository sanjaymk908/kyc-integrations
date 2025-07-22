//
//  TruKYCHandler.swift
//  TruKYCDemo
//
//  Created by Sanjay Krishnamurthy on 7/21/25.
//


import UIKit
import Dist

final class TruKYCHandler: NSObject {
    static let shared = TruKYCHandler()
    private var completionHandler: ((Result<KYCResult, TruKYCError>) -> Void)?

    func performBiometric(from presenter: UIViewController,
                          completion: @escaping (Result<KYCResult, TruKYCError>) -> Void) {
        self.completionHandler = completion
        ClientAPI.shared.delegate = self

        let kycVC = ClientAPI.shared.start(fullScreen: false)
        presenter.present(kycVC, animated: true)
    }
}

extension TruKYCHandler: ClientAPIDelegate {
    func completedKYC(result: KYCResult) {
        if result.isSelfieReal && result.isUserAbove21 {
            completionHandler?(.success(result))
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

            completionHandler?(.failure(error))
        }

        completionHandler = nil
    }
}
