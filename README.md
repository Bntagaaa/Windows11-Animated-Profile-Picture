# Windows 11 Animated Profile Picture

Use an animated GIF as your Windows 11 account/profile picture with two small `.cmd` scripts. The project redirects Windows `AccountPicture` registry image entries to a GIF and includes a safe rollback mechanism.

> [!IMPORTANT]
> This is an **unofficial Windows workaround**, not a Microsoft-supported animated-profile-picture feature. Windows updates, account-picture sync, or changing your picture from Settings may overwrite the change.

## Credits

The Windows registry workaround that makes transparent and animated profile pictures possible was shared by **PatRyk (@Patrosi73)** on X on September 6, 2026.

Original discovery/post: https://x.com/Patrosi73/status/2096652760494088376

This repository packages that registry technique into an easier `.cmd` workflow with a Windows GIF file picker, automatic SYSTEM-level application, first-run backup preservation, verification, and rollback.

## Files

- **`animatedprofile.cmd`** — choose a GIF, preserve the original registry state, and apply the animated profile picture.
- **`rollback_animatedprofile.cmd`** — restore the original registry state and clean up the animated-profile files.

## Requirements

- Windows 11
- Administrator access
- Windows PowerShell
- Windows Forms / standard Windows file picker
- Task Scheduler service enabled
- A `.gif` file

## Before You Start

It is recommended to first set a normal profile picture from **Settings → Accounts → Your info**. This helps ensure Windows has created the account-picture registry entries for your user.

> [!IMPORTANT]
> The apply script preserves the **first original registry backup**. If `AccountPicture-backup.reg` already exists, later runs do not overwrite it.

## Apply the GIF

1. Download `animatedprofile.cmd`.
2. Right-click it and select **Run as administrator**.
3. The normal Windows file picker will open.
4. Select your `.gif` file.
5. Wait for `[SUCCESS] Animated profile picture applied successfully!`.
6. All Done! You can see the changes on Settings, Start Menu, and Lock screen.

https://github.com/user-attachments/assets/b3daad66-6be4-4cc9-b4a6-768431b60d21

> Note:
> You may need system restart to see changes in the start menu


The selected GIF is copied to:

```text
C:\ProgramData\AnimatedProfilePicture\profile.gif
```

## How It Works

The script gets the SID of the currently logged-in Windows user and works with:

```text
HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AccountPicture\Users\<SID>
```

It redirects the Windows account-picture values below to `profile.gif`:

```text
Image32
Image40
Image48
Image64
Image96
Image192
Image200
Image208
Image240
Image424
Image448
Image1080
```

Because this registry location can require permissions beyond a normal elevated process, the script creates a **temporary Scheduled Task** that runs a local helper as:

```text
NT AUTHORITY\SYSTEM
```

The task is run immediately and then deleted. No permanent service or background task is installed.

## Backup Mechanism

Before modifying the registry for the first time, the apply script exports the original account-picture key to:

```text
C:\ProgramData\AnimatedProfilePicture\AccountPicture-backup.reg
```

This `.reg` file contains the original state of:

```text
HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\AccountPicture\Users\<SID>
```

Windows exports the file in Unicode format. The apply script checks whether the backup already exists; if it does, **it is not overwritten**. This means you can change the GIF later without replacing the original pre-GIF backup.

Keep `AccountPicture-backup.reg` if you want automatic rollback.

## Roll Back

1. Run  `rollback_animatedprofile.cmd`. as administrator.

## Files Created

During use, this folder is used:

```text
C:\ProgramData\AnimatedProfilePicture\
├── profile.gif
├── apply.cmd
├── AccountPicture-backup.reg
└── AccountPicture-animated-state.reg
```

Temporary helper files and Scheduled Tasks are removed when they are no longer needed. The registry backups are retained for safety.

## Troubleshooting

**Script says it is not Administrator** — Right-click the `.cmd` file and choose **Run as administrator**.

**File picker does not open** — Make sure Windows PowerShell is available. The picker uses `System.Windows.Forms.OpenFileDialog`.

**`Image1080` was not found** — The apply script uses this value as its final verification. Check the registry output shown by the script and make sure Task Scheduler was able to run the helper as SYSTEM.

**Rollback says the backup is missing** — Do not delete `C:\ProgramData\AnimatedProfilePicture\AccountPicture-backup.reg` before rollback.

**Rollback reports a different SID** — Run rollback from the same Windows user account that originally created the backup.

**GIF is static in some Windows surfaces** — Not every Windows component is guaranteed to animate the account image. Try signing out/in or restarting Windows. Some surfaces may cache or render a static frame.

## Security Notes

These scripts require Administrator permission and temporarily execute a local helper as SYSTEM. Review the scripts before running them. They modify the current user's Windows account-picture registry values and store the selected GIF under `C:\ProgramData\AnimatedProfilePicture`.

## Cleanup

The recommended uninstall path is to run `rollback_animatedprofile.cmd` first. Once rollback succeeds, you can manually delete:

```text
C:\ProgramData\AnimatedProfilePicture
```

if you no longer want to keep the safety backups.

Do **not** delete that folder before rollback if you still need `AccountPicture-backup.reg`.

## Disclaimer

Use this project at your own risk. It modifies Windows registry values and relies on Windows behavior that is not officially documented as an animated-profile-picture feature.
