<#
.SYNOPSIS
    GenshinSlimmer v4
    Replaces large video files with empty "stubs" (0KB files) to save space 
    without triggering missing file errors.
    
    Author: dnullptr
#>

# --- CONFIGURATION ---
$SubPath_Streaming = "GenshinImpact_Data\StreamingAssets"
$RelPath_Videos    = "VideoAssets\StandaloneWindows64"
$RelPath_UGC       = "AudioAssets\BeyondUGC"

function Get-GamePath {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "   GenshinSlimmer v4 Setup" -ForegroundColor Yellow
    Write-Host "   Created by dnullptr" -ForegroundColor DarkGray
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Please paste the path to your 'Genshin Impact game' folder." -ForegroundColor White
    Write-Host "Example: D:\Games\Genshin Impact\Genshin Impact game" -ForegroundColor Gray
    Write-Host ""
    
    $validPathFound = $false

    while (-not $validPathFound) {
        $userInput = Read-Host "Paste Path Here"
        $userInput = $userInput -replace '"', '' # Remove quotes
        
        # 1. Check for StreamingAssets
        $fullStreamingPath = Join-Path -Path $userInput -ChildPath $SubPath_Streaming

        if (Test-Path $fullStreamingPath) {
            Write-Host "`nFolder found! Switching directory..." -ForegroundColor Green
            Set-Location $fullStreamingPath
            $validPathFound = $true
            Start-Sleep -Seconds 1
        } else {
            Write-Host "`nCould not find the StreamingAssets folder at:" -ForegroundColor Red
            Write-Host "$fullStreamingPath" -ForegroundColor DarkGray
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
    Write-Host "   GenshinSlimmer v4" -ForegroundColor Yellow
    Write-Host "   Created by dnullptr" -ForegroundColor DarkGray
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Target Base: ...\GenshinImpact_Data\StreamingAssets" -ForegroundColor DarkGray
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
        [string]$RelativePath,
        [array]$Patterns
    )
    
    $fullPath = Join-Path (Get-Location) $RelativePath
    
    # If folder doesn't exist (e.g. user never played UGC), return empty list
    if (-not (Test-Path $fullPath)) {
        return @()
    }

    # Find files matching patterns
    return Get-ChildItem -Path $fullPath -File | Where-Object { 
        $name = $_.Name
        $matched = $false
        foreach ($pattern in $Patterns) {
            if ($name -like $pattern) { $matched = $true; break }
        }
        $matched
    }
}

function Process-Stubbing {
    param (
        [array]$FilesToStub,
        [string]$Description
    )

    # Filter out files that are already 0 bytes to avoid inflating stats
    $ActiveFiles = $FilesToStub | Where-Object { $_.Length -gt 0 }

    if ($ActiveFiles.Count -eq 0) {
        Write-Host "`nNo stubbable files found for: $Description" -ForegroundColor Yellow
        Write-Host "(Files are either missing or already optimized/empty)" -ForegroundColor DarkGray
        Read-Host "Press Enter to continue..."
        return
    }

    # --- CALCULATE SIZE ---
    $totalBytes = ($ActiveFiles | Measure-Object -Property Length -Sum).Sum
    $totalMB = [math]::Round($totalBytes / 1MB, 2)
    $totalGB = [math]::Round($totalBytes / 1GB, 2)

    # --- REPORT ---
    Write-Host "`n-----------------------------------------" -ForegroundColor DarkGray
    Write-Host "Selection:         $Description"
    Write-Host "Files Found:       " -NoNewline
    Write-Host "$($ActiveFiles.Count)" -ForegroundColor Yellow
    Write-Host "Potential Savings: " -NoNewline
    if ($totalGB -gt 1) {
        Write-Host "$totalGB GB" -ForegroundColor Green
    } else {
        Write-Host "$totalMB MB" -ForegroundColor Green
    }
    Write-Host "-----------------------------------------" -ForegroundColor DarkGray
    
    Write-Host "Preview:" -ForegroundColor Gray
    $ActiveFiles.Name | Select-Object -First 5 | ForEach-Object { Write-Host " - $_" -ForegroundColor DarkGray }
    if ($ActiveFiles.Count -gt 5) { Write-Host " ... and $($ActiveFiles.Count - 5) others." -ForegroundColor DarkGray }

    Write-Host ""
    Write-Host "This will replace the files with empty (0KB) stubs." -ForegroundColor Cyan
    $confirmation = Read-Host "Are you sure? (Y/N)"
    
    if ($confirmation -eq 'Y' -or $confirmation -eq 'y') {
        $stubbedCount = 0
        $savedSize = 0
        foreach ($file in $ActiveFiles) {
            try {
                $size = $file.Length
                
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
            $selection = Get-MatchingFiles $RelPath_Videos $PatternsMondstadt 
            $desc = "Mondstadt Videos"
        }
        '2' { 
            $selection = Get-MatchingFiles $RelPath_Videos $PatternsLiyue 
            $desc = "Liyue Videos"
        }
        '3' { 
            $selection = Get-MatchingFiles $RelPath_Videos $PatternsSumeru 
            $desc = "Sumeru Videos"
        }
        '4' { 
            $selection = Get-MatchingFiles $RelPath_Videos $PatternsFontaine 
            $desc = "Fontaine Videos"
        }
        '5' { 
            $selection = Get-MatchingFiles $RelPath_Videos $PatternsNatlan 
            $desc = "Natlan Videos"
        }
        '6' {
            # Select ALL files in the UGC folder
            $selection = Get-MatchingFiles $RelPath_UGC @("*")
            $desc = "UGC Cache (BeyondUGC)"
        }
        '7' {
            $selection = Get-MatchingFiles $RelPath_Videos $PatternsBoy
            $desc = "Boy/Aether Videos (Global)"
        }
        '8' {
            $selection = Get-MatchingFiles $RelPath_Videos $PatternsGirl
            $desc = "Girl/Lumine Videos (Global)"
        }
        '9' { 
            # Combine ALL videos + ALL UGC
            $AllVideoPatterns = $PatternsMondstadt + $PatternsLiyue + $PatternsSumeru + $PatternsFontaine + $PatternsNatlan
            $selection += Get-MatchingFiles $RelPath_Videos $AllVideoPatterns
            $selection += Get-MatchingFiles $RelPath_UGC @("*")
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
