# CI/CD: Deploy iOS App to TestFlight

This repository includes a GitHub Actions workflow at `.github/workflows/deploy-testflight.yml` that uploads the iOS app to TestFlight when a pull request is **merged**.

## 1) Confirm workflow trigger behavior

The workflow runs on:
- `pull_request` with type `closed`
- and only continues when `github.event.pull_request.merged == true`

So deployment happens only after a PR is merged.

## 2) Sequential deployments (concurrency)

The workflow uses:

- `concurrency.group: testflight-deploy`
- `cancel-in-progress: false`

This ensures TestFlight deployments run **one at a time** and preserve release order even if multiple PRs are merged close together.

## 3) Prepare Apple Developer assets

You need these items from Apple Developer / App Store Connect:

1. **iOS Distribution certificate** exported as `.p12`
2. **Provisioning profile** (`.mobileprovision`) for App Store/TestFlight distribution
3. **App Store Connect API key** (`.p8`) with permissions to upload builds
4. API key metadata:
   - **Key ID**
   - **Issuer ID**

## 4) Add required GitHub repository secrets

In GitHub: **Repository → Settings → Secrets and variables → Actions → New repository secret**

Add the following secrets exactly as named:

- `BUILD_CERTIFICATE_BASE64`
  - Base64-encoded `.p12` certificate file content
- `P12_PASSWORD`
  - Password used when exporting the `.p12` certificate
- `BUILD_PROVISION_PROFILE_BASE64`
  - Base64-encoded `.mobileprovision` file content
- `KEYCHAIN_PASSWORD`
  - Temporary keychain password used during the CI run
- `APP_STORE_CONNECT_KEY_ID`
  - App Store Connect API key ID
- `APP_STORE_CONNECT_ISSUER_ID`
  - App Store Connect issuer ID
- `APP_STORE_CONNECT_API_KEY`
  - Raw `.p8` API key content (including BEGIN/END markers)

## 5) Encode certificate and provisioning profile to base64

Run locally before adding secrets:

```bash
# Certificate (.p12)
base64 -i cert.p12 | pbcopy

# Provisioning profile (.mobileprovision)
base64 -i profile.mobileprovision | pbcopy
```

Paste each output into:
- `BUILD_CERTIFICATE_BASE64`
- `BUILD_PROVISION_PROFILE_BASE64`

> Tip: Keep the values as a single line if possible.

## 6) Verify Xcode project/scheme values used by CI

The workflow builds with:

- Project: `HelloWorldiOS/HelloWorldiOS.xcodeproj`
- Scheme: `HelloWorldiOS`
- Configuration: `Release`

If these change in the app project, update `.github/workflows/deploy-testflight.yml` accordingly.

## 7) Xcode version selection

The workflow uses `maxim-lobanov/setup-xcode@v4` with `xcode-version: latest-stable`, so CI automatically picks the latest stable Xcode available on GitHub-hosted macOS runners.

## 8) Dynamic build number and CFBundleVersion validation

Before building, the workflow:

1. Generates a UTC timestamp build number in `YYYYMMDDHHMMSS` format.
2. Writes it into `HelloWorldiOS/HelloWorldiOS/Info.plist` as `CFBundleVersion`.
3. Reads back `CFBundleVersion` and fails the workflow if it does not match.

This guarantees each TestFlight upload has a **unique, traceable build number**.

## 9) Ensure signing settings match CI export mode

The workflow exports with `method = app-store` and `signingStyle = manual`.

Make sure:
- The provisioning profile is valid for App Store distribution.
- The certificate/provisioning profile match the app bundle identifier.
- The Xcode project supports manual signing for release/archive as configured.

## 10) Deployment logging and traceability

The workflow logs and summarizes metadata for each deployment, including:

- PR number
- source/target branches
- merge commit SHA
- generated build number (`CFBundleVersion`)
- link to the workflow run

This is published in the GitHub Actions run summary (`GITHUB_STEP_SUMMARY`) and can be used as a deployment history list to match TestFlight builds back to their source PR.

## 11) Test the pipeline

1. Open a pull request with your changes.
2. Merge the pull request.
3. Go to **Actions** tab and open the `Deploy iOS App to TestFlight` run.
4. Confirm steps pass:
   - build number generation/validation
   - certificate/profile installation
   - archive
   - IPA export
   - upload to TestFlight
5. Verify the workflow summary includes the expected PR and build number.

## 12) Troubleshooting

- **Signing errors**: Recreate/export certificate and profile, re-encode, and update secrets.
- **API auth errors**: Re-check `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, and `.p8` key content.
- **Build/scheme errors**: Confirm project path and scheme name in the workflow.
- **No deployment after merge**: Verify PR was merged (not just closed) and workflow is enabled.
- **Duplicate/invalid build number**: Ensure `CFBundleVersion` is not overridden elsewhere in the build settings.
