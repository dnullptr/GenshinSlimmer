```markdown
# GenshinSlimmer

GenshinSlimmer is a small PowerShell utility that helps reclaim disk space by safely removing pre-rendered cutscene videos from completed regions in Genshin Impact.

This repository contains a single script (Cleanup.ps1) which:
- finds the game's video folders automatically after you point it to the main installation directory,
- calculates how much space will be freed,
- shows a preview of files that would be removed,
- and requires explicit confirmation before deleting anything.

Features
- Universal path finder: The script locates the cutscene/video folders when given the "Genshin Impact game" folder.
- Space calculator: Reports the total space that will be reclaimed (MB / GB) before any deletion.
- Selective deletion: Pick one region to clean or remove old videos from all supported regions.
- Safety-first workflow: Preview files, confirm selection, and then perform deletion.
- Dry-run friendly: You can preview without deleting to be 100% sure.

Supported regions
- Mondstadt
- Liyue
- Sumeru
- Fontaine
- Natlan

(Note: support is based on the folder structure used by the game. If a region isn't present the script will skip it.)

Requirements
- Windows 10+ with PowerShell (built-in).
- ExecutionPolicy that allows running scripts, or run PowerShell as administrator and set an appropriate policy for the session:
  - Example (temporary, session-only): In an elevated PowerShell: Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

Usage
1. Download Cleanup.ps1 from this repository.
2. Right-click the file and choose "Run with PowerShell" — or open PowerShell, navigate to the file location and run:
   .\Cleanup.ps1
3. When prompted, paste the path to your "Genshin Impact game" folder. Example:
   C:\Program Files\Genshin Impact\Genshin Impact game
4. Choose the region(s) you want to analyze or delete from the interactive menu.
5. Review the preview list and the space savings reported.
6. Confirm to delete, or cancel to exit without changes.

Behavior and safety notes
- The script targets pre-rendered cutscene / video assets. In general, the game will skip missing videos and fall back to in-engine sequences. However, deleting files is irreversible without a backup.
- The script always shows a full preview and requires manual confirmation before performing deletions.
- If you are unsure, use the preview/dry-run option and back up the folders to an external drive before deleting.

How it works (brief)
- The script finds common video asset paths relative to the installation folder you provide.
- It enumerates files in known video directories, sums file sizes, and displays the list and total space releasable.
- After your confirmation it removes the selected files.

Troubleshooting
- If the script can't find your game folder, double-check you provided the path to "Genshin Impact game" (not just the launcher).
- If a region doesn't appear, the game may not have downloaded those assets yet or uses a different folder layout for your installation. Inspect the game's installation directory to locate the video's subfolders.
- If PowerShell refuses to run the script, verify your ExecutionPolicy or run PowerShell as administrator and use the session bypass shown above.

Contributing
- Found a bug or want a feature? Open an issue or submit a PR. Small improvements like better detection of custom install locations, additional safety checks, or region mappings are welcome.

Disclaimer
This script deletes game files. While it is intended to be safe for video assets (the game typically skips missing cutscene files), always confirm the preview and consider backing up files before deletion. Use at your own risk.


```
