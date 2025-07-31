//
//  TruKYCError.swift
//  SampleApp
//
//  Created by Sanjay Krishnamurthy on 7/28/25.
//

import Foundation

enum TruKYCError: Error {
    case selfieUnclear
    case idExpired
    case profileMismatch
    case networkUnavailable
    case internalError(String)
    case unknown

    var userMessage: String {
        switch self {
        case .selfieUnclear:
            return "Your selfie was unclear. Try again in good lighting."
        case .idExpired:
            return "Your ID looks expired. Please use a valid one."
        case .profileMismatch:
            return "Your selfie doesn't match your ID profile. Try again carefully."
        case .networkUnavailable:
            return "Please check your internet connection and retry."
        case .internalError(let details):
            return "An unexpected error occurred: \(details)"
        case .unknown:
            return "Something went wrong. Please try again or contact support."
        }
    }
}
