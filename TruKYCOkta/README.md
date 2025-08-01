# Okta Authenticator Sample App

This sample app demonstrates how to integrate [Okta Devices SDK](https://github.com/okta/okta-devices-swift) into an Xcode project.

**Table of Contents**
- [TruKYC Okta Integration App](#trukyc-okta-integration-app)
  - [Prerequisites](#prerequisites)
  - [Update Okta.plist](#update-oktaplist)
  - [Run the Project](#run-the-project)
  - [Enroll the App as a Custom Authenticator](#enroll-the-app-as-a-custom-authenticator)
  - [Verify It Works](#verify-it-works)
  - [Implementing the SDK in Your Project](#implementing-the-sdk-in-your-project)
  - [Debugging Tips](#debugging-tips)

## TruKYC Okta Integration App

### Prerequisites

#### Admin Prerequisites
1. Add a Native OIDC app with the proper scopes:  
   `okta.authenticators.manage.self`, `okta.authenticators.read`, `okta.devices.manage`, `okta.devices.read`,  
   `okta.factors.manage`, `okta.myAccount.appAuthenticator.maintenance.manage`, `okta.myAccount.appAuthenticator.maintenance.read`,  
   `okta.myAccount.appAuthenticator.manage`, `okta.myAccount.appAuthenticator.read`, `okta.users.manage`, `okta.users.read.self`.

2. Create an **APNS config** at [Apple Developer Portal](https://developer.apple.com).  
   The Bundle ID should match this app’s bundle ID (`com.yella.TruKYCOkta`).  
   Download the `.p8` APNS key for use during Okta setup.

3. Create a custom authenticator in Okta using the APNS configuration created above.

#### Client Prerequisites
1. If your client app is **Xcode-managed**, add the following capabilities to the app target under `Signing & Capabilities`:
   - App Groups
   - Push Notifications
   - Time Sensitive Notifications

   If not, create a new App ID in the Apple Developer portal with these capabilities enabled.

2. Install [CocoaPods](http://cocoapods.org) if not already installed.

---

## Update Okta.plist

This SDK needs an access token for backend authentication. We're using [Okta Mobile SDK](https://github.com/okta/okta-mobile-swift) for sign-in and token retrieval.

Update the `Okta.plist` file with your Okta app’s values:
1. `{clientId}` – OIDC Client ID
2. `{issuer}` – App’s OAuth2 domain (e.g. `https://yourdomain.okta.com`)
3. `{redirectUri}` – Must match what's configured in your app
4. `{logoutRedirectUri}` – Must match what’s configured in your app
5. `{scopes}` – Include:
   - `openid`
   - `offline_access`
   - `profile`
   - `email`
   - `okta.myAccount.appAuthenticator.manage`
   - `okta.myAccount.appAuthenticator.read`

---

## Run the Project

1. Open Terminal and navigate to the project directory:
    ```bash
    cd TruKYCOkta/
    ```

2. Update and install pods:
    ```bash
    pod repo update
    pod install
    ```

3. Open the `.xcworkspace` file:
    ```bash
    open TruKYCOkta.xcworkspace
    ```

4. In Xcode, update the Bundle Identifier in project settings to match your Apple Developer App ID.

5. Under `Signing & Capabilities`, add your App Group (e.g. `group.group.com.yella.TruKYCOkta`).  
   If it differs from the default, update the `applicationGroupID` in `AppDelegate.swift`.

6. Build and run on a **real device** 📲 for Push Notifications & Camera access.

---

## Enroll the App as a Custom Authenticator

Sign in using your Okta org credentials in the app. Then:

1. Enable **Sign in with Push Notification**.  
   This will trigger SDK enrollment and register your device as a push authenticator.

2. On success, you’ll see a success alert confirming enrollment.

---

## Verify It Works

1. On a browser, sign in to your Okta org.
2. After password entry, you should receive a push notification.
3. Tap the notification to launch the app and complete verification via the TruKYC SDK.
4. If successful, you’ll be signed in.

---

### Push Delivery Issues

If notifications fail to arrive, the SDK will poll for pending challenges when the app is foregrounded.  
If there’s one pending, the app will prompt you for verification.

---

## Implementing the SDK in Your Project

1. **`NSCameraUsageDescription`**

    Add this key to your app’s `Info.plist` to enable camera access:
    ```xml
    <key>NSCameraUsageDescription</key>
    <string>Used for facial identity verification via TruKYC</string>
    ```

    If missing, the app will **crash at runtime** when attempting to access the camera.

2. **`apsEnvironment`**

    Ensure your app uses the correct push notification environment.

    - In `Entitlements.plist`, add:
      ```xml
      <key>aps-environment</key>
      <string>development</string>
      ```

      Replace with `production` for production builds.

3. **Age Verification Check**

    In `TruKYCHandler.swift`, the following logic checks that the user is over 21:
    ```swift
    if result.isSelfieReal && result.isUserAbove21 {
        // Proceed
    }
    ```

    To allow users under 21 with valid IDs, use:
    ```swift
    if result.isSelfieReal && (result.isUserAbove21 || result.isUserBelow21) {
        // Proceed
    }
    ```

---

## Debugging Tips

1. **Push Not Received**

    - Use the [Apple APNs Console](https://developer.apple.com/account/resources/identifiers/list/push) to send test pushes.
    - Ensure the push targets the correct bundle ID.

2. **Unable to Sign In After Username Entry**

    - Ensure the device is already enrolled via this TruKYC Okta app.
    - Otherwise, sign-in won’t proceed to password or verification steps.

3. **Check Enrollment Status**

    - In the Okta Admin Console, go to **System Logs**.
    - Successful enrollments show `Authentication of user via MFA SUCCESS`.
    - Deleted enrollments show `Reset factor for user SUCCESS`.

---

## License

This project is licensed under the MIT License.

