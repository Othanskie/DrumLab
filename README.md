# DRUMLAB for iPad

This iPad version uses a native Swift shell around the bundled DRUMLAB interface.

- **USB / hardware MIDI:** Apple CoreMIDI.
- **Bluetooth MIDI:** CoreBluetooth scans for the standard BLE-MIDI service and subscribes to the MIDI characteristic.
- **UI/audio:** bundled local HTML and Web Audio inside WKWebView.
- **No Web MIDI and no Web Bluetooth:** hardware messages enter through Swift and are forwarded to the local UI through a narrow JavaScript bridge.
- **Orientation:** portrait and landscape are both supported.

## Build an IPA through GitHub Actions for Sideloadly

The repository includes `.github/workflows/build-sideloadly-ipa.yml`. It runs on a GitHub-hosted macOS runner and creates an **unsigned device IPA**. This does not require a paid Apple Developer membership.

1. Create a new GitHub repository.
2. Extract this source ZIP and upload all contents, including the `.github` folder.
3. Open the repository on GitHub.
4. Select **Actions**.
5. Select **Build DRUMLAB IPA for Sideloadly**.
6. Select **Run workflow**.
7. Wait for the workflow to finish.
8. Open the completed workflow run and download the artifact named `DRUMLAB-sideloadly-ipa`.
9. Extract the downloaded artifact and use `DRUMLAB-sideloadly.ipa` in Sideloadly.

In Sideloadly, connect the iPad, choose the IPA, enter the Apple ID requested by Sideloadly, and click **Start**. The Apple ID is used to sign the app for installation; do not put Apple credentials or certificates into GitHub.

A free Apple ID generally produces a temporary sideloaded installation that must be refreshed periodically. Sideloadly will show the applicable signing status for your account.

## Hardware notes

USB MIDI requires a compatible iPad USB-C/Lightning adapter and a class-compliant MIDI device. BLE controllers must advertise the standard BLE-MIDI service UUID `03B80E5A-EDE8-4B4A-B5F4-221A8278229D`.

The Linux sandbox cannot run Xcode or sign an iPad app, so the GitHub macOS workflow is provided for the unsigned IPA build step.
