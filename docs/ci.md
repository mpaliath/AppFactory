# CI/CD: Deploy iOS App to TestFlight

This repository uses `.github/workflows/deploy-testflight.yml` to archive the iOS app and upload it to TestFlight after a pull request is merged.

## What changed

The workflow now uses the simplest current setup:

- Xcode automatic signing
- App Store Connect API key authentication
- GitHub Actions on `macos-latest`

It no longer installs a `.p12` certificate, creates a temporary keychain, or copies a `.mobileprovision` profile into the runner.

## Trigger behavior

The workflow runs on:

- `pull_request` with type `closed`
- `workflow_dispatch`

For pull requests, deployment continues only when the PR was actually merged.

## Required GitHub secrets

Add these repository secrets in GitHub under `Settings -> Secrets and variables -> Actions`:

- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY`

`APP_STORE_CONNECT_API_KEY` should contain the raw `.p8` key contents, including the `BEGIN PRIVATE KEY` and `END PRIVATE KEY` lines.

## Required Xcode project settings

This workflow depends on the Xcode project already being configured for automatic signing.

Confirm the Release build for the app target has:

- `CODE_SIGN_STYLE = Automatic`
- the correct `DEVELOPMENT_TEAM`
- the correct `PRODUCT_BUNDLE_IDENTIFIER`

In this repository those values live in `HelloWorldiOS/HelloWorldiOS.xcodeproj/project.pbxproj`.

## How the workflow works

1. Checks out the repository.
2. Installs the latest stable Xcode on the GitHub runner.
3. Writes the App Store Connect API key to a temporary `.p8` file.
4. Runs `xcodebuild archive` with:
   - automatic signing
   - `-allowProvisioningUpdates`
   - App Store Connect API key authentication
5. Runs `xcodebuild -exportArchive` with:
   - `method = app-store-connect`
   - `destination = export`
   - `signingStyle = automatic`
6. Uploads the exported IPA to TestFlight with the App Store Connect API key.

This avoids Xcode's App Store metadata fetch during export and keeps the upload step explicit.

## Notes

- Deployments stay serialized through the existing `concurrency` setting, so multiple merged PRs do not upload at the same time.

## Troubleshooting

- **Signing fails**: verify the app target still uses automatic signing and the correct Apple Developer team.
- **Provisioning fails**: make sure the App Store Connect API key has access to the app and the Apple Developer account.
- **Upload fails**: verify `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, and `APP_STORE_CONNECT_API_KEY` are correct and active, and that the key can access the app in App Store Connect.
- **Wrong app receives the build**: verify the bundle identifier in the Xcode project matches the App Store Connect app.
