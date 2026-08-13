##                                                                GenshinSlimmer
<p align="center"><img width="256" height="512" alt="fin" src="https://github.com/user-attachments/assets/9813ea66-741a-4f85-ad19-5c33f72a46ff" /></p>
GenshinSlimmer is a small PowerShell utility that helps reclaim disk space by safely replacing pre-rendered cutscene videos, unused audio cache, and duplicate gendered assets with empty "stubs" in Genshin Impact.

This repository contains a single script which:
- finds the game's asset folders automatically (including `StreamingAssets` and `Persistent` data locations),
- calculates how much space will be freed,
- provides a non-destructive **Scan & Analyze** preview mode (`[S]`),
- stubs & locks files using Windows ACL rules to prevent the launcher from re-downloading deleted assets,
- and requires explicit confirmation before modifying anything.

### Version

- **Current script version: v10**

### What's new in v10 (2026 Aug 14)
- **Snezhnaya Region (ZhìDōng / 7.0):** Added support for Snezhnaya (`*ZD_*`, `*AQ70*`) cutscenes.
- **Inazuma Region:** Restored and expanded dedicated Inazuma region pattern matching (`*Inazuma*`, `*DaoQi*`, `*200803*`, `*200806*`, `*200919*`, `*201104*`, `*200211*`, `*LQ12*`, `*ShougunBoss*`, `*WanYeXian*`).
- **Complete Quest & Event Coverage:** Expanded pattern matching across all Legend Quests (`LQ10` through `LQ16`), World/Side Quests (`WQ...`), and expired event cutscenes (`Cs_EQ_...`, `Cs_FD_...`, `battlePass`, `Reunion`, etc.).
- **Anti Re-download Fix (`.usm.bak` ACL Locking):** Extended ACL permissions (`Deny Write, Delete` + `ReadOnly`) to `.usm.bak` files in `GenshinImpact_Data\Persistent\VideoAssets` to prevent the launcher's verification check from triggering 30GB+ re-downloads.
- **Scan & Analyze Mode (`[S]`):** Interactive mode to scan and display exact disk usage and file status per region and category before stubbing.

### What's new in v9 (2026 May 26)
- **Nod-Krai Region:** Added support for the Nod-Krai region in the video stubbing patterns.
- **LZX Compression & Optimizations:** Added NTFS LZX compression option (`[C]`) for game assets and general optimizations to stubbing and locking logic.

### What's new in v8 (2026 Mar 1)
- **Fast Re-Unlock:** To help release the lock when you actually have new content to download (in-game) - will trigger re-download but it's once!
- **Added Gender-specific Stub All:** No more manually choosing traveler videos after `0. STUB ALL`. (New options `[G]irl`/`[B]oy`, Option `0` still in script.)

### What's new in v7 (2026 Jan 26)
- **Aggressive Locking (ACL):** To prevent the game's launcher from automatically re-downloading deleted files, applies strict Windows Access Control permissions ("Deny Write") to the stubbed files.
- **Unlock & Restore (`[U]`):** Menu option to verify, unlock, and restore permissions. Essential before running major launcher updates.
- **Persistent Folder Support:** Safely handles the `Persistent` folder where newer game assets live.
- **Read-Only Fixes:** Improved handling of file attributes during stubbing.

### What's new in v6
- **Stubbing instead of Deleting:** Replaces large video files with empty (0KB) files rather than deleting them.
- **Smart Path Saving:** Saves game path to `path.ini` so you only enter it once.
- **Dual Folder Scanning:** Scans both `StreamingAssets` and `Persistent` folders.

### Features
- **Universal path finder:** Locates cutscene/video folders automatically given the "Genshin Impact game" folder.
- **Config Persistence:** Saves game path to `path.ini`.
- **Space calculator & Scan Mode:** Reports total space to be reclaimed (MB / GB) and status per region (`[S]`).
- **Selective optimization:** Pick specific regions, clear UGC cache, stub unused MC gender videos, or stub all at once.
- **Anti-Redownload Lock:** Uses ACL Deny rules to keep 0KB files locked against launcher overwrite.
- **NTFS LZX Compression:** Built-in option (`[C]`) using Windows `compact.exe` for extra compression savings.

### Supported Optimization Options
- **Regions:** Mondstadt, Liyue, Inazuma, Sumeru, Fontaine, Natlan, Nod-Krai, Snezhnaya (ZhìDōng)
- **Quests & Events:** Interlude Quests, Legend Quests, Expired Events & Misc Cutscenes
- **UGC Cache:** Miliastra Wonderland / BeyondUGC audio folder
- **Global:** Unused Gender Videos (Aether/Lumine variants)

### Requirements
- Windows 10+ with PowerShell (built-in).
- ExecutionPolicy that allows running scripts, or run PowerShell as administrator and set an appropriate policy for the session:
  - *Example (temporary, session-only):* In an elevated PowerShell: `Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process`

### Usage
1. Download `GenshinSlimmer.ps1` from this repository.
2. Right-click the file and choose **"Run with PowerShell"** — or open PowerShell, navigate to the file location and run:
   ```powershell
   .\GenshinSlimmer.ps1
   ```

### Screenshot of a run example from v9
<img width="632" height="606" alt="image" src="https://github.com/user-attachments/assets/debd065e-a1e9-4808-91ac-6522b79120d2" />
