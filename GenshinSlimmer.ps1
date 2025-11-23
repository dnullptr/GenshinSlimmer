<#
.SYNOPSIS
    Genshin Impact Slimmer
    For now: Deletes cutscenes from specific regions to save disk space.
    
    Author: dnullptr
#>

function Get-GamePath {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "   GenshinSlimmer v1 Setup" -ForegroundColor Yellow
    Write-Host "   Created by dnullptr" -ForegroundColor DarkGray
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Please paste the path to your 'Genshin Impact game' folder." -ForegroundColor White
    Write-Host "Example: D:\Games\Genshin Impact\Genshin Impact game" -ForegroundColor Gray
    Write-Host ""
    
    $validPathFound = $false
    $targetSubPath = "GenshinImpact_Data\StreamingAssets\VideoAssets\StandaloneWindows64"

    while (-not $validPathFound) {
        $userInput = Read-Host "Paste Path Here"
        
        # Remove surrounding quotes if the user pasted them
        $userInput = $userInput -replace '"', ''
        
        # Construct the full path to the videos
        $fullVideoPath = Join-Path -Path $userInput -ChildPath $targetSubPath

        if (Test-Path $fullVideoPath) {
            Write-Host "`nFolder found! Switching directory..." -ForegroundColor Green
            Set-Location $fullVideoPath
            $validPathFound = $true
            Start-Sleep -Seconds 1
        } else {
            Write-Host "`nCould not find the video folder at:" -ForegroundColor Red
            Write-Host "$fullVideoPath" -ForegroundColor DarkGray
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

function Show-Menu {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "   GenshinSlimmer v1" -ForegroundColor Yellow
    Write-Host "   Created by dnullptr" -ForegroundColor DarkGray
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Target: ...\VideoAssets\StandaloneWindows64" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Select a region to delete video files for:"
    Write-Host "1. Mondstadt (Matches *Mengde*, *MDAQ*, *Venti*)"
    Write-Host "2. Liyue     (Matches *LiYue*, *LYAQ*)"
    Write-Host "3. Sumeru    (Matches *Sumeru*)"
    Write-Host "4. Fontaine  (Matches *Fontaine*)"
    Write-Host "5. Natlan    (Matches *Natlan*)"
    Write-Host "-----------------------------------------" -ForegroundColor DarkGray
    Write-Host "6. ALL ABOVE (Delete files for all 5 regions)" -ForegroundColor Magenta
    Write-Host "-----------------------------------------" -ForegroundColor DarkGray
    Write-Host "Q. Quit"
    Write-Host "=========================================" -ForegroundColor Cyan
}

function Delete-RegionFiles {
    param (
        [string]$RegionName,
        [array]$Patterns
    )

    Write-Host "`nSearching for $RegionName files..." -ForegroundColor Cyan
    
    # Get files in current dir (we are already in the video folder)
    $allFiles = Get-ChildItem -File
    
    $filesToDelete = $allFiles | Where-Object { 
        $name = $_.Name
        $matched = $false
        foreach ($pattern in $Patterns) {
            if ($name -like $pattern) { $matched = $true; break }
        }
        $matched
    }

    if ($filesToDelete.Count -eq 0) {
        Write-Host "No files found for $RegionName." -ForegroundColor Yellow
        Read-Host "Press Enter to continue..."
        return
    }

    # --- CALCULATE SIZE ---
    $totalBytes = ($filesToDelete | Measure-Object -Property Length -Sum).Sum
    $totalMB = [math]::Round($totalBytes / 1MB, 2)
    $totalGB = [math]::Round($totalBytes / 1GB, 2)

    # --- REPORT ---
    Write-Host "-----------------------------------------" -ForegroundColor DarkGray
    Write-Host "Files Found:       " -NoNewline
    Write-Host "$($filesToDelete.Count)" -ForegroundColor Yellow
    Write-Host "Potential Savings: " -NoNewline
    if ($totalGB -gt 1) {
        Write-Host "$totalGB GB" -ForegroundColor Green
    } else {
        Write-Host "$totalMB MB" -ForegroundColor Green
    }
    Write-Host "-----------------------------------------" -ForegroundColor DarkGray
    
    Write-Host "Preview:" -ForegroundColor Gray
    $filesToDelete.Name | Select-Object -First 5 | ForEach-Object { Write-Host " - $_" -ForegroundColor DarkGray }
    if ($filesToDelete.Count -gt 5) { Write-Host " ... and $($filesToDelete.Count - 5) others." -ForegroundColor DarkGray }

    Write-Host ""
    $confirmation = Read-Host "Are you sure you want to delete these files to save space? (Y/N)"
    
    if ($confirmation -eq 'Y' -or $confirmation -eq 'y') {
        $deletedCount = 0
        $deletedSize = 0
        foreach ($file in $filesToDelete) {
            try {
                $size = $file.Length
                Remove-Item $file.FullName -Force -ErrorAction Stop
                Write-Host "Deleted: $($file.Name)" -ForegroundColor DarkGray
                $deletedCount++
                $deletedSize += $size
            }
            catch {
                Write-Host "Error deleting $($file.Name): $_" -ForegroundColor Red
            }
        }
        $finalSavedGB = [math]::Round($deletedSize / 1GB, 2)
        Write-Host "`nSuccess! Cleaned $deletedCount files." -ForegroundColor Green
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

    switch ($choice) {
        '1' { Delete-RegionFiles -RegionName "Mondstadt" -Patterns $PatternsMondstadt }
        '2' { Delete-RegionFiles -RegionName "Liyue"     -Patterns $PatternsLiyue }
        '3' { Delete-RegionFiles -RegionName "Sumeru"    -Patterns $PatternsSumeru }
        '4' { Delete-RegionFiles -RegionName "Fontaine"  -Patterns $PatternsFontaine }
        '5' { Delete-RegionFiles -RegionName "Natlan"    -Patterns $PatternsNatlan }
        '6' { 
            $AllPatterns = $PatternsMondstadt + $PatternsLiyue + $PatternsSumeru + $PatternsFontaine + $PatternsNatlan
            Delete-RegionFiles -RegionName "ALL REGIONS" -Patterns $AllPatterns 
        }
        'Q' { Write-Host "Exiting..."; break }
        'q' { Write-Host "Exiting..."; break }
        default { 
            Write-Host "Invalid selection." -ForegroundColor Red
            Start-Sleep -Milliseconds 500
        }
    }
} until ($choice -eq 'Q' -or $choice -eq 'q')