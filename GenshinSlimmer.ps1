<#
.SYNOPSIS
    GenshinSlimmer v6
    Replaces large video files with empty "stubs" (0KB files) to save space.
    
    Updates:
    - Added support for "Persistent" asset folder (New Genshin file structure)
    - Scans both StreamingAssets and Persistent folders
    
    Author: dnullptr
#>

# --- CONFIGURATION ---
# Paths relative to the "Genshin Impact game" root folder
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
    Write-Host "   GenshinSlimmer v6" -ForegroundColor Yellow
    Write-Host "   Created by dnullptr" -ForegroundColor DarkGray
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""

    $ConfigPath = Join-Path $PSScriptRoot "path.ini"
    $validPathFound = $false

    # 1. Try to load from path.ini
    if (Test-Path $ConfigPath) {
        $SavedPath = Get-Content -Path $ConfigPath -Raw -ErrorAction SilentlyContinue
        if ($SavedPath) {
            $SavedPath = $SavedPath.Trim().Replace('"', '')
            $CheckPath = Join-Path -Path $SavedPath -ChildPath "GenshinImpact_Data"
            
            if (Test-Path $CheckPath) {
                Write-Host "Found saved path in path.ini:" -ForegroundColor White
                Write-Host "$SavedPath" -ForegroundColor DarkGray
                Write-Host "Verifying... " -NoNewline
                Write-Host "OK!" -ForegroundColor Green
                
                Set-Location $SavedPath
                $validPathFound = $true
                Start-Sleep -Seconds 1
                return 
            } else {
                Write-Host "Saved path in path.ini is invalid." -ForegroundColor Yellow
            }
        }
    }

    if (-not $validPathFound) {
        Write-Host "Please paste the path to your 'Genshin Impact game' folder." -ForegroundColor White
        Write-Host "Example: D:\Games\Genshin Impact\Genshin Impact game" -ForegroundColor Gray
        Write-Host "(This will be saved to path.ini for next time)" -ForegroundColor DarkGray
        Write-Host ""
    }

    while (-not $validPathFound) {
        $userInput = Read-Host "Paste Path Here"
        $userInput = $userInput -replace '"', '' # Remove quotes
        
        # 2. Check for GenshinImpact_Data
        $CheckPath = Join-Path -Path $userInput -ChildPath "GenshinImpact_Data"

        if (Test-Path $CheckPath) {
            Write-Host "`nFolder found! Saving config..." -ForegroundColor Green
            
            # Save to path.ini
            try {
                $userInput | Out-File -FilePath $ConfigPath -Encoding utf8 -Force
                Write-Host "Path saved to path.ini" -ForegroundColor Cyan
            } catch {
                Write-Host "Warning: Could not write path.ini" -ForegroundColor Red
            }

            Write-Host "Switching directory..." -ForegroundColor Green
            Set-Location $userInput
            $validPathFound = $true
            Start-Sleep -Seconds 1
        } else {
            Write-Host "`nCould not find 'GenshinImpact_Data' at:" -ForegroundColor Red
            Write-Host "$CheckPath" -ForegroundColor DarkGray
            Write-Host "Please make sure you selected the folder named 'Genshin Impact game'." -ForegroundColor Yellow
            Write-Host "Try again.`n"
        }
    }
}

# --- DEFINE PATTERNS ---
$PatternsMondstadt = @("*Mengde*", "*MDAQ*", "*Venti*")
$PatternsLiyue     = @("*LiYue*", "*LYAQ*")
$PatternsSumeru    = @("*Sumeru*")
$PatternsFontaine  = @("*Fontaine*")
$PatternsNatlan    = @("*Natlan*")

# New Gender Patterns
$PatternsBoy       = @("*Boy.usm")
$PatternsGirl      = @("*Girl.usm")

function Show-Menu {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "   GenshinSlimmer v6" -ForegroundColor Yellow
    Write-Host "   Created by dnullptr" -ForegroundColor DarkGray
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Target Base: ...\Genshin Impact game (Scans StreamingAssets & Persistent)" -ForegroundColor DarkGray
    Write-Host "Mode: STUBBING (Files are emptied, not deleted)" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "Select content to stub (empty):"
    Write-Host "1. Mondstadt Videos (Matches *Mengde*, *MDAQ*, *Venti*)"
    Write-Host "2. Liyue Videos     (Matches *LiYue*, *LYAQ*)"
    Write-Host "3. Sumeru Videos    (Matches *Sumeru*)"
    Write-Host "4. Fontaine Videos  (Matches *Fontaine*)"
    Write-Host "5. Natlan Videos    (Matches *Natlan*)"
    Write-Host "-----------------------------------------" -ForegroundColor DarkGray
    Write-Host "6. UGC Cache (Miliastra Wonderland / BeyondUGC)" -ForegroundColor Magenta
    Write-Host "-----------------------------------------" -ForegroundColor DarkGray
    Write-Host "7. Stub 'Boy' (Aether) Videos (Global)" -ForegroundColor Cyan
    Write-Host "8. Stub 'Girl' (Lumine) Videos (Global)" -ForegroundColor Cyan
    Write-Host "-----------------------------------------" -ForegroundColor DarkGray
    Write-Host "9. STUB ALL (Regions 1-5 + UGC)" -ForegroundColor Red
    Write-Host "-----------------------------------------" -ForegroundColor DarkGray
    Write-Host "Q. Quit"
    Write-Host "=========================================" -ForegroundColor Cyan
}

function Get-MatchingFiles {
    param (
        [array]$RelativePaths,
        [array]$Patterns
    )
    
    $AllFiles = @()
    $CurrentLocation = Get-Location

    foreach ($path in $RelativePaths) {
        $fullPath = Join-Path $CurrentLocation $path
        
        if (Test-Path $fullPath) {
            $files = Get-ChildItem -Path $fullPath -File | Where-Object { 
                $name = $_.Name
                $matched = $false
                foreach ($pattern in $Patterns) {
                    if ($name -like $pattern) { $matched = $true; break }
                }
                $matched
            }
            $AllFiles += $files
        }
    }
    
    return $AllFiles
}

function Process-Stubbing {
    param (
        [array]$FilesToStub,
        [string]$Description
    )

    # 1. Check if ANY files match the name pattern (regardless of size)
    if ($FilesToStub.Count -eq 0) {
        Write-Host "`nNo matching files found for: $Description" -ForegroundColor Yellow
        Write-Host "(Folder might be empty or region not installed)" -ForegroundColor DarkGray
        Read-Host "Press Enter to continue..."
        return
    }

    # 2. Calculate TOTAL SIZE of all matching files
    $stats = $FilesToStub | Measure-Object -Property Length -Sum
    $totalBytesFound = $stats.Sum
    
    # --- REPORT HEADER ---
    Write-Host "`n-----------------------------------------" -ForegroundColor DarkGray
    Write-Host "Selection:         $Description"
    Write-Host "Files Match:       " -NoNewline
    Write-Host "$($FilesToStub.Count)" -ForegroundColor White

    # 3. Check if ALREADY STUBBED (Total Size == 0)
    if ($totalBytesFound -eq 0) {
        Write-Host "Status:            " -NoNewline
        Write-Host "ALREADY STUBBED (0 GB)" -ForegroundColor Green
        Write-Host "-----------------------------------------" -ForegroundColor DarkGray
        Write-Host "These files are already optimized (empty)." -ForegroundColor Yellow
        Read-Host "Press Enter to continue..."
        return
    }

    # 4. If not stubbed, calculate savings
    $ActiveFiles = $FilesToStub | Where-Object { $_.Length -gt 0 }
    
    $totalMB = [math]::Round($totalBytesFound / 1MB, 2)
    $totalGB = [math]::Round($totalBytesFound / 1GB, 2)

    Write-Host "Stubbable Files:   " -NoNewline
    Write-Host "$($ActiveFiles.Count)" -ForegroundColor Yellow
    Write-Host "Potential Savings: " -NoNewline
    if ($totalGB -gt 1) {
        Write-Host "$totalGB GB" -ForegroundColor Green
    } else {
        Write-Host "$totalMB MB" -ForegroundColor Green
    }
    Write-Host "-----------------------------------------" -ForegroundColor DarkGray
    
    # Preview
    Write-Host "Preview (Active files):" -ForegroundColor Gray
    $ActiveFiles.Name | Select-Object -First 5 | ForEach-Object { Write-Host " - $_" -ForegroundColor DarkGray }
    if ($ActiveFiles.Count -gt 5) { Write-Host " ... and $($ActiveFiles.Count - 5) others." -ForegroundColor DarkGray }

    Write-Host ""
    Write-Host "This will replace the active files with empty (0KB) stubs." -ForegroundColor Cyan
    $confirmation = Read-Host "Are you sure? (Y/N)"
    
    if ($confirmation -eq 'Y' -or $confirmation -eq 'y') {
        $stubbedCount = 0
        $savedSize = 0
        foreach ($file in $ActiveFiles) {
            try {
                $size = $file.Length
                
                # Fix for Access Denied: Remove Read-Only attribute if present
                if ($file.IsReadOnly) {
                    $file.IsReadOnly = $false
                }

                # STUBBING LOGIC: Create a new empty file, overwriting the old one
                New-Item -Path $file.FullName -ItemType File -Force | Out-Null
                
                Write-Host "Stubbed: $($file.Name)" -ForegroundColor DarkGray
                $stubbedCount++
                $savedSize += $size
            }
            catch {
                Write-Host "Error stubbing $($file.Name): $_" -ForegroundColor Red
            }
        }
        $finalSavedGB = [math]::Round($savedSize / 1GB, 2)
        Write-Host "`nSuccess! Optimized $stubbedCount files." -ForegroundColor Green
        if ($finalSavedGB -gt 0) { Write-Host "You saved $finalSavedGB GB." -ForegroundColor Green }
    } else {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
    }
    
    Read-Host "Press Enter to return to menu..."
}

# --- EXECUTION START ---

# 1. Ask user for path and set location
Get-GamePath

# 2. Loop Menu
do {
    Show-Menu
    $choice = Read-Host "Enter your choice"
    
    # Reset file list
    $selection = @()
    $desc = ""

    switch ($choice) {
        '1' { 
            $selection = Get-MatchingFiles $VideoSearchPaths $PatternsMondstadt 
            $desc = "Mondstadt Videos"
        }
        '2' { 
            $selection = Get-MatchingFiles $VideoSearchPaths $PatternsLiyue 
            $desc = "Liyue Videos"
        }
        '3' { 
            $selection = Get-MatchingFiles $VideoSearchPaths $PatternsSumeru 
            $desc = "Sumeru Videos"
        }
        '4' { 
            $selection = Get-MatchingFiles $VideoSearchPaths $PatternsFontaine 
            $desc = "Fontaine Videos"
        }
        '5' { 
            $selection = Get-MatchingFiles $VideoSearchPaths $PatternsNatlan 
            $desc = "Natlan Videos"
        }
        '6' {
            # Select ALL files in the UGC folder
            $selection = Get-MatchingFiles $UGCSearchPaths @("*")
            $desc = "UGC Cache (BeyondUGC)"
        }
        '7' {
            $selection = Get-MatchingFiles $VideoSearchPaths $PatternsBoy
            $desc = "Boy/Aether Videos (Global)"
        }
        '8' {
            $selection = Get-MatchingFiles $VideoSearchPaths $PatternsGirl
            $desc = "Girl/Lumine Videos (Global)"
        }
        '9' { 
            # Combine ALL videos + ALL UGC
            $AllVideoPatterns = $PatternsMondstadt + $PatternsLiyue + $PatternsSumeru + $PatternsFontaine + $PatternsNatlan
            $selection += Get-MatchingFiles $VideoSearchPaths $AllVideoPatterns
            $selection += Get-MatchingFiles $UGCSearchPaths @("*")
            $desc = "ALL REGIONS + UGC"
        }
        'Q' { Write-Host "Exiting..."; break }
        'q' { Write-Host "Exiting..."; break }
    }

    if ($choice -ne 'Q' -and $choice -ne 'q' -and $desc -ne "") {
        Process-Stubbing -FilesToStub $selection -Description $desc
    } elseif ($choice -ne 'Q' -and $choice -ne 'q') {
        Write-Host "Invalid selection." -ForegroundColor Red
        Start-Sleep -Milliseconds 500
    }

} until ($choice -eq 'Q' -or $choice -eq 'q')
