//
//  OktaAppConfig.swift
//  TruKYCDemo
//
//  Created by Sanjay Krishnamurthy on 7/21/25.
//

import Foundation

struct OktaAppConfig {
    let clientId: String
    let issuer: String
    let redirectUri: String
    let scopes: [String]
    let applicationName: String
    let applicationVersion: String

    static func load() -> OktaAppConfig {
        guard let url = Bundle.main.url(forResource: "TruKYCOktaConfig", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            fatalError("🔴 TruKYCOktaConfig.plist is missing or malformed.")
        }

        // Parse scopes as [String], fallback to default if needed
        let scopes = dict["scopes"] as? [String] ?? ["openid", "profile", "email"]

        return OktaAppConfig(
            clientId: dict["clientId"] as? String ?? "",
            issuer: dict["issuer"] as? String ?? "",
            redirectUri: dict["redirectUri"] as? String ?? "",
            scopes: scopes,
            applicationName: dict["applicationName"] as? String ?? "UnknownApp",
            applicationVersion: dict["applicationVersion"] as? String ?? "1.0.0"
        )
    }
}

