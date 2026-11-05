##                                                                GenshinSlimmer
<p align="center"><img width="512" height="768" alt="fin" src="https://github.com/user-attachments/assets/9813ea66-741a-4f85-ad19-5c33f72a46ff" /></p>
GenshinSlimmer is a utility that helps reclaim disk space by safely replacing pre-rendered cutscene videos, unused audio cache, and duplicate gendered assets with empty "stubs" in Genshin Impact.


### Version

- **Current script version: v13**

### What's new in v13 (2026 Nov) - 7.2 Support, Modern Dark GUI, Split Snezhnaya Options & Launcher pkg_version Sync
- **New Modern Dark GUI (`GenshinSlimmer_GUI.ps1`):** A full WPF dark-themed graphical interface alongside the classic CLI script (`GenshinSlimmer.ps1`). Includes live category cards with file counts and size badges, one-click 7.2-safe presets (`Up to 7.1 + Boy`, `Up to 7.1 + Girl`, `Up to 7.1 (No Gender)`), live Manifest & Launcher `pkg_version` sync counters, an inline Revision (`R`) editor, Unlock/Restore controls, LZX compression launcher, and an activity log. Shares `path.ini` with the CLI.
- **Split Snezhnaya Options (`[8]` for 7.0–7.1 & `[8b]` for 7.2):**
  - **`[8]` Snezhnaya 7.0–7.1 (Up to 7.1 AQ — 3.93 GB):** Stubs all 17 Snezhnaya cutscenes from 7.0 and 7.1 (`AQ7008` through `AQ7020`) while keeping all 7.2 Archon Quest cutscenes intact.
  - **`[8b]` Snezhnaya 7.2 (7.2 AQ — 0.49 GB):** Dedicated option for the 5 new 7.2 Archon Quest cutscenes (`AQ7023`, `AQ7025`, `AQ7031`) once you have finished 7.2.
  - **Safe Bulk Stubbing (`[0]` / `[B]` / `[G]`):** Bulk options now stub everything **up to 7.1** (including Snezhnaya 7.0–7.1) and intentionally exclude 7.2 AQ cutscenes, so players can reclaim ~40 GB immediately after updating to 7.2 without waiting to finish the new Archon Quest.
- **Launcher `pkg_version` Sync (`[P]`, EXPERIMENTAL):** The HoYoPlay launcher validates the game folder against `pkg_version` in the game root, not against the in-game manifests. `[P]` registers your 0KB stubs there too (`fileSize: 0`, empty-file `md5`/`hash`), in an attempt to stop the launcher's repair/verify from re-downloading them. It is opt-in, keeps a `pkg_version.bak`, can be reverted from the same menu, and is also reverted automatically per file when you use `[U]` -> `[2]`. See [Major updates & the HoYoPlay launcher](#major-updates--the-hoyoplay-launcher-read-before-a-big-patch) for what is and is not known.
- **Verified on 7.2:** All 280 cutscene videos shipped in 7.2 (including the new `Cs_ZD_AQ70xx` Snezhnaya chapters and `Video_Reunion_72`) are covered, and the manifest format (`remoteName` / `md5` / `hash` / `fileSize`) and the empty-file hash are unchanged.
- **QoL (community contribution):** Added the Prologue `Cs_102*` cutscenes (Mondstadt category) and `*Backstory*` cutscenes (Events & Misc category).
- **Backups no longer go stale:** `res_versions_persist.bak` (and the other manifest `.bak` files) are now refreshed whenever the live manifest is pristine, instead of being created only once. Previously the backup could stay at an older game version across a major update.
- **Supported Regions:** Mondstadt, Liyue, Inazuma, Sumeru, Fontaine, Natlan, Nod-Krai, Snezhnaya 7.0–7.1 (`[8]`), and Snezhnaya 7.2 (`[8b]`).


### What's new in v12 (2026 Oct 30) - 7.1 Compatibility & Multi-Manifest Engine
- **7.1 Strict Hash Verification Fix:** Patches the `"hash"` field (`ef46db3751d8e999`, 0-byte hash) alongside `"fileSize": 0` and `"md5": "d41d8cd98f00b204e9800998ecf8427e"`, bypassing 7.1's strict hash integrity checks that triggered re-downloads.
- **Path-Robust Suffix Matching:** Matches `remoteName` entries by filename suffix, gracefully handling `VideoAssets/` and platform prefix variations introduced in 7.1.
- **Multi-Manifest Discovery:** Automatically locates and synchronizes all `*versions*persist*` and `audio_versions*` manifests across `Persistent` data.
- **Snezhnaya 7.1 Cutscenes:** Added coverage for 7.1 cutscenes (`*ZD71*`, `*AQ71*`, `*LQ17*`, `*Snezhnaya*`).


### Major updates & the HoYoPlay launcher (read before a big patch)

The manifest trick covers the **in-game** updater only: it stops the game's "minor update" downloads and the in-game resource check from re-fetching stubbed files. The **HoYoPlay launcher** is a separate check. It validates the game folder against `pkg_version` in the game root (one entry per file with the real `md5`/`fileSize`). On a major patch (7.x -> 7.y) the launcher can flag every stub as damaged and re-download it during its update/repair.

**Experimental (v13):** option `[P]` registers the stubs in `pkg_version` as well. What is known and what is not:
- Known: `pkg_version` lists all 279 videos and the UGC audio files with their real md5/size, so unpatched stubs always fail that check.
- Not known: whether the launcher trusts the local `pkg_version` or downloads a fresh copy from the server when it updates or repairs. If it fetches a fresh copy, `[P]` has no effect on that run (it is harmless; use `[P]` -> `[2]` to revert). Please report what you see.
- A launcher update/repair rewrites `pkg_version`, so run `[P]` again after an update. `pkg_version.bak` is refreshed automatically whenever the file is unpatched, and reverting only touches entries that are still patched, so a stale backup can never downgrade a newer `pkg_version`.
- Close the launcher before using `[P]`, otherwise the file may be locked.

Recommended workflow for a major update (works whether or not `[P]` helps):
1. **Before updating:** run the script, choose **`U`** and then **`[2] Delete Stubs & Restore Manifest`**. This puts the manifest (and `pkg_version`, if you used `[P]`) back to the original values and removes the stubs, so the launcher update and repair run as one clean pass.
2. Let the launcher update the game (and repair/verify if it asks).
3. Launch the game once to the start door, so it generates the new `res_versions_persist`.
4. Run the script again (`0` / `B` / `G` or your chosen options, then `[P]` if you want to keep testing it) to re-stub and re-sync.

If you skip step 1 it still works. The launcher just repairs the stubs during the update and you re-run the script afterwards.

### What's new in v11 (2026 Sep 24) - Major Improvements!
- **Manifest Synchronization Engine (`[M]`):** Completely replaces restrictive Windows ACL Deny locks with direct `res_versions_persist` manifest synchronization. Stubbed 0KB files are registered as valid 0KB assets in the game's own asset database, passing integrity verification instantly and permanently stopping in-game patch re-downloads.
- **In-Game Revision Manager (`[R]`):** View and synchronize internal revision numbers (`res_revision`, `silence_revision`, `data_revision`). Allows players to match the server's R-number during minor hotfixes to completely bypass the 2,580-file resource check.
- **Auto-Elevation (Run as Admin):** The script now automatically detects if it is running with administrator privileges and restarts itself elevated if needed via UAC prompt, with automatic execution policy bypass.
- **Fixed Menu Option Collisions (`[11]` / `[12]`):** Fixed duplicate `B` and `G` menu keys by giving standalone Traveler Gender cutscenes dedicated options (`11` for Boy, `12` for Girl), keeping `B` and `G` for bulk operations.
- **Safe ACL Stripping (`[U]`):** Option to strip legacy `Deny Write, Delete` permissions left over from older versions, preventing `Download error -9908` and startup deadlocks.

### Features
- **Dual Interface (GUI & CLI):** Run `GenshinSlimmer_GUI.ps1` for a modern dark-themed WPF dashboard, or `GenshinSlimmer.ps1` for the classic interactive terminal menu.
- **Universal path finder:** Locates cutscene/video folders automatically given the "Genshin Impact game" folder.
- **Config Persistence:** Saves game path to `path.ini`.
- **Space calculator & Scan Mode:** Reports total space to be reclaimed (MB / GB) and status per region (`[S]`).
- **Anti-Redownload Manifest Engine:** Synchronizes the internal asset database (`res_versions_persist` and variants) to mark 0KB stubs as intact, permanently stopping patcher redownloads.
- **Launcher `pkg_version` Sync (experimental, `[P]`):** Optionally registers stubs in the launcher's own file list as well.
- **NTFS LZX Compression:** Built-in option (`[C]`) using Windows `compact.exe` for extra compression savings on PC.

### Supported Optimization Options
- **Regions:** Mondstadt, Liyue, Inazuma, Sumeru, Fontaine, Natlan, Nod-Krai, Snezhnaya 7.0–7.1 (`[8]`), Snezhnaya 7.2 (`[8b]`)
- **Quests & Events:** Interlude Quests, Legend Quests, Expired Events & Misc Cutscenes
- **UGC Cache:** Miliastra Wonderland / BeyondUGC audio cache
- **Global:** Unused Gender Videos (Aether/Lumine variants)

---
### Screenshots from v13 (Both GUI and Terminal script)
<img width="1020" height="999" alt="image" src="https://github.com/user-attachments/assets/56c1cc01-2226-4939-91ff-022c06654f66" />
<img width="1218" height="931" alt="image" src="https://github.com/user-attachments/assets/10151893-683f-4237-9f70-4ea2a3895984" />

