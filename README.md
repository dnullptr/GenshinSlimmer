
# GenshinSlimmer

GenshinSlimmer is a small PowerShell utility that helps reclaim disk space by safely removing pre-rendered cutscene videos from completed regions in Genshin Impact.

This repository contains a single script which:
- finds the game's video folders automatically after you point it to the main installation directory,
- calculates how much space will be freed,
- shows a preview of files that would be removed,
- and requires explicit confirmation before deleting anything.

Version
- Current script version: v3

What's new in v3
- Optional Milliastra Wonderland audio cleanup: You can now choose to scan for and remove Milliastra Wonderland audio files (these are separate audio assets used by the Milliastra content). This is opt-in and appears as a separate choice in the interactive menu and as a dedicated CLI flag.
- Traveler-specific video removal: If you only use one Traveler (Aether — male, or Lumine — female), v3 lets you optionally remove pre-rendered videos for the Traveler you don't use. This helps reclaim space from redundant Traveler-specific cutscenes while leaving the videos for the Traveler you play.
- Existing safety guarantees remain: full preview, dry-run support, and confirmation are still the default behavior.

Features
- Universal path finder: The script locates the cutscene/video folders when given the "Genshin Impact game" folder.
- Space calculator: Reports the total space that will be reclaimed (MB / GB) before any deletion.
- Selective deletion: Pick one region to clean or remove old videos from all supported regions — now includes Milliastra audio and Traveler-specific videos as optional targets.
- Safety-first workflow: Preview files, confirm selection, and then perform deletion.
- Dry-run friendly: You can preview without deleting to be 100% sure.

Supported regions
- Mondstadt
- Liyue
- Sumeru
- Fontaine
- Natlan

Note on Milliastra and Traveler options
- Milliastra Wonderland audio files: These are optional audio assets; deleting them may remove voice/music cues tied to the Milliastra content. The script will clearly label these files in the preview so you can confirm before any action.
- Traveler videos: Traveler-specific videos are separate pre-rendered cutscenes for Aether or Lumine. If you choose to remove one Traveler's videos, the other Traveler's videos will be preserved. The script will list all files that would be removed so you can verify the selection.

Requirements
- Windows 10+ with PowerShell (built-in).
- ExecutionPolicy that allows running scripts, or run PowerShell as administrator and set an appropriate policy for the session:
  - Example (temporary, session-only): In an elevated PowerShell: Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

Usage
1. Download GenshinSlimmer.ps1 from this repository.
2. Right-click the file and choose "Run with PowerShell" — or open PowerShell, navigate to the file location and run:
   .\GenshinSlimmer.ps1
3. When prompted, paste the path to your "Genshin Impact game" folder. Example:
   C:\Program Files\Genshin Impact\Genshin Impact game
4. Choose the region(s) you want to analyze or delete from the interactive menu. In v3 you will also see optional choices for:
   - Milliastra Wonderland audio files
   - Traveler video cleanup (Aether or Lumine)
5. Review the preview list and the space savings reported.
6. Confirm to delete, or cancel to exit without changes.

Command-line / Non-interactive examples (v3)
- Dry-run (preview only, no deletion):
  .\GenshinSlimmer.ps1 -Path "C:\Program Files\Genshin Impact\Genshin Impact game" -DryRun
- Delete a single region non-interactively with auto-confirm:
  .\GenshinSlimmer.ps1 -Path "C:\Program Files\Genshin Impact\Genshin Impact game" -Region Mondstadt -AutoConfirm
- Delete Milliastra Wonderland audio files (preview first):
  .\GenshinSlimmer.ps1 -Path "C:\Program Files\Genshin Impact\Genshin Impact game" -DryRun -DeleteMilliastraAudio
- Remove videos for the unused Traveler (example: remove Aether files):
  .\GenshinSlimmer.ps1 -Path "C:\Program Files\Genshin Impact\Genshin Impact game" -Traveler Aether -DryRun
- Backup then remove unused Traveler videos with auto-confirm:
  .\GenshinSlimmer.ps1 -Path "C:\Program Files\Genshin Impact\Genshin Impact game" -Traveler Lumine -Backup -AutoConfirm

Available options (v3)
- -Path <string> : Path to the "Genshin Impact game" folder (optional in interactive mode).
- -Region <string|All> : Region name (e.g., Mondstadt, Liyue) or All to target all supported regions.
- -DryRun : Show what would be deleted without removing files.
- -AutoConfirm : Skip interactive confirmation and perform removal (use with caution; recommended to use with -Backup).
- -Backup : Create a timestamped backup (zip) or move to Recycle Bin before deleting files.
- -LogFile <string> : Write detailed output and actions to a log file.
- -ExcludePatterns <string[]> : File patterns to exclude from deletion.
- -DeleteMilliastraAudio : Scan for and include Milliastra Wonderland audio files in the preview and deletion (opt-in).
- -Traveler <Aether|Lumine|Both> : Select which Traveler's videos to include in the target set. Choosing Aether or Lumine removes videos for that Traveler (use DryRun first).
- -WhatIf : PowerShell-compatible WhatIf behavior where implemented.

Behavior and safety notes
- The script targets pre-rendered cutscene / video and named audio assets. In general, the game will skip missing videos and fall back to in-engine sequences. However, deleting files is irreversible without a backup.
- The script always shows a full preview when run interactively and requires manual confirmation before performing deletions (unless -AutoConfirm is used).
- Deleting Milliastra audio or a Traveler's videos is optional and clearly labeled in the preview. Use -DryRun to confirm exactly which files will be affected.
- Backup mode is recommended for first runs: the script can create a .zip of selected files or attempt to move them to the Recycle Bin if the required modules/permissions are available.

How it works (brief)
- The script finds common video and named audio asset paths relative to the installation folder you provide.
- It enumerates files in known directories (regions, traveler folders, Milliastra audio directories), sums file sizes, and displays the list and total space releasable.
- After your confirmation it removes the selected files or archives them when backup is enabled.

Troubleshooting
- If the script can't find your game folder, double-check you provided the path to "Genshin Impact game" (not just the launcher).
- If a region or optional item (Milliastra audio, Traveler videos) doesn't appear, the game may not have downloaded those assets yet or uses a different folder layout for your installation. Inspect the game's installation directory to locate the video's or audio's subfolders.
- If PowerShell refuses to run the script, verify your ExecutionPolicy or run PowerShell as administrator and use the session bypass shown above.
- If backup to Recycle Bin fails, ensure you have the required module or use the .zip backup option instead.
- Review the log file (if specified) for details on which files were scanned and any errors encountered.

Contributing
- Found a bug or want a feature? Open an issue or submit a PR. Small improvements like better detection of custom install locations, additional safety checks, or updated region mappings are welcome.

Changelog (v3)
- Added opt-in Milliastra Wonderland audio deletion.
- Added Traveler-specific video removal for unused Traveler (Aether/Lumine).
- Non-interactive automation flags (-AutoConfirm, -DryRun, -LogFile).
- Backup option (zip or Recycle Bin).
- Additional safety checks and exclude patterns.
- Performance improvements and progress feedback.

Disclaimer
This script deletes game files. While it is intended to be safe for video and named audio assets (the game typically skips missing cutscene files), always confirm the preview and consider backing up files before deletion. Use at your own risk.

<img width="1243" height="1080" alt="image" src="https://github.com/user-attachments/assets/9e994981-e8d3-4502-86be-6256a5cc7d2b" />
