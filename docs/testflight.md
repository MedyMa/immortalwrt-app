# TestFlight publishing

The manual **Publish iOS to TestFlight** workflow builds a signed device IPA and uploads it to App Store Connect. Simulator artifacts cannot be uploaded to TestFlight.

Create the App Store Connect app record and explicit App ID `com.medyma.immortalwrtApp` in the same Apple Developer team. Create an Apple Distribution certificate with its private key exported as a password-protected P12, and an App Store distribution provisioning profile for that exact ID and certificate.

Configure GitHub repository secrets (or secrets in the `testflight` environment):

| Secret | Value |
|---|---|
| `IOS_TEAM_ID` | Apple Developer team ID |
| `IOS_DISTRIBUTION_P12_BASE64` | Base64-encoded distribution P12 |
| `IOS_DISTRIBUTION_P12_PASSWORD` | P12 export password |
| `IOS_PROVISION_PROFILE_BASE64` | Base64-encoded App Store provisioning profile |
| `ASC_KEY_ID` | App Store Connect team API key ID |
| `ASC_ISSUER_ID` | API key issuer ID |
| `ASC_PRIVATE_KEY_BASE64` | Base64-encoded API key P8 |

Use a team API key with Developer or higher access to this app. Never commit these files or paste their contents into chat. GitHub Actions only needs the secrets above; it does not need your Apple ID password.

Run the workflow on `main`, using a new build number for each upload (first build: 19). Upload completion means Apple received the build. Wait for processing in App Store Connect → TestFlight, answer export-compliance questions where required, and add the build to the intended tester group. External testing may require Apple's beta review. No tester invitations are sent by this workflow.

The signing workflow requires macOS/Xcode and configured credentials; it cannot be validated as a signed upload on Windows. Routine CI continues to produce the Android debug APK and unsigned iOS simulator package.
