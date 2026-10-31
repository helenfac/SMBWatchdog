# SMB Watchdog

A native macOS menu-bar app that checks an SMB mount every 20 seconds and asks Finder to reconnect if the share is unavailable. Set your own SMB address in Settings; the initial placeholder is `smb://server/share`.

The app uses macOS filesystem metadata to confirm that the exact `/Volumes/<share>` path is mounted as `smbfs`, attempts a directory listing with a five-second timeout, and verifies that `smbutil` can report the SMB share. When the share is unavailable, it opens the SMB URL through macOS so Finder can use credentials saved in Keychain or prompt for sign-in. Credentials are not stored by SMB Watchdog.

Reconnect attempts are limited to once per minute unless **Reconnect Now** is selected. If macOS is not already configured to authenticate to the share, sign in through Finder and save the credentials in Keychain before relying on unattended reconnects.

## Build and run

Requires macOS 13 or later and Swift 5.9 or later. The build script creates a universal app for Intel and Apple silicon Macs.

```sh
swift test
bash ./build-app.sh
open .build/SMBWatchdog.app
```

In the menu-bar app's **Settings**, edit the SMB address if needed and choose **Enable Open at Login** to keep monitoring after you sign in.

The first share name determines the mount point the app monitors. For example, `smb://server/Team%20Files` is monitored at `/Volumes/Team Files`.
