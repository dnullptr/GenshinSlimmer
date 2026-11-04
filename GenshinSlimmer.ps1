<#
    GenshinSlimmer v12
    - Stubs cutscene videos and audio cache to 0KB to save 30-40+ GB of disk space.
    - Manifest Synchronization Engine: Directly synchronizes Genshin's internal
      asset databases (res_versions_persist + audio/silence/data persist variants)
      so the in-game patcher validates 0KB stubs as 100% intact, stopping
      minor update re-downloads (fixed for 7.1 strict hash validation).
    - v12 fix for 7.1: also patches the "hash" field (empty-file hash
      ef46db3751d8e999, same as base_revision), matches remoteName by filename
      suffix (handles VideoAssets/ prefix changes), and scans ALL *versions*persist*
      manifests (res + audio) instead of only res_versions_persist.
    - Eliminates restrictive ACL Deny locks (which caused Error -9908 and download loops).
    - Revision Manager: View and sync R/S/D revisions (res_revision, silence_revision, data_revision).
    - Supports all regions: Mondstadt, Liyue, Inazuma, Sumeru, Fontaine, Natlan, Nod-Krai, Snezhnaya (ZhìDōng / AQ70 / AQ71 - 7.1).
    - Dedicated gender options: Boy Traveler only, Girl Traveler only, or bulk.
    - Handles both .usm and .usm.bak files across StreamingAssets and Persistent folders.
    - Includes interactive game folder scan/analysis mode.
    - Includes LZX NTFS compression.
    
    Author: dnullptr
#>

# --- SELF-ELEVATION (REQUIRE ADMIN) ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Elevating privileges to Administrator..." -ForegroundColor Yellow
    $scriptPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Definition }
    if ($scriptPath) {
        try {
            $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
            Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Verb RunAs
            exit
        } catch {
            Write-Host "Failed to elevate automatically: $_" -ForegroundColor Red
            Write-Host "Please right-click GenshinSlimmer.ps1 and choose 'Run as administrator'." -ForegroundColor Yellow
            Read-Host "Press Enter to exit..."
            exit
        }
    }
}

# --- CONFIGURATION ---
$VideoSearchPaths = @(
    "GenshinImpact_Data\StreamingAssets\VideoAssets\StandaloneWindows64",
    "GenshinImpact_Data\Persistent\VideoAssets\StandaloneWindows64"
)
$UGCSearchPaths = @(
    "GenshinImpact_Data\StreamingAssets\AudioAssets\BeyondUGC",
    "GenshinImpact_Data\Persistent\AudioAssets\BeyondUGC"
)

function Get-GamePath {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "   GenshinSlimmer v12" -ForegroundColor Yellow
    Write-Host "   Created by dnullptr" -ForegroundColor DarkGray
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""

    $ConfigPath = Join-Path $PSScriptRoot "path.ini"
    $validPathFound = $false

    if (Test-Path $ConfigPath) {
        $SavedPath = Get-Content -Path $ConfigPath -Raw -ErrorAction SilentlyContinue
        if ($SavedPath) {
            $SavedPath = $SavedPath.Trim().Replace('"', '')
            $CheckPath = Join-Path -Path $SavedPath -ChildPath "GenshinImpact_Data"
            
            if (Test-Path $CheckPath) {
                Write-Host "Found saved path in path.ini:" -ForegroundColor White
                Write-Host "$SavedPath" -ForegroundColor DarkGray
                Set-Location $SavedPath
                $validPathFound = $true
                Start-Sleep -Seconds 1
                return 
            }
        }
    }

    if (-not $validPathFound) {
        Write-Host "Please paste the path to your 'Genshin Impact game' folder." -ForegroundColor White
        Write-Host "Example: C:\Program Files\HoYoPlay\games\Genshin Impact game" -ForegroundColor Gray
        Write-Host ""
    }

    while (-not $validPathFound) {
        $userInput = Read-Host "Paste Path Here"
        $userInput = $userInput -replace '"', ''
        $CheckPath = Join-Path -Path $userInput -ChildPath "GenshinImpact_Data"

        if (Test-Path $CheckPath) {
            Write-Host "`nFolder found! Saving config..." -ForegroundColor Green
            try { $userInput | Out-File -FilePath $ConfigPath -Encoding utf8 -Force } catch {}
            Set-Location $userInput
            $validPathFound = $true
            Start-Sleep -Seconds 1
        } else {
            Write-Host "`nCould not find 'GenshinImpact_Data'." -ForegroundColor Red
        }
    }
}

function Remove-FileLock {
    param ([string]$Path)
    try {
        $file = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
        if ($null -eq $file) { return }
        if ($file.IsReadOnly) { $file.IsReadOnly = $false }
        $acl = $file.GetAccessControl()
        $rules = $acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier])
        $modified = $false
        foreach ($r in $rules) {
            if ($r.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Deny) {
                $acl.RemoveAccessRuleSpecific($r)
                $modified = $true
            }
        }
        if ($modified) {
            $file.SetAccessControl($acl)
        }
    } catch {}
}

function Get-ManifestCandidates {
    param ([string]$GameRoot)
    $candidates = @()
    $persistentDir = Join-Path $GameRoot "GenshinImpact_Data\Persistent"
    $defaultPersist = Join-Path $persistentDir "res_versions_persist"
    if (Test-Path -LiteralPath $defaultPersist) { $candidates += $defaultPersist }
    if (Test-Path -LiteralPath $persistentDir) {
        try {
            $found = Get-ChildItem -Path $persistentDir -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "*versions*" -and $_.Name -like "*persist*" -and $_.Name -notlike "*.bak" -and $_.FullName -notlike "*.bak" }
            foreach ($f in $found) {
                if ($candidates -notcontains $f.FullName) { $candidates += $f.FullName }
            }
            # Also catch audio manifest variants that may not contain "persist" in name
            # e.g. Persistent/AudioAssets/audio_versions, Persistent/audio_lang_*/...
            $audioFound = Get-ChildItem -Path $persistentDir -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { ($_.Name -like "audio_versions*" -or $_.Name -like "*audio*versions*") -and $_.Name -notlike "*.bak" -and $_.FullName -notlike "*.bak" }
            foreach ($f in $audioFound) {
                if ($candidates -notcontains $f.FullName) { $candidates += $f.FullName }
            }
        } catch {}
    }
    return @($candidates | Select-Object -Unique)
}

function Get-StubbedFileMap {
    param ([string]$GameRoot)
    # Returns hashtable with two lookup styles:
    #  - Exact keys "StandaloneWindows64/<file>" and "BeyondUGC/<file>" (legacy)
    #  - Filename-only keys "<file>" for suffix matching (7.1 path-prefix robust)
    $exactMap = @{}
    $nameMap = @{}
    foreach ($relPath in $VideoSearchPaths) {
        $fullPath = Join-Path $GameRoot $relPath
        if (Test-Path $fullPath) {
            $files = Get-ChildItem -Path $fullPath -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -eq 0 }
            # Fallback: also accept <1KB for legacy stubs created by older versions
            if (-not $files) {
                $files = Get-ChildItem -Path $fullPath -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -lt 1024 }
            }
            foreach ($f in $files) {
                $cleanName = if ($f.Name -like "*.bak") { $f.Name.Substring(0, $f.Name.Length - 4) } else { $f.Name }
                $exactMap["StandaloneWindows64/$cleanName"] = $true
                $nameMap[$cleanName] = $true
            }
        }
    }
    foreach ($relPath in $UGCSearchPaths) {
        $fullPath = Join-Path $GameRoot $relPath
        if (Test-Path $fullPath) {
            $files = Get-ChildItem -Path $fullPath -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -eq 0 }
            if (-not $files) {
                $files = Get-ChildItem -Path $fullPath -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -lt 1024 }
            }
            foreach ($f in $files) {
                $cleanName = if ($f.Name -like "*.bak") { $f.Name.Substring(0, $f.Name.Length - 4) } else { $f.Name }
                $exactMap["BeyondUGC/$cleanName"] = $true
                $nameMap[$cleanName] = $true
            }
        }
    }
    return @{ Exact = $exactMap; Names = $nameMap }
}

function Test-ManifestMatch {
    param ([string]$RemoteName, [hashtable]$ExactMap, [hashtable]$NameMap)
    if ($ExactMap.ContainsKey($RemoteName)) { return $true }
    # Suffix match: compare filename only (handles "VideoAssets/StandaloneWindows64/x.usm"
    # vs "StandaloneWindows64/x.usm" changes in 7.1, plus case variations)
    $fileName = $RemoteName.Split('/')[-1]
    if ($NameMap.ContainsKey($fileName)) { return $true }
    # Case-insensitive fallback
    foreach ($k in $NameMap.Keys) {
        if ($k -ieq $fileName) { return $true }
    }
    return $false
}

function Sync-Manifest {
    param ([switch]$Silent)

    $CurrentLocation = (Get-Location).ProviderPath
    $manifestPaths = @(Get-ManifestCandidates -GameRoot $CurrentLocation)

    if (-not $manifestPaths -or $manifestPaths.Count -eq 0) {
        $persistPath = Join-Path $CurrentLocation "GenshinImpact_Data\Persistent\res_versions_persist"
        if (-not $Silent) {
            Write-Host "`nCould not find 'res_versions_persist' at:" -ForegroundColor Yellow
            Write-Host "$persistPath" -ForegroundColor DarkGray
            Write-Host "Launch the game once to the start door so it creates this file." -ForegroundColor Gray
            Read-Host "Press Enter to continue..."
        }
        return 0
    }

    if (-not $Silent) {
        Write-Host "`nScanning stubbed files to synchronize manifest..." -ForegroundColor Cyan
    }

    # Map all 0-byte (stubbed) files
    $maps = Get-StubbedFileMap -GameRoot $CurrentLocation
    $stubbedMap = $maps.Exact
    $stubbedNames = $maps.Names

    if ($stubbedNames.Count -eq 0 -and -not $Silent) {
        Write-Host "No stubbed (0KB) files found. Stub files first, then sync." -ForegroundColor Yellow
    }

    # Empty-file fingerprints (md5 of 0 bytes + hash of 0 bytes as seen in base_revision).
    # 7.1 validates "hash" in addition to "fileSize"/"md5"; leaving it stale triggers redownload.
    $emptyMd5 = "d41d8cd98f00b204e9800998ecf8427e"
    $emptyHash = "ef46db3751d8e999"

    $totalPatched = 0
    $perFileCounts = @{}

    foreach ($persistPath in $manifestPaths) {
        $lines = Get-Content -LiteralPath $persistPath -Encoding utf8
        $output = [System.Collections.Generic.List[string]]::new($lines.Count)
        $patchedCount = 0

        foreach ($line in $lines) {
            $matched = $false
            if ($line -match '"remoteName":\s*"([^"]+)"') {
                $remoteName = $matches[1]
                if (Test-ManifestMatch -RemoteName $remoteName -ExactMap $stubbedMap -NameMap $stubbedNames) {
                    $newLine = $line -replace '"fileSize":\s*\d+', '"fileSize": 0' `
                                     -replace '"md5":\s*"[^"]+"', "`"md5`": `"$emptyMd5`""
                    # Patch hash as well when present (7.1 strict check). If no hash field, this is a no-op.
                    if ($newLine -match '"hash":') {
                        $newLine = $newLine -replace '"hash":\s*"[^"]+"', "`"hash`": `"$emptyHash`""
                    }
                    $output.Add($newLine)
                    $patchedCount++
                    $matched = $true
                }
            }
            if (-not $matched) {
                $output.Add($line)
            }
        }

        # Backup original manifest once
        $backupPath = "$persistPath.bak"
        if (-not (Test-Path $backupPath)) {
            try { Copy-Item -LiteralPath $persistPath -Destination $backupPath -Force } catch {}
        }

        # Ensure file is writable (strip ReadOnly attribute and Deny rules)
        Remove-FileLock -Path $persistPath
        try {
            $persistItem = Get-Item -LiteralPath $persistPath -Force -ErrorAction SilentlyContinue
            if ($persistItem -and $persistItem.IsReadOnly) { $persistItem.IsReadOnly = $false }
        } catch {}

        try {
            [System.IO.File]::WriteAllLines($persistPath, $output, [System.Text.UTF8Encoding]::new($false))
        } catch {
            Write-Host "`nError writing to $persistPath : $_" -ForegroundColor Red
            if (-not $Silent) { Read-Host "Press Enter to continue..." }
            continue
        }
        $perFileCounts[$persistPath] = $patchedCount
        $totalPatched += $patchedCount
    }

    if (-not $Silent) {
        foreach ($kv in $perFileCounts.GetEnumerator()) {
            Write-Host ("  {0} : {1} entries" -f (Split-Path $kv.Key -Leaf), $kv.Value) -ForegroundColor DarkGray
        }
        if ($totalPatched -eq 0 -and $stubbedNames.Count -gt 0) {
            Write-Host "`nWARNING: Found $($stubbedNames.Count) stubbed files but patched 0 manifest entries." -ForegroundColor Yellow
            Write-Host "The manifest remoteName paths may have changed in 7.1." -ForegroundColor Yellow
            Write-Host "Sample stubbed names:" -ForegroundColor DarkGray
            $stubbedNames.Keys | Select-Object -First 5 | ForEach-Object { Write-Host "  - $_" -ForegroundColor DarkGray }
            Write-Host "Check res_versions_persist remoteName format manually." -ForegroundColor DarkGray
        } else {
            Write-Host "Success! Synchronized $totalPatched stubbed assets across $($manifestPaths.Count) manifest(s)." -ForegroundColor Green
            Write-Host "The in-game patcher will now treat these 0KB stubs as 100% valid." -ForegroundColor Cyan
        }
        Read-Host "Press Enter to return to menu..."
    }

    return $totalPatched
}

function Restore-Manifest {
    param ([array]$FileNamesToRestore)

    $CurrentLocation = (Get-Location).ProviderPath
    $manifestPaths = @(Get-ManifestCandidates -GameRoot $CurrentLocation)
    if (-not $manifestPaths -or $manifestPaths.Count -eq 0) { return 0 }

    # Build global lookup from ALL streaming manifests (res + audio), keyed by
    # exact remoteName AND by filename for 7.1 path-robust restore.
    $lookupExact = @{}
    $lookupByName = @{}
    $streamingDir = Join-Path $CurrentLocation "GenshinImpact_Data\StreamingAssets"
    if (Test-Path -LiteralPath $streamingDir) {
        try {
            $streamingManifests = Get-ChildItem -Path $streamingDir -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { ($_.Name -like "*versions*streaming*" -or $_.Name -like "res_versions_streaming" -or $_.Name -like "audio_versions*") -and $_.Name -notlike "*.bak" -and $_.FullName -notlike "*.bak" }
            # Always include the classic res_versions_streaming even if filter misses it
            $classicStreaming = Join-Path $CurrentLocation "GenshinImpact_Data\StreamingAssets\res_versions_streaming"
            $allStreaming = @($streamingManifests.FullName) + @($classicStreaming) | Select-Object -Unique
            foreach ($sp in $allStreaming) {
                if (-not $sp -or -not (Test-Path -LiteralPath $sp)) { continue }
                $sLines = Get-Content -LiteralPath $sp -Encoding utf8 -ErrorAction SilentlyContinue
                foreach ($line in $sLines) {
                    if ($line -match '"remoteName":\s*"([^"]+)"') {
                        $rn = $matches[1]
                        if (-not $lookupExact.ContainsKey($rn)) { $lookupExact[$rn] = $line }
                        $fn = $rn.Split('/')[-1]
                        if (-not $lookupByName.ContainsKey($fn)) { $lookupByName[$fn] = $line }
                    }
                }
            }
        } catch {}
    }

    if ($lookupExact.Count -eq 0) { return 0 }

    $restoreNames = @{}
    foreach ($fn in $FileNamesToRestore) {
        $cleanName = if ($fn -like "*.bak") { $fn.Substring(0, $fn.Length - 4) } else { $fn }
        $restoreNames[$cleanName] = $true
    }

    $totalRestored = 0
    foreach ($persistPath in $manifestPaths) {
        $persistLines = Get-Content -LiteralPath $persistPath -Encoding utf8
        $output = [System.Collections.Generic.List[string]]::new($persistLines.Count)
        $restoredCount = 0

        foreach ($line in $persistLines) {
            $matched = $false
            if ($line -match '"remoteName":\s*"([^"]+)"') {
                $remoteName = $matches[1]
                $fileName = $remoteName.Split('/')[-1]
                $shouldRestore = $restoreNames.ContainsKey($fileName)
                if ($shouldRestore) {
                    if ($lookupExact.ContainsKey($remoteName)) {
                        $output.Add($lookupExact[$remoteName])
                        $restoredCount++
                        $matched = $true
                    } elseif ($lookupByName.ContainsKey($fileName)) {
                        $output.Add($lookupByName[$fileName])
                        $restoredCount++
                        $matched = $true
                    }
                }
            }
            if (-not $matched) {
                $output.Add($line)
            }
        }

        # Ensure file is writable (strip ReadOnly attribute and Deny rules)
        Remove-FileLock -Path $persistPath
        try {
            $persistItem = Get-Item -LiteralPath $persistPath -Force -ErrorAction SilentlyContinue
            if ($persistItem -and $persistItem.IsReadOnly) { $persistItem.IsReadOnly = $false }
        } catch {}

        try {
            [System.IO.File]::WriteAllLines($persistPath, $output, [System.Text.UTF8Encoding]::new($false))
        } catch {
            Write-Host "`nError writing to $persistPath : $_" -ForegroundColor Red
            continue
        }
        $totalRestored += $restoredCount
    }
    return $totalRestored
}

# --- DEFINE PATTERNS ---
$PatternsMondstadt = @("*Mengde*", "*MDAQ*", "*Venti*", "*WDLQ*", "*Ambor*", "*Cs_102*")
$PatternsLiyue     = @("*LiYue*", "*LYAQ*", "*LY_*", "*LQ10*", "*LQ11*", "*XiaoPersonal*", "*ShenheBattle*", "*YunjinOpera*")
$PatternsInazuma   = @("*Inazuma*", "*DaoQi*", "*200803*", "*200806*", "*200919*", "*201104*", "*200211*", "*LQ12*", "*ShougunBoss*", "*WanYeXian*")
$PatternsSumeru    = @("*Sumeru*", "*Xm_*", "*LQ13*")
$PatternsFontaine  = @("*Fontaine*", "*LQ14*")
$PatternsNatlan    = @("*Natlan*", "*LQ15*")
$PatternsNodKrai   = @("*NodKrai*", "*NK_*", "*LQ16*")
$PatternsSnezhnaya = @("*ZD_*", "*ZD71*", "*AQ70*", "*AQ71*", "*LQ17*", "*Snezhnaya*") # Snezhnaya (ZhìDōng / 至冬) - 7.0 AQ70 + 7.1 AQ71 (A Rekviem for the Underworld)
$PatternsMisc      = @("*battlePass*", "*ChangeWeather*", "*EQ*", "*FD_*", "*GY*", "*Memories*", "*Reunion*", "*ShieldingResources*", "*Backstory*")
$PatternsBoy       = @("*Boy*.usm*", "*PlayerBoy*.usm*")
$PatternsGirl      = @("*Girl*.usm*", "*PlayerGirl*.usm*")

$AllRegionPatterns = $PatternsMondstadt + $PatternsLiyue + $PatternsInazuma + $PatternsSumeru + $PatternsFontaine + $PatternsNatlan + $PatternsNodKrai + $PatternsSnezhnaya + $PatternsMisc

function Get-MatchingFiles {
    param ([array]$RelativePaths, [array]$Patterns)
    $AllFiles = @()
    $CurrentLocation = Get-Location

    foreach ($path in $RelativePaths) {
        $fullPath = Join-Path $CurrentLocation $path
        if (Test-Path $fullPath) {
            $files = Get-ChildItem -Path $fullPath -File | Where-Object { 
                $name = $_.Name
                $matched = $false
                foreach ($pattern in $Patterns) { if ($name -like $pattern) { $matched = $true; break } }
                $matched
            }
            $AllFiles += $files
        }
    }
    return $AllFiles
}

function Process-Scan {
    $CurrentLocation = Get-Location
    Write-Host "`n=========================================" -ForegroundColor Cyan
    Write-Host "   Genshin Impact Data Scan & Analysis" -ForegroundColor Yellow
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Scanning game directory: $CurrentLocation" -ForegroundColor DarkGray
    Write-Host ""

    $categories = [ordered]@{
        "1. Mondstadt"           = $PatternsMondstadt
        "2. Liyue"               = $PatternsLiyue
        "3. Inazuma"             = $PatternsInazuma
        "4. Sumeru"              = $PatternsSumeru
        "5. Fontaine"            = $PatternsFontaine
        "6. Natlan"              = $PatternsNatlan
        "7. Nod-Krai"            = $PatternsNodKrai
        "8. Snezhnaya (ZhìDōng)"  = $PatternsSnezhnaya
        "9. Events & Misc"       = $PatternsMisc
        "10. UGC Cache"          = @("*")
    }

    $totalGlobalBytes = 0
    $totalGlobalCount = 0

    foreach ($cat in $categories.Keys) {
        $paths = if ($cat -like "*UGC*") { $UGCSearchPaths } else { $VideoSearchPaths }
        $files = Get-MatchingFiles $paths $categories[$cat]
        
        $stats = $files | Measure-Object -Property Length -Sum
        $count = $files.Count
        $bytes = if ($stats.Sum) { $stats.Sum } else { 0 }
        $gb = [math]::Round($bytes / 1GB, 2)

        $totalGlobalBytes += $bytes
        $totalGlobalCount += $count

        $statusStr = if ($bytes -eq 0 -and $count -gt 0) { "[STUBBED]" } else { "$gb GB" }
        $color = if ($bytes -eq 0 -and $count -gt 0) { "Green" } elseif ($count -eq 0) { "DarkGray" } else { "Cyan" }

        Write-Host ("{0,-25} : {1,4} files | {2,10}" -f $cat, $count, $statusStr) -ForegroundColor $color
    }

    Write-Host "-----------------------------------------" -ForegroundColor DarkGray
    $boyFiles  = Get-MatchingFiles $VideoSearchPaths $PatternsBoy
    $girlFiles = Get-MatchingFiles $VideoSearchPaths $PatternsGirl
    
    $boyGB  = [math]::Round(($boyFiles  | Measure-Object -Property Length -Sum).Sum / 1GB, 2)
    $girlGB = [math]::Round(($girlFiles | Measure-Object -Property Length -Sum).Sum / 1GB, 2)
    
    Write-Host ("Boy Traveler Cutscenes   : {0,4} files | {1,10} GB" -f $boyFiles.Count, $boyGB) -ForegroundColor Yellow
    Write-Host ("Girl Traveler Cutscenes  : {0,4} files | {1,10} GB" -f $girlFiles.Count, $girlGB) -ForegroundColor Magenta
    
    Write-Host "=========================================" -ForegroundColor Cyan
    $totalGB = [math]::Round($totalGlobalBytes / 1GB, 2)
    Write-Host ("TOTAL STUBBABLE DATA     : {0,4} files | {1,10} GB" -f $totalGlobalCount, $totalGB) -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    Read-Host "Press Enter to return to menu..."
}

function Process-Stubbing {
    param ([array]$FilesToStub, [string]$Description)

    if ($FilesToStub.Count -eq 0) {
        Write-Host "`nNo matching files found for: $Description" -ForegroundColor Yellow
        Read-Host "Press Enter to continue..."
        return
    }

    $stats = $FilesToStub | Measure-Object -Property Length -Sum
    $totalBytesFound = $stats.Sum
    
    Write-Host "`n-----------------------------------------" -ForegroundColor DarkGray
    Write-Host "Selection:         $Description"
    Write-Host "Files Match:       " -NoNewline
    Write-Host "$($FilesToStub.Count)" -ForegroundColor White

    # Check for already stubbed (Total bytes = 0 or close to 0)
    if ($totalBytesFound -lt ($FilesToStub.Count * 1024)) { 
        Write-Host "Status:            " -NoNewline
        Write-Host "ALREADY STUBBED" -ForegroundColor Green
        Write-Host "-----------------------------------------" -ForegroundColor DarkGray
        Write-Host "Files appear to be stubbed (0KB)." -ForegroundColor Gray
        Write-Host ""
        Write-Host "Select action:"
        Write-Host " [1] Re-Sync Manifest (Register stubs as 0KB in res_versions_persist)"
        Write-Host " [2] Restore & Delete (Force game to redownload real files on launch)"
        Write-Host " [3] Cancel"
        
        $action = Read-Host "Choice"
        
        if ($action -eq '1') {
            $synced = Sync-Manifest
        }
        elseif ($action -eq '2') {
            $deletedNames = @()
            foreach ($file in $FilesToStub) {
                try {
                    Remove-FileLock -Path $file.FullName
                    Remove-Item $file.FullName -Force -ErrorAction SilentlyContinue
                    $deletedNames += $file.Name
                    Write-Host "Removed stub: $($file.Name)" -ForegroundColor DarkGray
                } catch { Write-Host "Error removing: $($file.Name)" -ForegroundColor Red }
            }
            if ($deletedNames.Count -gt 0) {
                $restored = Restore-Manifest -FileNamesToRestore $deletedNames
                Write-Host "`nRestored $restored manifest entries in res_versions_persist." -ForegroundColor Green
            }
            Write-Host "Done. The game will redownload these files on next launch." -ForegroundColor Yellow
            Read-Host "Press Enter to continue..."
        }
        return
    }

    $ActiveFiles = $FilesToStub | Where-Object { $_.Length -gt 0 }
    $totalGB = [math]::Round($totalBytesFound / 1GB, 2)

    Write-Host "Stubbable Files:   " -NoNewline
    Write-Host "$($ActiveFiles.Count)" -ForegroundColor Yellow
    Write-Host "Potential Savings: " -NoNewline
    Write-Host "$totalGB GB" -ForegroundColor Green
    Write-Host "-----------------------------------------" -ForegroundColor DarkGray
    
    $ActiveFiles.Name | Select-Object -First 3 | ForEach-Object { Write-Host " - $_" -ForegroundColor DarkGray }
    if ($ActiveFiles.Count -gt 3) { Write-Host " ... and others." -ForegroundColor DarkGray }
    
    Write-Host ""
    Write-Host "This will STUB (0KB) files and synchronize the game's manifest (res_versions_persist)." -ForegroundColor Cyan
    Write-Host "The in-game patcher will recognize these stubs as valid and will not redownload them." -ForegroundColor Gray
    $confirmation = Read-Host "`nProceed? (Y/N)"
    
    if ($confirmation -eq 'Y' -or $confirmation -eq 'y') {
        $stubbedCount = 0
        foreach ($file in $ActiveFiles) {
            try {
                # 1. Clean slate - remove any legacy ACLs
                Remove-FileLock -Path $file.FullName
                
                # 2. Stub to 0 bytes
                New-Item -Path $file.FullName -ItemType File -Force | Out-Null
                
                Write-Host "Stubbed: $($file.Name)" -ForegroundColor DarkGray
                $stubbedCount++
            }
            catch { Write-Host "Error: $($file.Name) - $_" -ForegroundColor Red }
        }
        Write-Host "`nSuccess! Stubbed $stubbedCount files." -ForegroundColor Green
        
        # 3. Synchronize with res_versions_persist
        Write-Host "Synchronizing manifest with internal asset database..." -ForegroundColor Cyan
        $synced = Sync-Manifest -Silent
        Write-Host "Manifest synced! ($synced stubbed assets registered as 0KB)." -ForegroundColor Green
        Write-Host "The game's in-game patcher will now treat these stubs as 100% valid." -ForegroundColor Cyan
    } else {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
    }
    Read-Host "Press Enter to return to menu..."
}

function Process-UnlockOnly {
    param ([array]$FilesToUnlock, [string]$Description)

    if ($FilesToUnlock.Count -eq 0) {
        Write-Host "`nNo matching files found for: $Description" -ForegroundColor Yellow
        Read-Host "Press Enter to continue..."
        return
    }

    $stats = $FilesToUnlock | Measure-Object -Property Length -Sum
    $totalBytesFound = $stats.Sum
    
    Write-Host "`n-----------------------------------------" -ForegroundColor DarkGray
    Write-Host "Selection:         $Description" -ForegroundColor Yellow
    Write-Host "Files Found:       $($FilesToUnlock.Count)" -ForegroundColor White
    Write-Host "Current Size:      $([math]::Round($totalBytesFound / 1MB, 2)) MB" -ForegroundColor Cyan
    Write-Host "-----------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Select unlock mode:"
    Write-Host " [1] Strip Legacy ACLs (Remove Deny Write rules, keep 0KB stubs & manifest synced)" -ForegroundColor Cyan
    Write-Host " [2] Delete Stubs & Restore Manifest (Game will re-download full files on launch)" -ForegroundColor Yellow
    Write-Host " [3] Cancel"
    
    $subChoice = Read-Host "`nEnter choice"
    if ($subChoice -eq '1') {
        $count = 0
        foreach ($file in $FilesToUnlock) {
            Remove-FileLock -Path $file.FullName
            $count++
        }
        Write-Host "`nStripped legacy ACL locks from $count files." -ForegroundColor Green
        $synced = Sync-Manifest -Silent
        Write-Host "Manifest synced ($synced stubs confirmed). Game can run freely without Error -9908." -ForegroundColor Cyan
        Read-Host "`nPress Enter to return to menu..."
    }
    elseif ($subChoice -eq '2') {
        $deletedNames = @()
        foreach ($file in $FilesToUnlock) {
            try {
                Remove-FileLock -Path $file.FullName
                Remove-Item $file.FullName -Force -ErrorAction SilentlyContinue
                $deletedNames += $file.Name
                Write-Host "Removed: $($file.Name)" -ForegroundColor DarkGray
            } catch { Write-Host "Error deleting: $($file.Name)" -ForegroundColor Red }
        }
        if ($deletedNames.Count -gt 0) {
            $restored = Restore-Manifest -FileNamesToRestore $deletedNames
            Write-Host "`nRestored $restored entries in res_versions_persist." -ForegroundColor Green
        }
        Write-Host "Done. The game will redownload these files naturally on next launch." -ForegroundColor Yellow
        Read-Host "`nPress Enter to return to menu..."
    }
}

function Process-RevisionManager {
    $CurrentLocation = (Get-Location).ProviderPath
    $persistentDir = Join-Path $CurrentLocation "GenshinImpact_Data\Persistent"

    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "   In-Game Revisions & Hotfix Status" -ForegroundColor Yellow
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Directory: $persistentDir" -ForegroundColor DarkGray
    Write-Host ""

    $resRevFile     = Join-Path $persistentDir "res_revision"
    $silenceRevFile = Join-Path $persistentDir "silence_revision"
    $dataRevFile    = Join-Path $persistentDir "data_revision"
    $scriptRevFile  = Join-Path $persistentDir "ScriptVersion"
    $channelFile    = Join-Path $persistentDir "ChannelName"

    $channel = if (Test-Path $channelFile) { (Get-Content $channelFile -Raw).Trim() } else { "OSRELWin" }
    $script  = if (Test-Path $scriptRevFile) { (Get-Content $scriptRevFile -Raw).Trim() } else { "Unknown" }
    $resRev  = if (Test-Path $resRevFile) { (Get-Content $resRevFile -Raw).Trim() } else { "Unknown" }
    $silRev  = if (Test-Path $silenceRevFile) { (Get-Content $silenceRevFile -Raw).Trim() } else { "Unknown" }
    $dataRev = if (Test-Path $dataRevFile) { (Get-Content $dataRevFile -Raw).Trim() } else { "Unknown" }

    $versionString = "${channel}${script}_R${resRev}_S${silRev}_D${dataRev}"

    Write-Host "Current In-Game Version String:" -ForegroundColor White
    Write-Host "  $versionString" -ForegroundColor Green
    Write-Host ""
    Write-Host "Revision Components:" -ForegroundColor White
    Write-Host "  [R] Resource Revision : $resRev" -ForegroundColor Yellow -NoNewline
    Write-Host " (res_versions_persist - cutscenes, audio, models)" -ForegroundColor DarkGray
    Write-Host "  [S] Silence Revision  : $silRev" -ForegroundColor Cyan -NoNewline
    Write-Host " (silence_data_versions - tiny hotfix blocks)" -ForegroundColor DarkGray
    Write-Host "  [D] Data Revision     : $dataRev" -ForegroundColor Magenta -NoNewline
    Write-Host " (data_versions - gameplay Lua, quest data)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "How this helps with minor patches:" -ForegroundColor Gray
    Write-Host "When HoYoverse pushes a minor in-game patch, R/S/D are updated." -ForegroundColor Gray
    Write-Host "Matching 'res_revision' to the server's new R-number tells the game that" -ForegroundColor Gray
    Write-Host "resources are already up-to-date, completely skipping the 2,580 file integrity check." -ForegroundColor Gray
    Write-Host ""
    Write-Host "Options:"
    Write-Host " [1] Update Resource Revision (R-number) manually"
    Write-Host " [2] Return to Menu"

    $revChoice = Read-Host "`nEnter Choice"
    if ($revChoice -eq '1') {
        $newR = Read-Host "Enter new Resource Revision (e.g., $resRev)"
        $newR = $newR.Trim().TrimStart('R').TrimStart('r')
        if ($newR -match '^\d+$') {
            try {
                $newR | Out-File -FilePath $resRevFile -Encoding ascii -Force -NoNewline
                Write-Host "`nSuccessfully updated res_revision to: $newR" -ForegroundColor Green
                Write-Host "The game will now consider resource revision $newR already installed." -ForegroundColor Cyan
            } catch {
                Write-Host "`nFailed to write res_revision: $_" -ForegroundColor Red
            }
        } else {
            Write-Host "Invalid revision format. Must be numeric." -ForegroundColor Yellow
        }
        Read-Host "`nPress Enter to return to menu..."
    }
}

function Get-CompressedFileSize {
    param([string]$path)
    if (-not (Test-Path $path)) { return 0 }

    if (-not [type]::GetType('Win32Compressed')) {
        $signature = @'
using System;
using System.Runtime.InteropServices;
public static class Win32Compressed {
    [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
    public static extern uint GetCompressedFileSizeW(string lpFileName, out uint lpFileSizeHigh);
}
'@
        try { Add-Type -TypeDefinition $signature -ErrorAction Stop } catch { }
    }

    $high = 0
    try {
        $low = [Win32Compressed]::GetCompressedFileSizeW($path, [ref]$high)
    } catch {
        return 0
    }
    if ($low -eq 0xFFFFFFFF) {
        $err = [System.ComponentModel.Win32Exception]::new([System.Runtime.InteropServices.Marshal]::GetLastWin32Error())
        throw $err
    }
    return (([uint64]$high -shl 32) -bor ([uint64]$low))
}

function Get-FolderDiskUsage {
    param([string]$root)
    $logicalSum = 0
    $compressedSum = 0
    $files = Get-ChildItem -Path $root -Recurse -File -ErrorAction SilentlyContinue
    foreach ($f in $files) {
        $logicalSum += $f.Length
        try { $compressedSum += Get-CompressedFileSize $f.FullName } catch { $compressedSum += $f.Length }
    }
    return @{ Logical = $logicalSum; Compressed = $compressedSum }
}

function Process-Compression {
    $gameRoot = (Get-Location).ProviderPath
    Write-Host "`nCalculating current disk usage (this may take a while)..." -ForegroundColor Cyan
    $before = Get-FolderDiskUsage $gameRoot
    $beforeGB = [math]::Round($before.Compressed / 1GB, 2)
    $logicalGB = [math]::Round($before.Logical / 1GB, 2)
    Write-Host "Before: $beforeGB GB (on-disk) / $logicalGB GB (logical)" -ForegroundColor Cyan

    Write-Host "`nThis will apply NTFS LZX compression recursively to the current game folder." -ForegroundColor Yellow
    $confirmation = Read-Host "Proceed? (Y/N)"
    if ($confirmation -notin @('Y','y')) { Write-Host "Compression cancelled." -ForegroundColor Yellow; Read-Host "Press Enter to continue..."; return }

    Write-Host "`nCompressing files under: $gameRoot" -ForegroundColor Cyan
    try {
        $argS = '/S:"' + $gameRoot + '"'
        $args = @('/C', $argS, '/I', '/Q', '/EXE:LZX')
        $proc = Start-Process -FilePath 'compact.exe' -ArgumentList $args -NoNewWindow -Wait -PassThru
        if ($proc.ExitCode -ne 0) { Write-Host "`ncompact.exe exited with code $($proc.ExitCode)." -ForegroundColor Red }
    } catch {
        Write-Host "`nError running compact.exe: $_" -ForegroundColor Red
    }

    Write-Host "`nRecalculating disk usage after compression..." -ForegroundColor Cyan
    $after = Get-FolderDiskUsage $gameRoot
    $afterGB = [math]::Round($after.Compressed / 1GB, 2)
    Write-Host "After:  $afterGB GB (on-disk) / $logicalGB GB (logical)" -ForegroundColor Cyan

    $savedBytes = $before.Compressed - $after.Compressed
    $savedGB = [math]::Round($savedBytes / 1GB, 2)
    $percent = if ($before.Compressed -gt 0) { [math]::Round(($savedBytes / $before.Compressed) * 100, 2) } else { 0 }
    Write-Host "`nSaved:  $savedGB GB ($percent% reduction)" -ForegroundColor Green
    Read-Host "Press Enter to continue..."
}

# --- MAIN EXECUTION ---
Get-GamePath

do {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "   GenshinSlimmer v12" -ForegroundColor Yellow
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Mode: Manifest-Sync Engine + Persistent Support (7.1 fixed)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Select content to stub:"
    Write-Host " 1. Mondstadt"
    Write-Host " 2. Liyue"
    Write-Host " 3. Inazuma"
    Write-Host " 4. Sumeru"
    Write-Host " 5. Fontaine"
    Write-Host " 6. Natlan"
    Write-Host " 7. Nod-Krai"
    Write-Host " 8. Snezhnaya (ZhìDōng / 7.0-7.1) " -NoNewline
    Write-Host "[WARNING: FINISH 7.x AQ First!]" -ForegroundColor Red
    Write-Host " 9. Expired Events & Misc Cutscenes"
    Write-Host "10. UGC Cache (BeyondUGC)"
    Write-Host "11. Stub 'Boy' Traveler Videos Only" -ForegroundColor Cyan
    Write-Host "12. Stub 'Girl' Traveler Videos Only" -ForegroundColor Magenta
    Write-Host "-----------------------------------------" -ForegroundColor DarkGray
    Write-Host " S. Scan & Analyze Game Folder" -ForegroundColor Yellow
    Write-Host " M. Sync Manifest (Fix In-Game Patcher / Stop Minor Update Redownloads)" -ForegroundColor Green
    Write-Host " R. View / Update In-Game Revisions (R / S / D)" -ForegroundColor Cyan
    Write-Host " U. UNLOCK / Restore Files & Clean Legacy ACLs" -ForegroundColor Yellow
    Write-Host "-----------------------------------------" -ForegroundColor DarkGray
    Write-Host " B. STUB ALL + BOY (Regions + Events + UGC + Boy)" -ForegroundColor Cyan
    Write-Host " G. STUB ALL + GIRL (Regions + Events + UGC + Girl)" -ForegroundColor Magenta
    Write-Host " 0. STUB ALL (Regions + Events + UGC - Without Boy/Girl)" -ForegroundColor Red
    Write-Host " C. Compress Game Files (LZX)" -ForegroundColor Green
    Write-Host " Q. Quit"
    Write-Host "=========================================" -ForegroundColor Cyan

    $choice = Read-Host "Enter your choice"
    
    $selection = @()
    $desc = ""

    switch ($choice) {
        'C' { Process-Compression; continue }
        'c' { Process-Compression; continue }

        'S' { Process-Scan; continue }
        's' { Process-Scan; continue }

        'M' { Sync-Manifest; continue }
        'm' { Sync-Manifest; continue }

        'R' { Process-RevisionManager; continue }
        'r' { Process-RevisionManager; continue }

        '1'  { $selection = Get-MatchingFiles $VideoSearchPaths $PatternsMondstadt; $desc = "Mondstadt" }
        '2'  { $selection = Get-MatchingFiles $VideoSearchPaths $PatternsLiyue; $desc = "Liyue" }
        '3'  { $selection = Get-MatchingFiles $VideoSearchPaths $PatternsInazuma; $desc = "Inazuma" }
        '4'  { $selection = Get-MatchingFiles $VideoSearchPaths $PatternsSumeru; $desc = "Sumeru" }
        '5'  { $selection = Get-MatchingFiles $VideoSearchPaths $PatternsFontaine; $desc = "Fontaine" }
        '6'  { $selection = Get-MatchingFiles $VideoSearchPaths $PatternsNatlan; $desc = "Natlan" }
        '7'  { $selection = Get-MatchingFiles $VideoSearchPaths $PatternsNodKrai; $desc = "NodKrai" }
        '8'  { $selection = Get-MatchingFiles $VideoSearchPaths $PatternsSnezhnaya; $desc = "Snezhnaya" }
        '9'  { $selection = Get-MatchingFiles $VideoSearchPaths $PatternsMisc; $desc = "Events & Misc" }
        '10' { $selection = Get-MatchingFiles $UGCSearchPaths @("*"); $desc = "UGC Cache" }
        '11' { $selection = Get-MatchingFiles $VideoSearchPaths $PatternsBoy; $desc = "Boy Traveler Videos Only" }
        '12' { $selection = Get-MatchingFiles $VideoSearchPaths $PatternsGirl; $desc = "Girl Traveler Videos Only" }

        'U' {
            Write-Host "`nScanning for stubbed files..." -ForegroundColor Cyan
            $AllPatterns = $AllRegionPatterns + $PatternsBoy + $PatternsGirl
            $selection += Get-MatchingFiles $VideoSearchPaths $AllPatterns
            $selection += Get-MatchingFiles $UGCSearchPaths @("*")
            $desc = "UNLOCK / RESTORE ALL"
        }
        'u' {
            Write-Host "`nScanning for stubbed files..." -ForegroundColor Cyan
            $AllPatterns = $AllRegionPatterns + $PatternsBoy + $PatternsGirl
            $selection += Get-MatchingFiles $VideoSearchPaths $AllPatterns
            $selection += Get-MatchingFiles $UGCSearchPaths @("*")
            $desc = "UNLOCK / RESTORE ALL"
        }

        'G' {
            $AllVideoPatterns = $AllRegionPatterns + $PatternsGirl
            $selection += Get-MatchingFiles $VideoSearchPaths $AllVideoPatterns
            $selection += Get-MatchingFiles $UGCSearchPaths @("*")
            $desc = "ALL REGIONS + EVENTS + UGC + GIRL"
        }
        'g' {
            $AllVideoPatterns = $AllRegionPatterns + $PatternsGirl
            $selection += Get-MatchingFiles $VideoSearchPaths $AllVideoPatterns
            $selection += Get-MatchingFiles $UGCSearchPaths @("*")
            $desc = "ALL REGIONS + EVENTS + UGC + GIRL"
        }
        'B' {
            $AllVideoPatterns = $AllRegionPatterns + $PatternsBoy
            $selection += Get-MatchingFiles $VideoSearchPaths $AllVideoPatterns
            $selection += Get-MatchingFiles $UGCSearchPaths @("*")
            $desc = "ALL REGIONS + EVENTS + UGC + BOY"
        }
        'b' {
            $AllVideoPatterns = $AllRegionPatterns + $PatternsBoy
            $selection += Get-MatchingFiles $VideoSearchPaths $AllVideoPatterns
            $selection += Get-MatchingFiles $UGCSearchPaths @("*")
            $desc = "ALL REGIONS + EVENTS + UGC + BOY"
        }
        '0' { 
            $selection += Get-MatchingFiles $VideoSearchPaths $AllRegionPatterns
            $selection += Get-MatchingFiles $UGCSearchPaths @("*")
            $desc = "ALL REGIONS + EVENTS + UGC"
        }
        'Q' { break }
        'q' { break }
    }

    if ($choice -in '1','2','3','4','5','6','7','8','9','10','11','12','G','g','B','b','0','U','u') {
        if ($choice -in 'U','u') {
            Process-UnlockOnly -FilesToUnlock $selection -Description $desc
        } else {
            Process-Stubbing -FilesToStub $selection -Description $desc
        }
    }
} until ($choice -eq 'Q' -or $choice -eq 'q')
