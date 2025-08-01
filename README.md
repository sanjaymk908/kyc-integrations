# TruKYC SDK

Welcome to the TruKYC SDK repository! This SDK provides a comprehensive solution for on-device KYC (Know Your Customer) processes integrated with Okta MFA for secure, passwordless authentication using facial biometrics.

---

## Repository Structure

This repo contains three main folders, each serving a distinct purpose:

### 1. Frameworks

- Contains `Dist.framework`, the iOS framework implementing the core TruKYC SDK functionality.
- Use this framework to integrate TruKYC capabilities into your iOS app.
- This framework handles the core KYC flow including selfie capture, ID scanning, and age verification.

### 2. TruKYCDemo

- A standalone iOS app demonstrating the usage of the TruKYC SDK (`Dist.framework`).
- Provides an onboarding Intro screen presenting disclaimers and a guide to the two-step TruKYC process:  
  - Taking a selfie  
  - Scanning an ID (currently supports Driver License, State ID, or US Passport)  
- Guides the user through performing these two steps interactively.  
- Processes the results and displays an info screen summarizing the KYC verification outcome.  
- Useful as a reference implementation or a starting point for your app development.

### 3. TruKYCOkta

- Contains the Xcode workspace for the app enabling integration with Okta for MFA push factor enrollment.  
- Allows users to enroll their devices as a push factor using TruKYC facial biometric verification.  
- After enrollment, this app receives push notifications from Okta as part of the MFA flow for user authentication.  
- Communicates the success or failure of the TruKYC facial biometric results back to Okta to determine the overall MFA outcome.  
- Demonstrates how to integrate TruKYC SDK with Okta's MFA ecosystem seamlessly.

---

## Getting Started

1. **Integrate the SDK:**  
   Use the `Dist.framework` from the Frameworks folder in your iOS project to enable TruKYC features.

2. **Explore the Demo:**  
   Open the `TruKYCDemo` app project to understand how to wrap the SDK with an onboarding flow and UI screens guiding the user.

3. **Okta Integration:**  
   Use the `TruKYCOkta` workspace as a reference for enrolling users as Okta MFA push factors and handling push notifications using the TruKYC facial biometric results.

---

## Supported ID Types

Currently supported ID documents for verification in the SDK include:

- Driver License  
- State ID  
- US Passport

---

## Disclaimer

This SDK is provided as a technical and compliance aid. Please ensure you follow your local regulations when using TruKYC SDK for age verification and identity proofing. The TruKYCDemo app includes disclaimers and user guidance.

---

For detailed documentation, integration guides, and troubleshooting tips, please refer to the `docs` folder (if available) or contact the maintainers.

---

Happy coding with TruKYC!


