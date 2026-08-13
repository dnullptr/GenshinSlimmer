<#
    GenshinSlimmer v10
    - Stubs files to 0KB to save space.
    - Applies "Aggressive Lock" (ACL Permissions) to prevent the game from 
      redownloading the stubbed files during its verification check.
    - Handles both .usm and .usm.bak files across StreamingAssets and Persistent folders.
    - Supports all regions: Mondstadt, Liyue, Inazuma, Sumeru, Fontaine, Natlan, Nod-Krai, Snezhnaya (ZhìDōng / AQ70).
    - Includes past events, Dainsleif quests, traveler gender cutscenes, and UGC audio cache.
    - Includes interactive game folder scan/analysis mode.
    - Includes LZX NTFS compression.
    
    Author: dnullptr
#>

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
    Write-Host "   GenshinSlimmer v10" -ForegroundColor Yellow
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

function Toggle-FileLock {
    param (
        [string]$Path,
        [bool]$Lock
    )
    
    $file = Get-Item $Path
    $acl = $file.GetAccessControl()
    
    # Define a "Deny Write" rule for Everyone
    $permission = "Everyone"
    $rights = "Write, Delete" 
    $type = "Deny"
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($permission, $rights, $type)
    
    if ($Lock) {
        # 1. Set ReadOnly FIRST (Before removing write permissions)
        if (-not $file.IsReadOnly) { $file.IsReadOnly = $true }

        # 2. Apply Deny Rule
        $acl.AddAccessRule($rule)
        $file.SetAccessControl($acl)
    } else {
        # 1. Remove Deny Rule FIRST (To regain write permissions)
        $acl.RemoveAccessRule($rule) | Out-Null
        $file.SetAccessControl($acl)

        # 2. Remove ReadOnly
        if ($file.IsReadOnly) { $file.IsReadOnly = $false }
    }
}

# --- DEFINE PATTERNS ---
$PatternsMondstadt = @("*Mengde*", "*MDAQ*", "*Venti*", "*WDLQ*", "*Ambor*")
$PatternsLiyue     = @("*LiYue*", "*LYAQ*", "*LY_*", "*LQ10*", "*LQ11*", "*XiaoPersonal*", "*ShenheBattle*", "*YunjinOpera*")
$PatternsInazuma   = @("*Inazuma*", "*DaoQi*", "*200803*", "*200806*", "*200919*", "*201104*", "*200211*", "*LQ12*", "*ShougunBoss*", "*WanYeXian*")
$PatternsSumeru    = @("*Sumeru*", "*Xm_*", "*LQ13*")
$PatternsFontaine  = @("*Fontaine*", "*LQ14*")
$PatternsNatlan    = @("*Natlan*", "*LQ15*")
$PatternsNodKrai   = @("*NodKrai*", "*NK_*", "*LQ16*")
$PatternsSnezhnaya = @("*ZD_*", "*AQ70*") # Snezhnaya (ZhìDōng / 至冬)
$PatternsMisc      = @("*battlePass*", "*ChangeWeather*", "*EQ*", "*FD_*", "*GY*", "*Memories*", "*Reunion*", "*ShieldingResources*")
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
        Write-Host " [1] Re-Apply Lock (Fix permissions if previous run errored)"
        Write-Host " [2] Unlock & Delete (Force game to redownload)"
        Write-Host " [3] Cancel"
        
        $action = Read-Host "Choice"
        
        if ($action -eq '1') {
             foreach ($file in $FilesToStub) {
                try {
                    # Unlock first to clear weird states
                    Toggle-FileLock -Path $file.FullName -Lock $false
                    # Lock correctly
                    Toggle-FileLock -Path $file.FullName -Lock $true
                    Write-Host "Relocked: $($file.Name)" -ForegroundColor DarkGray
                } catch { Write-Host "Error: $($file.Name)" -ForegroundColor Red }
             }
             Write-Host "`nLocks updated. Game should not redownload files now." -ForegroundColor Green
        }
        elseif ($action -eq '2') {
            foreach ($file in $FilesToStub) {
                try {
                    Toggle-FileLock -Path $file.FullName -Lock $false
                    Remove-Item $file.FullName -Force
                    Write-Host "Unlocked & Deleted: $($file.Name)" -ForegroundColor DarkGray
                } catch { Write-Host "Error unlocking: $($file.Name)" -ForegroundColor Red }
            }
            Write-Host "`nDone. The game will redownload these files on next launch." -ForegroundColor Yellow
        }
        Read-Host "Press Enter to continue..."
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
    Write-Host "This will STUB (0KB) and LOCK files to prevent the game from fixing them." -ForegroundColor Cyan
    $confirmation = Read-Host "Proceed? (Y/N)"
    
    if ($confirmation -eq 'Y' -or $confirmation -eq 'y') {
        $stubbedCount = 0
        foreach ($file in $ActiveFiles) {
            try {
                # 1. Unlock first (clean slate - in case partially locked from failed run)
                try { Toggle-FileLock -Path $file.FullName -Lock $false } catch {}
                
                # 2. Stub
                New-Item -Path $file.FullName -ItemType File -Force | Out-Null
                
                # 3. Lock
                Toggle-FileLock -Path $file.FullName -Lock $true
                
                Write-Host "Stubbed & Locked: $($file.Name)" -ForegroundColor DarkGray
                $stubbedCount++
            }
            catch { Write-Host "Error: $($file.Name) - $_" -ForegroundColor Red }
        }
        Write-Host "`nSuccess! Optimized $stubbedCount files." -ForegroundColor Green
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
    Write-Host "This will UNLOCK all files WITHOUT deleting them." -ForegroundColor Yellow
    Write-Host "The game will be able to re-download these files naturally." -ForegroundColor Gray
    Write-Host "Useful for big patches that require file updates." -ForegroundColor Gray
    $confirmation = Read-Host "`nProceed? (Y/N)"
    
    if ($confirmation -eq 'Y' -or $confirmation -eq 'y') {
        $unlockedCount = 0
        foreach ($file in $FilesToUnlock) {
            try {
                Toggle-FileLock -Path $file.FullName -Lock $false
                Write-Host "Unlocked: $($file.Name)" -ForegroundColor Green
                $unlockedCount++
            }
            catch { Write-Host "Error: $($file.Name) - $_" -ForegroundColor Red }
        }
        Write-Host "`nSuccess! Unlocked $unlockedCount files." -ForegroundColor Green
        Write-Host "The game can now re-download these files during patches." -ForegroundColor Cyan
    } else {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
    }
    Read-Host "Press Enter to return to menu..."
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
    Write-Host "   GenshinSlimmer v10" -ForegroundColor Yellow
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Mode: Persistent + StreamingAssets (Aggressive Lock)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Select content to stub & lock:"
    Write-Host " 1. Mondstadt"
    Write-Host " 2. Liyue"
    Write-Host " 3. Inazuma"
    Write-Host " 4. Sumeru"
    Write-Host " 5. Fontaine"
    Write-Host " 6. Natlan"
    Write-Host " 7. Nod-Krai"
    Write-Host " 8. Snezhnaya (ZhìDōng / 7.0) " -NoNewline
    Write-Host "[WARNING: FINISH 7.0 AQ First!]" -ForegroundColor Red
    Write-Host " 9. Expired Events & Misc Cutscenes"
    Write-Host "10. UGC Cache (BeyondUGC)"
    Write-Host "-----------------------------------------" -ForegroundColor DarkGray
    Write-Host " S. Scan & Analyze Game Folder" -ForegroundColor Yellow
    Write-Host "-----------------------------------------" -ForegroundColor DarkGray
    Write-Host " B. Stub 'Boy' Videos"
    Write-Host " G. Stub 'Girl' Videos"
    Write-Host " U. UNLOCK ALL (Allow Re-download before major patch)" -ForegroundColor Yellow
    Write-Host "-----------------------------------------" -ForegroundColor DarkGray
    Write-Host " G. STUB ALL + GIRL (Regions + Events + UGC + Girl)" -ForegroundColor Magenta
    Write-Host " B. STUB ALL + BOY (Regions + Events + UGC + Boy)" -ForegroundColor Cyan
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

        'U' {
            Write-Host "`nScanning for stubbed & locked files..." -ForegroundColor Cyan
            $AllPatterns = $AllRegionPatterns + $PatternsBoy + $PatternsGirl
            $selection += Get-MatchingFiles $VideoSearchPaths $AllPatterns
            $selection += Get-MatchingFiles $UGCSearchPaths @("*")
            $desc = "UNLOCK ALL"
        }
        'u' {
            Write-Host "`nScanning for stubbed & locked files..." -ForegroundColor Cyan
            $AllPatterns = $AllRegionPatterns + $PatternsBoy + $PatternsGirl
            $selection += Get-MatchingFiles $VideoSearchPaths $AllPatterns
            $selection += Get-MatchingFiles $UGCSearchPaths @("*")
            $desc = "UNLOCK ALL"
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

    if ($choice -in '1','2','3','4','5','6','7','8','9','10','G','g','B','b','0','U','u') {
        if ($choice -in 'U','u') {
            Process-UnlockOnly -FilesToUnlock $selection -Description $desc
        } else {
            Process-Stubbing -FilesToStub $selection -Description $desc
        }
    }
} until ($choice -eq 'Q' -or $choice -eq 'q')
