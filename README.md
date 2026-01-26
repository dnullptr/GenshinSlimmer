
##                                                                GenshinSlimmer
<p align="center"><img width="256" height="512" alt="fin" src="https://github.com/user-attachments/assets/9813ea66-741a-4f85-ad19-5c33f72a46ff" /></p>
GenshinSlimmer is a small PowerShell utility that helps reclaim disk space by safely replacing pre-rendered cutscene videos, unused audio cache, and duplicate gendered assets with empty "stubs" in Genshin Impact.



This repository contains a single script which:
- finds the game's asset folders automatically (including new `Persistent` data locations),
- calculates how much space will be freed,
- shows a preview of files that would be optimized,
- and requires explicit confirmation before modifying anything.

### Version


- **Current script version: v7**

### What's new in v7 (2026 Jan 26)
- **Aggressive Locking (ACL):** To prevent the game's launcher from automatically re-downloading the deleted files, this version applies strict Windows Access Control permissions ("Deny Write") to the stubbed files. This "locks" the 0KB stubs so the game cannot overwrite them.
- 
- **Unlock & Restore:** A new menu option allows you to verify, unlock, and delete the locked stubs. This is essential for letting the game "repair" itself before a major version update.
-**Persistent Folder Support:** Safely handles the Persistent folder (where newer game assets live) by using the locking mechanism to bypass integrity checks.
-**Read-Only Fixes:** Improved handling of file attributes to prevent permission errors during the stubbing process.

### What's new in v6
- **Stubbing instead of Deleting:** The tool now replaces large video files with empty (0KB) files rather than deleting them. This ensures the game passes basic file existence checks without re-downloading the assets, while still saving you the disk space.
- **Smart Path Saving:** You only need to paste your game path once. The script now creates a `path.ini` file to remember your installation location for future runs.
- **Dual Folder Scanning:** Now supports the modern Genshin file structure by scanning both the `StreamingAssets` and `Persistent` folders to find all video assets.
- **Read-Only Fix:** Automatically handles files marked as "Read-Only" to prevent "Access Denied" errors during optimization.

### Features
- **Universal path finder:** The script locates the cutscene/video folders automatically when given the "Genshin Impact game" folder.
- **Config Persistence:** Saves your game path to `path.ini` so you don't have to copy-paste it every time.
- **Space calculator:** Reports the total space that will be reclaimed (MB / GB) before any action.
- **Selective optimization:** Pick specific regions to clean, clear UGC cache, stub unused MC gender videos, or do everything at once.
- **Safety-first workflow:** Preview files, confirm selection, and then perform the stubbing operation.

### Supported Optimization Options
- **Regions:** Mondstadt, Liyue, Sumeru, Fontaine, Natlan
- **UGC Cache:** Miliastra Wonderland (BeyondUGC folder)
- **Global:** Unused Gender Videos (Aether/Lumine variants)

*(Note: support is based on the folder structure used by the game. If a region isn't present the script will skip it.)*

### Requirements
- Windows 10+ with PowerShell (built-in).
- ExecutionPolicy that allows running scripts, or run PowerShell as administrator and set an appropriate policy for the session:
  - *Example (temporary, session-only):* In an elevated PowerShell: `Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process`

### Usage
1. Download `GenshinSlimmer.ps1` from this repository.
2. Right-click the file and choose **"Run with PowerShell"** — or open PowerShell, navigate to the file location and run:
   ```powershell
   .\GenshinSlimmer.ps1
### Screenshot of a run example from v6 
<img width="1087" height="695" alt="image" src="https://github.com/user-attachments/assets/3bd9a096-7fbb-4883-a5e4-bfdcff79c66a" />

   
