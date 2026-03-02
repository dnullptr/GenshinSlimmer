<#
.SYNOPSIS
    GenshinSlimmer v8
    - Stubs files to 0KB to save space.
    - Applies "Aggressive Lock" (ACL Permissions) to prevent the game from 
      redownloading the stubbed files during its verification check.
    
    Findings:
    - The game verifies files in 'Persistent' on startup (DownloadError.log).
    - Locking the file permissions stops the redownload.
    
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
    Write-Host "   GenshinSlimmer v8" -ForegroundColor Yellow
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
$PatternsMondstadt = @("*Mengde*", "*MDAQ*", "*Venti*")
$PatternsLiyue     = @("*LiYue*", "*LYAQ*")
$PatternsSumeru    = @("*Sumeru*")
$PatternsFontaine  = @("*Fontaine*")
$PatternsNatlan    = @("*Natlan*")
$PatternsBoy       = @("*Boy.usm")
$PatternsGirl      = @("*Girl.usm")

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

# --- MAIN EXECUTION ---
Get-GamePath

do {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "   GenshinSlimmer v8" -ForegroundColor Yellow
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Mode: Persistent + StreamingAssets (Aggressive Lock)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Select content to stub & lock:"
    Write-Host "1. Mondstadt"
    Write-Host "2. Liyue"
    Write-Host "3. Sumeru"
    Write-Host "4. Fontaine"
    Write-Host "5. Natlan"
    Write-Host "-----------------------------------------" -ForegroundColor DarkGray
    Write-Host "6. UGC Cache"
    Write-Host "7. Stub 'Boy' Videos"
    Write-Host "8. Stub 'Girl' Videos"
    Write-Host "9. UNLOCK ALL (Allow Re-download every major update)" -ForegroundColor Yellow
    Write-Host "-----------------------------------------" -ForegroundColor DarkGray
    Write-Host "G. STUB ALL + GIRL (Regions + UGC + Girl)" -ForegroundColor Magenta
    Write-Host "B. STUB ALL + BOY (Regions + UGC + Boy)" -ForegroundColor Cyan
    Write-Host "0. STUB ALL (Regions + UGC - Without Boy/Girl)" -ForegroundColor Red
    Write-Host "Q. Quit"
    Write-Host "=========================================" -ForegroundColor Cyan

    $choice = Read-Host "Enter your choice"
    
    $selection = @()
    $desc = ""

    switch ($choice) {
        '1' { $selection = Get-MatchingFiles $VideoSearchPaths $PatternsMondstadt; $desc = "Mondstadt" }
        '2' { $selection = Get-MatchingFiles $VideoSearchPaths $PatternsLiyue; $desc = "Liyue" }
        '3' { $selection = Get-MatchingFiles $VideoSearchPaths $PatternsSumeru; $desc = "Sumeru" }
        '4' { $selection = Get-MatchingFiles $VideoSearchPaths $PatternsFontaine; $desc = "Fontaine" }
        '5' { $selection = Get-MatchingFiles $VideoSearchPaths $PatternsNatlan; $desc = "Natlan" }
        '6' { $selection = Get-MatchingFiles $UGCSearchPaths @("*"); $desc = "UGC Cache" }
        '7' { $selection = Get-MatchingFiles $VideoSearchPaths $PatternsBoy; $desc = "Boy Videos" }
        '8' { $selection = Get-MatchingFiles $VideoSearchPaths $PatternsGirl; $desc = "Girl Videos" }
        '9' {
            # Unlock ALL stubbed files without deleting - allows game to re-download
            Write-Host "`nScanning for stubbed & locked files..." -ForegroundColor Cyan
            $AllPatterns = $PatternsMondstadt + $PatternsLiyue + $PatternsSumeru + $PatternsFontaine + $PatternsNatlan + $PatternsBoy + $PatternsGirl
            $selection += Get-MatchingFiles $VideoSearchPaths $AllPatterns
            $selection += Get-MatchingFiles $UGCSearchPaths @("*")
            $desc = "UNLOCK ALL"
        }
        'G' {
            $AllVideoPatterns = $PatternsMondstadt + $PatternsLiyue + $PatternsSumeru + $PatternsFontaine + $PatternsNatlan + $PatternsGirl
            $selection += Get-MatchingFiles $VideoSearchPaths $AllVideoPatterns
            $selection += Get-MatchingFiles $UGCSearchPaths @("*")
            $desc = "ALL REGIONS + UGC + GIRL"
        }
        'g' {
            $AllVideoPatterns = $PatternsMondstadt + $PatternsLiyue + $PatternsSumeru + $PatternsFontaine + $PatternsNatlan + $PatternsGirl
            $selection += Get-MatchingFiles $VideoSearchPaths $AllVideoPatterns
            $selection += Get-MatchingFiles $UGCSearchPaths @("*")
            $desc = "ALL REGIONS + UGC + GIRL"
        }
        'B' {
            $AllVideoPatterns = $PatternsMondstadt + $PatternsLiyue + $PatternsSumeru + $PatternsFontaine + $PatternsNatlan + $PatternsBoy
            $selection += Get-MatchingFiles $VideoSearchPaths $AllVideoPatterns
            $selection += Get-MatchingFiles $UGCSearchPaths @("*")
            $desc = "ALL REGIONS + UGC + BOY"
        }
        'b' {
            $AllVideoPatterns = $PatternsMondstadt + $PatternsLiyue + $PatternsSumeru + $PatternsFontaine + $PatternsNatlan + $PatternsBoy
            $selection += Get-MatchingFiles $VideoSearchPaths $AllVideoPatterns
            $selection += Get-MatchingFiles $UGCSearchPaths @("*")
            $desc = "ALL REGIONS + UGC + BOY"
        }
        '0' { 
            $AllVideoPatterns = $PatternsMondstadt + $PatternsLiyue + $PatternsSumeru + $PatternsFontaine + $PatternsNatlan
            $selection += Get-MatchingFiles $VideoSearchPaths $AllVideoPatterns
            $selection += Get-MatchingFiles $UGCSearchPaths @("*")
            $desc = "ALL REGIONS + UGC"
        }
        'Q' { break }
        'q' { break }
    }

    if ($choice -in '1','2','3','4','5','6','7','8','9','G','g','B','b','0') {
        if ($choice -eq '9') {
            # Special handling for Option 9 - Unlock without delete
            Process-UnlockOnly -FilesToUnlock $selection -Description $desc
        } else {
            Process-Stubbing -FilesToStub $selection -Description $desc
        }
    }
} until ($choice -eq 'Q' -or $choice -eq 'q')
