<#
    GenshinSlimmer v13 - WPF Dark GUI Edition
    - Full dark-themed graphical interface for GenshinSlimmer v13.
    - Supports all v13 features:
      * Split Snezhnaya 7.0-7.1 (safe before 7.2 AQ) and Snezhnaya 7.2 (7.2 AQ)
      * Safe presets (Up to 7.1 + Boy / Girl / No Gender, keeping 7.2 AQ untouched)
      * 7.x Manifest Synchronization Engine (res_versions_persist + audio/persist variants, fileSize=0, md5 + 7.1 hash)
      * Experimental Launcher pkg_version Sync & Revert ([P])
      * In-Game Revision Manager (R / S / D revisions)
      * Unlock / Restore & Legacy ACL Stripper ([U])
      * NTFS LZX Compression ([C])
    - Shares path.ini with GenshinSlimmer.ps1.

    Author: dnullptr
#>

# --- SELF-ELEVATION & STA THREAD REQUIREMENT ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$isSta   = ([System.Threading.Thread]::CurrentThread.GetApartmentState() -eq 'STA')

if (-not $isAdmin -or -not $isSta) {
    $scriptPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Definition }
    if ($scriptPath) {
        try {
            $argList = "-NoProfile -STA -ExecutionPolicy Bypass -File `"$scriptPath`""
            Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Verb RunAs
            exit
        } catch {
            Write-Host "Failed to launch elevated GUI: $_" -ForegroundColor Red
            exit
        }
    }
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# --- CORE CONSTANTS & PATTERNS (v13) ---
$script:EmptyMd5  = "d41d8cd98f00b204e9800998ecf8427e"
$script:EmptyHash = "ef46db3751d8e999"

$script:VideoSearchPaths = @(
    "GenshinImpact_Data\StreamingAssets\VideoAssets\StandaloneWindows64",
    "GenshinImpact_Data\Persistent\VideoAssets\StandaloneWindows64"
)
$script:UGCSearchPaths = @(
    "GenshinImpact_Data\StreamingAssets\AudioAssets\BeyondUGC",
    "GenshinImpact_Data\Persistent\AudioAssets\BeyondUGC"
)

$script:PatternsMondstadt   = @("*Mengde*", "*MDAQ*", "*Venti*", "*WDLQ*", "*Ambor*", "*Cs_102*")
$script:PatternsLiyue       = @("*LiYue*", "*LYAQ*", "*LY_*", "*LQ10*", "*LQ11*", "*XiaoPersonal*", "*ShenheBattle*", "*YunjinOpera*")
$script:PatternsInazuma     = @("*Inazuma*", "*DaoQi*", "*200803*", "*200806*", "*200919*", "*201104*", "*200211*", "*LQ12*", "*ShougunBoss*", "*WanYeXian*")
$script:PatternsSumeru      = @("*Sumeru*", "*Xm_*", "*LQ13*")
$script:PatternsFontaine    = @("*Fontaine*", "*LQ14*")
$script:PatternsNatlan      = @("*Natlan*", "*LQ15*")
$script:PatternsNodKrai     = @("*NodKrai*", "*NK_*", "*LQ16*")
$script:PatternsSnezhnaya   = @("*AQ7008*", "*AQ7009*", "*AQ7013*", "*AQ7017*", "*AQ7019*", "*AQ7020*", "*ZD70*", "*ZD71*", "*AQ70_*", "*AQ71*")
$script:PatternsSnezhnaya72 = @("*AQ7023*", "*AQ7025*", "*AQ7031*", "*ZD72*", "*AQ72*", "*LQ17*")
$script:PatternsMisc        = @("*battlePass*", "*ChangeWeather*", "*EQ*", "*FD_*", "*GY*", "*Memories*", "*Reunion*", "*ShieldingResources*", "*Backstory*")
$script:PatternsBoy         = @("*Boy*.usm*", "*PlayerBoy*.usm*")
$script:PatternsGirl        = @("*Girl*.usm*", "*PlayerGirl*.usm*")

$script:CategoryDefinitions = @(
    @{ Id = "Mondstadt";   Name = "1. Mondstadt";                    Sub = "Prologue (Cs_102*), Venti, Stormterror";          Paths = $script:VideoSearchPaths; Patterns = $script:PatternsMondstadt;   Exclude = @();                       SafePreset = $true;  Warn = $false }
    @{ Id = "Liyue";       Name = "2. Liyue";                        Sub = "Archon Quests, Shenhe, Yunjin, Xiao, Lantern Rite"; Paths = $script:VideoSearchPaths; Patterns = $script:PatternsLiyue;       Exclude = @();                       SafePreset = $true;  Warn = $false }
    @{ Id = "Inazuma";     Name = "3. Inazuma";                      Sub = "Raiden Shogun, Kazuha, Story & Archon Quests";     Paths = $script:VideoSearchPaths; Patterns = $script:PatternsInazuma;     Exclude = @();                       SafePreset = $true;  Warn = $false }
    @{ Id = "Sumeru";      Name = "4. Sumeru";                       Sub = "Akasha, Nahida, Scaramouche, Desert Quests";       Paths = $script:VideoSearchPaths; Patterns = $script:PatternsSumeru;      Exclude = @();                       SafePreset = $true;  Warn = $false }
    @{ Id = "Fontaine";    Name = "5. Fontaine";                     Sub = "Masquerade of the Guilty, Furina, Neuvillette";    Paths = $script:VideoSearchPaths; Patterns = $script:PatternsFontaine;    Exclude = @();                       SafePreset = $true;  Warn = $false }
    @{ Id = "Natlan";      Name = "6. Natlan";                       Sub = "Incandescent Ode of Resurrection, Mavuika";        Paths = $script:VideoSearchPaths; Patterns = $script:PatternsNatlan;      Exclude = @();                       SafePreset = $true;  Warn = $false }
    @{ Id = "NodKrai";     Name = "7. Nod-Krai";                     Sub = "Nod-Krai Prelude & World Quests";                  Paths = $script:VideoSearchPaths; Patterns = $script:PatternsNodKrai;     Exclude = @();                       SafePreset = $true;  Warn = $false }
    @{ Id = "Snezhnaya71"; Name = "8. Snezhnaya 7.0-7.1 (Up to 7.1)"; Sub = "AQ7008-AQ7020 - Safe before playing 7.2 AQ";      Paths = $script:VideoSearchPaths; Patterns = $script:PatternsSnezhnaya;   Exclude = @();                       SafePreset = $true;  Warn = $false }
    @{ Id = "Snezhnaya72"; Name = "8b. Snezhnaya 7.2 (7.2 AQ)";      Sub = "WARNING: Finish 7.2 Archon Quest before stubbing!"; Paths = $script:VideoSearchPaths; Patterns = $script:PatternsSnezhnaya72; Exclude = @();                       SafePreset = $false; Warn = $true  }
    @{ Id = "Misc";        Name = "9. Expired Events & Misc";        Sub = "BattlePass, Reunion, Backstory, Seasonal Events";  Paths = $script:VideoSearchPaths; Patterns = $script:PatternsMisc;        Exclude = @();                       SafePreset = $true;  Warn = $false }
    @{ Id = "UGC";         Name = "10. UGC Cache (BeyondUGC)";       Sub = "Miliastra Wonderland / BeyondUGC Audio Cache";     Paths = $script:UGCSearchPaths;   Patterns = @("*");                      Exclude = @();                       SafePreset = $true;  Warn = $false }
    @{ Id = "Boy";         Name = "11. 'Boy' Traveler Cutscenes";    Sub = "Stub Aether variants (up to 7.1, keeps 7.2 AQ)";   Paths = $script:VideoSearchPaths; Patterns = $script:PatternsBoy;         Exclude = $script:PatternsSnezhnaya72; SafePreset = $false; Warn = $false }
    @{ Id = "Girl";        Name = "12. 'Girl' Traveler Cutscenes";   Sub = "Stub Lumine variants (up to 7.1, keeps 7.2 AQ)";   Paths = $script:VideoSearchPaths; Patterns = $script:PatternsGirl;        Exclude = $script:PatternsSnezhnaya72; SafePreset = $false; Warn = $false }
)

# --- BACKEND ENGINE FUNCTIONS ---
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
        if ($modified) { $file.SetAccessControl($acl) }
    } catch {}
}

function Get-MatchingFiles {
    param ([string]$GameRoot, [array]$RelativePaths, [array]$Patterns, [array]$ExcludePatterns = @())
    $AllFiles = @()
    if (-not $GameRoot -or -not (Test-Path -LiteralPath $GameRoot)) { return $AllFiles }

    foreach ($rel in $RelativePaths) {
        $fullPath = Join-Path $GameRoot $rel
        if (Test-Path -LiteralPath $fullPath) {
            $files = Get-ChildItem -Path $fullPath -File -ErrorAction SilentlyContinue | Where-Object {
                $name = $_.Name
                $matched = $false
                foreach ($pattern in $Patterns) { if ($name -like $pattern) { $matched = $true; break } }
                if ($matched -and $ExcludePatterns.Count -gt 0) {
                    foreach ($ex in $ExcludePatterns) { if ($name -like $ex) { $matched = $false; break } }
                }
                $matched
            }
            $AllFiles += $files
        }
    }
    return $AllFiles
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
                Where-Object { ($_.Name -like "*versions*persist*" -or $_.Name -like "audio_versions*" -or $_.Name -like "*audio*versions*") -and $_.Name -notlike "*.bak" -and $_.FullName -notlike "*.bak" }
            foreach ($f in $found) {
                if ($candidates -notcontains $f.FullName) { $candidates += $f.FullName }
            }
        } catch {}
    }
    return @($candidates | Select-Object -Unique)
}

function Get-StubbedFileMap {
    param ([string]$GameRoot)
    $exactMap = @{}
    $nameMap  = @{}
    foreach ($relPath in $script:VideoSearchPaths) {
        $fullPath = Join-Path $GameRoot $relPath
        if (Test-Path -LiteralPath $fullPath) {
            $files = Get-ChildItem -Path $fullPath -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -eq 0 }
            foreach ($f in $files) {
                $cleanName = if ($f.Name -like "*.bak") { $f.Name.Substring(0, $f.Name.Length - 4) } else { $f.Name }
                $exactMap["StandaloneWindows64/$cleanName"] = $true
                $nameMap[$cleanName.ToLower()] = $true
            }
        }
    }
    foreach ($relPath in $script:UGCSearchPaths) {
        $fullPath = Join-Path $GameRoot $relPath
        if (Test-Path -LiteralPath $fullPath) {
            $files = Get-ChildItem -Path $fullPath -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -eq 0 }
            foreach ($f in $files) {
                $cleanName = if ($f.Name -like "*.bak") { $f.Name.Substring(0, $f.Name.Length - 4) } else { $f.Name }
                $exactMap["BeyondUGC/$cleanName"] = $true
                $nameMap[$cleanName.ToLower()] = $true
            }
        }
    }
    return @{ Exact = $exactMap; Names = $nameMap }
}

function Sync-ManifestEngine {
    param ([string]$GameRoot)
    $manifestPaths = @(Get-ManifestCandidates -GameRoot $GameRoot)
    if ($manifestPaths.Count -eq 0) { return 0 }

    $persistentDir = Join-Path $GameRoot "GenshinImpact_Data\Persistent"
    Remove-Item -Path (Join-Path $persistentDir "VideoAssets") -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path (Join-Path $persistentDir "*versions_remote*") -Force -ErrorAction SilentlyContinue

    $maps = Get-StubbedFileMap -GameRoot $GameRoot
    $stubbedMap   = $maps.Exact
    $stubbedNames = $maps.Names
    $totalPatched = 0

    foreach ($persistPath in $manifestPaths) {
        $lines = Get-Content -LiteralPath $persistPath -Encoding utf8
        $backupPath = "$persistPath.bak"
        $isPristine = -not ($lines | Select-String -SimpleMatch $script:EmptyMd5 -Quiet)
        if ($isPristine -or -not (Test-Path -LiteralPath $backupPath)) {
            try { Copy-Item -LiteralPath $persistPath -Destination $backupPath -Force } catch {}
        }

        $output = [System.Collections.Generic.List[string]]::new($lines.Count)
        $patchedCount = 0

        foreach ($line in $lines) {
            $matched = $false
            if ($line -match '"remoteName":\s*"([^"]+)"') {
                $remoteName = $matches[1]
                $fileName   = $remoteName.Split('/')[-1].ToLower()
                if ($stubbedMap.ContainsKey($remoteName) -or $stubbedNames.ContainsKey($fileName)) {
                    $newLine = $line -replace '"fileSize":\s*\d+', '"fileSize": 0' `
                                     -replace '"md5":\s*"[^"]+"', "`"md5`": `"$($script:EmptyMd5)`""
                    if ($newLine -match '"hash":') {
                        $newLine = $newLine -replace '"hash":\s*"[^"]+"', "`"hash`": `"$($script:EmptyHash)`""
                    }
                    $output.Add($newLine)
                    $patchedCount++
                    $matched = $true
                }
            }
            if (-not $matched) { $output.Add($line) }
        }

        Remove-FileLock -Path $persistPath
        try {
            [System.IO.File]::WriteAllLines($persistPath, $output, [System.Text.UTF8Encoding]::new($false))
            $totalPatched += $patchedCount
        } catch {}
    }
    return $totalPatched
}

function Restore-ManifestEngine {
    param ([string]$GameRoot, [array]$FileNamesToRestore)
    $manifestPaths = @(Get-ManifestCandidates -GameRoot $GameRoot)
    if ($manifestPaths.Count -eq 0) { return 0 }

    $lookupExact  = @{}
    $lookupByName = @{}
    $streamingDir = Join-Path $GameRoot "GenshinImpact_Data\StreamingAssets"
    if (Test-Path -LiteralPath $streamingDir) {
        $streamingManifests = Get-ChildItem -Path $streamingDir -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { ($_.Name -like "*versions*streaming*" -or $_.Name -like "res_versions_streaming" -or $_.Name -like "audio_versions*") -and $_.Name -notlike "*.bak" }
        $classicStreaming = Join-Path $streamingDir "res_versions_streaming"
        $allStreaming = @($streamingManifests.FullName) + @($classicStreaming) | Select-Object -Unique
        foreach ($sp in $allStreaming) {
            if (-not $sp -or -not (Test-Path -LiteralPath $sp)) { continue }
            foreach ($line in (Get-Content -LiteralPath $sp -Encoding utf8 -ErrorAction SilentlyContinue)) {
                if ($line -match '"remoteName":\s*"([^"]+)"') {
                    $rn = $matches[1]
                    if (-not $lookupExact.ContainsKey($rn)) { $lookupExact[$rn] = $line }
                    $fn = $rn.Split('/')[-1].ToLower()
                    if (-not $lookupByName.ContainsKey($fn)) { $lookupByName[$fn] = $line }
                }
            }
        }
    }
    if ($lookupExact.Count -eq 0) { return 0 }

    $restoreNames = @{}
    foreach ($fn in $FileNamesToRestore) {
        $cleanName = if ($fn -like "*.bak") { $fn.Substring(0, $fn.Length - 4) } else { $fn }
        $restoreNames[$cleanName.ToLower()] = $true
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
                $fileName   = $remoteName.Split('/')[-1].ToLower()
                if ($restoreNames.ContainsKey($fileName)) {
                    if ($lookupExact.ContainsKey($remoteName)) {
                        $output.Add($lookupExact[$remoteName]); $restoredCount++; $matched = $true
                    } elseif ($lookupByName.ContainsKey($fileName)) {
                        $output.Add($lookupByName[$fileName]); $restoredCount++; $matched = $true
                    }
                }
            }
            if (-not $matched) { $output.Add($line) }
        }
        Remove-FileLock -Path $persistPath
        try {
            [System.IO.File]::WriteAllLines($persistPath, $output, [System.Text.UTF8Encoding]::new($false))
            $totalRestored += $restoredCount
        } catch {}
    }
    return $totalRestored
}

function Sync-PkgVersionEngine {
    param ([string]$GameRoot)
    $pkgPath = Join-Path $GameRoot "pkg_version"
    if (-not (Test-Path -LiteralPath $pkgPath)) { return 0 }

    $stubbed = @{}
    foreach ($rel in ($script:VideoSearchPaths + $script:UGCSearchPaths)) {
        $fullPath = Join-Path $GameRoot $rel
        if (-not (Test-Path -LiteralPath $fullPath)) { continue }
        $zeroFiles = Get-ChildItem -Path $fullPath -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -eq 0 }
        foreach ($f in $zeroFiles) {
            $cleanName = if ($f.Name -like "*.bak") { $f.Name.Substring(0, $f.Name.Length - 4) } else { $f.Name }
            $stubbed[(($rel -replace '\\', '/') + "/" + $cleanName).ToLower()] = $true
        }
    }

    $lines = Get-Content -LiteralPath $pkgPath -Encoding utf8
    $backupPath = "$pkgPath.bak"
    $isPristine = -not ($lines | Select-String -SimpleMatch $script:EmptyMd5 -Quiet)
    if ($isPristine -or -not (Test-Path -LiteralPath $backupPath)) {
        try { Copy-Item -LiteralPath $pkgPath -Destination $backupPath -Force } catch {}
    }

    $output = [System.Collections.Generic.List[string]]::new($lines.Count)
    $patched = 0
    foreach ($line in $lines) {
        $done = $false
        if ($line -match '"remoteName":\s*"([^"]+)"') {
            if ($stubbed.ContainsKey($matches[1].ToLower())) {
                $newLine = $line -replace '"fileSize":\s*\d+', '"fileSize": 0' `
                                 -replace '"md5":\s*"[^"]+"', "`"md5`": `"$($script:EmptyMd5)`""
                if ($newLine -match '"hash":') {
                    $newLine = $newLine -replace '"hash":\s*"[^"]+"', "`"hash`": `"$($script:EmptyHash)`""
                }
                $output.Add($newLine)
                $patched++
                $done = $true
            }
        }
        if (-not $done) { $output.Add($line) }
    }

    Remove-FileLock -Path $pkgPath
    try {
        [System.IO.File]::WriteAllLines($pkgPath, $output, [System.Text.UTF8Encoding]::new($false))
    } catch { return -1 }
    return $patched
}

function Restore-PkgVersionEngine {
    param ([string]$GameRoot, [array]$FileNamesToRestore = @())
    $pkgPath = Join-Path $GameRoot "pkg_version"
    $backupPath = "$pkgPath.bak"
    if (-not (Test-Path -LiteralPath $pkgPath) -or -not (Test-Path -LiteralPath $backupPath)) { return 0 }

    $restoreNames = @{}
    foreach ($fn in $FileNamesToRestore) {
        $cleanName = if ($fn -like "*.bak") { $fn.Substring(0, $fn.Length - 4) } else { $fn }
        $restoreNames[$cleanName.ToLower()] = $true
    }

    $bakLookup = @{}
    foreach ($line in (Get-Content -LiteralPath $backupPath -Encoding utf8)) {
        if ($line -match '"remoteName":\s*"([^"]+)"') { $bakLookup[$matches[1].ToLower()] = $line }
    }

    $lines = Get-Content -LiteralPath $pkgPath -Encoding utf8
    $output = [System.Collections.Generic.List[string]]::new($lines.Count)
    $restored = 0
    foreach ($line in $lines) {
        $done = $false
        if ($line -like "*$($script:EmptyMd5)*" -and $line -match '"remoteName":\s*"([^"]+)"') {
            $key = $matches[1].ToLower()
            $fileName = $key.Split('/')[-1]
            if ($bakLookup.ContainsKey($key) -and $bakLookup[$key] -notlike "*$($script:EmptyMd5)*" -and
                ($restoreNames.Count -eq 0 -or $restoreNames.ContainsKey($fileName))) {
                $output.Add($bakLookup[$key])
                $restored++
                $done = $true
            }
        }
        if (-not $done) { $output.Add($line) }
    }

    if ($restored -gt 0) {
        Remove-FileLock -Path $pkgPath
        try {
            [System.IO.File]::WriteAllLines($pkgPath, $output, [System.Text.UTF8Encoding]::new($false))
        } catch { return -1 }
    }
    return $restored
}

# --- XAML UI DEFINITION ---
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="GenshinSlimmer v13 - Manifest-Sync &amp; Asset Optimizer"
        Width="1040" Height="780" MinWidth="920" MinHeight="680"
        WindowStartupLocation="CenterScreen"
        Background="#0D1117" Foreground="#E6EDF3"
        FontFamily="Segoe UI">
    <Window.Resources>
        <Style x:Key="CardBorder" TargetType="Border">
            <Setter Property="Background" Value="#161B22"/>
            <Setter Property="BorderBrush" Value="#30363D"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CornerRadius" Value="8"/>
            <Setter Property="Padding" Value="14,10"/>
        </Style>
        <Style x:Key="BtnBase" TargetType="Button">
            <Setter Property="Background" Value="#21262D"/>
            <Setter Property="Foreground" Value="#E6EDF3"/>
            <Setter Property="BorderBrush" Value="#363B42"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="12,6"/>
            <Setter Property="FontSize" Value="12.5"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bd" Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="6" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="BorderBrush" Value="#58A6FF"/>
                                <Setter TargetName="bd" Property="Opacity" Value="0.92"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="bd" Property="Opacity" Value="0.75"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="bd" Property="Opacity" Value="0.45"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid Margin="18,14,18,14">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="115"/>
        </Grid.RowDefinitions>

        <!-- HEADER & PATH BAR -->
        <Grid Grid.Row="0" Margin="0,0,0,10">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,18,0">
                <Border Background="#1F6FEB" Width="6" Height="34" CornerRadius="3" Margin="0,0,10,0"/>
                <StackPanel>
                    <StackPanel Orientation="Horizontal">
                        <TextBlock Text="GenshinSlimmer" FontSize="20" FontWeight="Bold" Foreground="#F0F6FC"/>
                        <Border Background="#238636" CornerRadius="4" Padding="6,1" Margin="8,0,0,0" VerticalAlignment="Center">
                            <TextBlock Text="v13 (7.2 Ready)" FontSize="11" FontWeight="Bold" Foreground="#FFFFFF"/>
                        </Border>
                    </StackPanel>
                    <TextBlock Text="Manifest-Sync Engine  |  Split 7.1 / 7.2 Snezhnaya  |  Launcher pkg_version Sync" FontSize="11.5" Foreground="#8B949E"/>
                </StackPanel>
            </StackPanel>

            <Border Grid.Column="1" Background="#161B22" BorderBrush="#30363D" BorderThickness="1" CornerRadius="6" Padding="8,4" VerticalAlignment="Center">
                <DockPanel>
                    <TextBlock Text="Game Path:" Foreground="#8B949E" VerticalAlignment="Center" Margin="2,0,8,0" FontSize="12"/>
                    <TextBox x:Name="TxtGamePath" Background="Transparent" BorderThickness="0" Foreground="#E6EDF3"
                             VerticalContentAlignment="Center" FontSize="12.5"/>
                </DockPanel>
            </Border>

            <Button x:Name="BtnBrowse" Grid.Column="2" Style="{StaticResource BtnBase}" Content="Browse..." Margin="8,0,0,0" VerticalAlignment="Center"/>
            <Button x:Name="BtnRescan" Grid.Column="3" Style="{StaticResource BtnBase}" Content="Rescan" Background="#1F6FEB" BorderBrush="#388BFD" Margin="8,0,0,0" VerticalAlignment="Center"/>
        </Grid>

        <!-- SUMMARY STATS CARDS -->
        <Grid Grid.Row="1" Margin="0,0,0,10">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="10"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="10"/>
                <ColumnDefinition Width="1.25*"/>
            </Grid.ColumnDefinitions>

            <Border Grid.Column="0" Style="{StaticResource CardBorder}">
                <StackPanel>
                    <TextBlock Text="ACTIVE STUBBABLE DATA" FontSize="10.5" FontWeight="Bold" Foreground="#8B949E"/>
                    <StackPanel Orientation="Horizontal" Margin="0,4,0,0">
                        <TextBlock x:Name="LblTotalActiveGB" Text="0.00 GB" FontSize="20" FontWeight="Bold" Foreground="#58A6FF"/>
                        <TextBlock x:Name="LblSelectedGB" Text=" (0.00 GB selected)" FontSize="12.5" Foreground="#3FB950" VerticalAlignment="Bottom" Margin="8,0,0,2"/>
                    </StackPanel>
                    <TextBlock x:Name="LblTotalFilesSummary" Text="0 active files / 0 stubbed (0KB)" FontSize="11.5" Foreground="#8B949E" Margin="0,2,0,0"/>
                </StackPanel>
            </Border>

            <Border Grid.Column="2" Style="{StaticResource CardBorder}">
                <StackPanel>
                    <TextBlock Text="MANIFEST &amp; LAUNCHER SYNC STATUS" FontSize="10.5" FontWeight="Bold" Foreground="#8B949E"/>
                    <StackPanel Orientation="Horizontal" Margin="0,4,0,0">
                        <TextBlock x:Name="LblManifestSynced" Text="0 synced" FontSize="20" FontWeight="Bold" Foreground="#3FB950"/>
                        <TextBlock Text=" in res_versions_persist" FontSize="12" Foreground="#8B949E" VerticalAlignment="Bottom" Margin="4,0,0,2"/>
                    </StackPanel>
                    <TextBlock x:Name="LblPkgVersionStatus" Text="Launcher pkg_version: 0 entries patched" FontSize="11.5" Foreground="#D2A8FF" Margin="0,2,0,0"/>
                </StackPanel>
            </Border>

            <Border Grid.Column="4" Style="{StaticResource CardBorder}">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Grid.Column="0">
                        <TextBlock Text="IN-GAME REVISION MANAGER (R / S / D)" FontSize="10.5" FontWeight="Bold" Foreground="#8B949E"/>
                        <TextBlock x:Name="LblVersionString" Text="OSRELWin7.2.0_R..._S..._D..." FontSize="13.5" FontWeight="Bold" Foreground="#E3B341" Margin="0,4,0,2"/>
                        <StackPanel Orientation="Horizontal">
                            <TextBlock Text="Resource Rev (R):" FontSize="11.5" Foreground="#8B949E" VerticalAlignment="Center" Margin="0,0,6,0"/>
                            <TextBox x:Name="TxtResRevision" Width="90" Background="#0D1117" Foreground="#E6EDF3" BorderBrush="#30363D"
                                     BorderThickness="1" Padding="5,2" FontSize="12"/>
                            <Button x:Name="BtnSaveRevision" Style="{StaticResource BtnBase}" Content="Update R" Padding="8,2" FontSize="11.5" Margin="6,0,0,0"/>
                        </StackPanel>
                    </StackPanel>
                </Grid>
            </Border>
        </Grid>

        <!-- PRESET SELECTION BAR -->
        <Border Grid.Row="2" Background="#161B22" BorderBrush="#30363D" BorderThickness="1" CornerRadius="6" Padding="10,7" Margin="0,0,0,10">
            <DockPanel>
                <TextBlock Text="Quick Presets (Safe for 7.2 AQ):" FontWeight="SemiBold" Foreground="#C9D1D9" VerticalAlignment="Center" Margin="0,0,10,0" FontSize="12"/>
                <Button x:Name="BtnPresetBoy" Style="{StaticResource BtnBase}" Content="Up to 7.1 + Boy (Play as Lumine)" Background="#122D42" BorderBrush="#1F6FEB" Margin="0,0,6,0"/>
                <Button x:Name="BtnPresetGirl" Style="{StaticResource BtnBase}" Content="Up to 7.1 + Girl (Play as Aether)" Background="#2E1836" BorderBrush="#8957E5" Margin="0,0,6,0"/>
                <Button x:Name="BtnPresetNoGender" Style="{StaticResource BtnBase}" Content="Up to 7.1 (No Gender)" Margin="0,0,6,0"/>
                <Button x:Name="BtnSelectAll" Style="{StaticResource BtnBase}" Content="All (+7.2)" Margin="0,0,6,0"/>
                <Button x:Name="BtnSelectNone" Style="{StaticResource BtnBase}" Content="Clear" HorizontalAlignment="Left"/>
            </DockPanel>
        </Border>

        <!-- CATEGORY TABLE -->
        <Border Grid.Row="3" Background="#161B22" BorderBrush="#30363D" BorderThickness="1" CornerRadius="8" Padding="6">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                <Grid Grid.Row="0" Margin="10,4,18,6">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="36"/>
                        <ColumnDefinition Width="240"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="90"/>
                        <ColumnDefinition Width="130"/>
                    </Grid.ColumnDefinitions>
                    <TextBlock Grid.Column="0" Text="Use" FontSize="11" FontWeight="Bold" Foreground="#8B949E"/>
                    <TextBlock Grid.Column="1" Text="Category / Region" FontSize="11" FontWeight="Bold" Foreground="#8B949E"/>
                    <TextBlock Grid.Column="2" Text="Included Cutscenes &amp; Assets" FontSize="11" FontWeight="Bold" Foreground="#8B949E"/>
                    <TextBlock Grid.Column="3" Text="Files" FontSize="11" FontWeight="Bold" Foreground="#8B949E" HorizontalAlignment="Right"/>
                    <TextBlock Grid.Column="4" Text="Status / Size" FontSize="11" FontWeight="Bold" Foreground="#8B949E" HorizontalAlignment="Right"/>
                </Grid>
                <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                    <StackPanel x:Name="CategoryListPanel"/>
                </ScrollViewer>
            </Grid>
        </Border>

        <!-- ACTION BUTTON BAR -->
        <Grid Grid.Row="4" Margin="0,10,0,10">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="1.5*"/>
                <ColumnDefinition Width="8"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="8"/>
                <ColumnDefinition Width="1.15*"/>
                <ColumnDefinition Width="8"/>
                <ColumnDefinition Width="1.15*"/>
                <ColumnDefinition Width="8"/>
                <ColumnDefinition Width="0.9*"/>
            </Grid.ColumnDefinitions>

            <Button x:Name="BtnStubSelected" Grid.Column="0" Style="{StaticResource BtnBase}"
                    Content="Stub Selected &amp; Sync Manifest" Background="#238636" BorderBrush="#2EA043" FontSize="13.5" Padding="14,9"/>
            <Button x:Name="BtnSyncManifest" Grid.Column="2" Style="{StaticResource BtnBase}"
                    Content="[M] Sync Manifests" Background="#1F6FEB" BorderBrush="#388BFD" Padding="10,9"/>
            <Button x:Name="BtnSyncPkg" Grid.Column="4" Style="{StaticResource BtnBase}"
                    Content="[P] Launcher pkg_version..." Background="#3B234A" BorderBrush="#8957E5" Padding="10,9"/>
            <Button x:Name="BtnUnlockRestore" Grid.Column="6" Style="{StaticResource BtnBase}"
                    Content="[U] Unlock / Restore..." Background="#4A3619" BorderBrush="#D29922" Padding="10,9"/>
            <Button x:Name="BtnCompress" Grid.Column="8" Style="{StaticResource BtnBase}"
                    Content="[C] LZX Compress" Padding="10,9"/>
        </Grid>

        <!-- ACTIVITY LOG -->
        <Border Grid.Row="5" Background="#090D11" BorderBrush="#30363D" BorderThickness="1" CornerRadius="6" Padding="8,6">
            <DockPanel>
                <TextBlock DockPanel.Dock="Top" Text="ACTIVITY LOG" FontSize="10" FontWeight="Bold" Foreground="#8B949E" Margin="0,0,0,3"/>
                <TextBox x:Name="TxtLog" Background="Transparent" Foreground="#C9D1D9" BorderThickness="0"
                         IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"
                         FontFamily="Consolas" FontSize="11.5"/>
            </DockPanel>
        </Border>
    </Grid>
</Window>
"@

# --- INSTANTIATE WINDOW & CONTROLS ---
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$TxtGamePath         = $window.FindName("TxtGamePath")
$BtnBrowse           = $window.FindName("BtnBrowse")
$BtnRescan           = $window.FindName("BtnRescan")
$LblTotalActiveGB    = $window.FindName("LblTotalActiveGB")
$LblSelectedGB       = $window.FindName("LblSelectedGB")
$LblTotalFilesSummary= $window.FindName("LblTotalFilesSummary")
$LblManifestSynced   = $window.FindName("LblManifestSynced")
$LblPkgVersionStatus = $window.FindName("LblPkgVersionStatus")
$LblVersionString    = $window.FindName("LblVersionString")
$TxtResRevision      = $window.FindName("TxtResRevision")
$BtnSaveRevision     = $window.FindName("BtnSaveRevision")
$BtnPresetBoy        = $window.FindName("BtnPresetBoy")
$BtnPresetGirl       = $window.FindName("BtnPresetGirl")
$BtnPresetNoGender   = $window.FindName("BtnPresetNoGender")
$BtnSelectAll        = $window.FindName("BtnSelectAll")
$BtnSelectNone       = $window.FindName("BtnSelectNone")
$CategoryListPanel   = $window.FindName("CategoryListPanel")
$BtnStubSelected     = $window.FindName("BtnStubSelected")
$BtnSyncManifest     = $window.FindName("BtnSyncManifest")
$BtnSyncPkg          = $window.FindName("BtnSyncPkg")
$BtnUnlockRestore    = $window.FindName("BtnUnlockRestore")
$BtnCompress         = $window.FindName("BtnCompress")
$TxtLog              = $window.FindName("TxtLog")

$script:CategoryRows = @{}
$baseDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$script:ConfigPath   = Join-Path $baseDir "path.ini"
$script:BrushConverter = New-Object System.Windows.Media.BrushConverter

function Get-Brush([string]$hex) {
    return $script:BrushConverter.ConvertFromString($hex)
}

function Write-GuiLog([string]$msg) {
    $ts = (Get-Date).ToString("HH:mm:ss")
    $TxtLog.AppendText("[$ts] $msg`r`n")
    $TxtLog.ScrollToEnd()
}

function Format-Bytes([long]$bytes) {
    if ($bytes -le 0) { return "0 MB" }
    if ($bytes -lt 1GB) { return ("{0:N1} MB" -f ($bytes / 1MB)) }
    return ("{0:N2} GB" -f ($bytes / 1GB))
}

# --- BUILD CATEGORY ROWS ---
foreach ($cat in $script:CategoryDefinitions) {
    $rowBorder = New-Object System.Windows.Controls.Border
    $rowBorder.Background      = Get-Brush $(if ($cat.Warn) { "#1E161B" } else { "#12171E" })
    $rowBorder.BorderBrush     = Get-Brush $(if ($cat.Warn) { "#5A2630" } else { "#21262D" })
    $rowBorder.BorderThickness = New-Object System.Windows.Thickness(1)
    $rowBorder.CornerRadius    = New-Object System.Windows.CornerRadius(6)
    $rowBorder.Margin          = New-Object System.Windows.Thickness(4, 2, 4, 2)
    $rowBorder.Padding         = New-Object System.Windows.Thickness(10, 7, 12, 7)

    $grid = New-Object System.Windows.Controls.Grid
    foreach ($w in @("36", "240", "*", "90", "130")) {
        $col = New-Object System.Windows.Controls.ColumnDefinition
        if ($w -eq "*") {
            $col.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        } else {
            $col.Width = New-Object System.Windows.GridLength([double]$w)
        }
        $grid.ColumnDefinitions.Add($col)
    }

    $chk = New-Object System.Windows.Controls.CheckBox
    $chk.IsChecked         = $cat.SafePreset
    $chk.VerticalAlignment = "Center"
    [System.Windows.Controls.Grid]::SetColumn($chk, 0)

    $lblName = New-Object System.Windows.Controls.TextBlock
    $lblName.Text              = $cat.Name
    $lblName.FontWeight        = "SemiBold"
    $lblName.FontSize          = 13
    $lblName.VerticalAlignment = "Center"
    $lblName.Foreground        = Get-Brush $(if ($cat.Warn) { "#FF7B72" } elseif ($cat.Id -eq "Snezhnaya71") { "#3FB950" } else { "#F0F6FC" })
    [System.Windows.Controls.Grid]::SetColumn($lblName, 1)

    $lblSub = New-Object System.Windows.Controls.TextBlock
    $lblSub.Text              = $cat.Sub
    $lblSub.FontSize          = 11.5
    $lblSub.VerticalAlignment = "Center"
    $lblSub.Foreground        = Get-Brush $(if ($cat.Warn) { "#FFA198" } else { "#8B949E" })
    [System.Windows.Controls.Grid]::SetColumn($lblSub, 2)

    $lblCount = New-Object System.Windows.Controls.TextBlock
    $lblCount.Text                = "0 files"
    $lblCount.FontSize            = 12
    $lblCount.VerticalAlignment   = "Center"
    $lblCount.HorizontalAlignment = "Right"
    $lblCount.Foreground          = Get-Brush "#C9D1D9"
    [System.Windows.Controls.Grid]::SetColumn($lblCount, 3)

    $badge = New-Object System.Windows.Controls.Border
    $badge.CornerRadius        = New-Object System.Windows.CornerRadius(4)
    $badge.Padding             = New-Object System.Windows.Thickness(8, 2, 8, 2)
    $badge.HorizontalAlignment = "Right"
    $badge.VerticalAlignment   = "Center"
    $badge.Background          = Get-Brush "#21262D"

    $lblSize = New-Object System.Windows.Controls.TextBlock
    $lblSize.Text       = "0 MB"
    $lblSize.FontSize   = 11.5
    $lblSize.FontWeight = "Bold"
    $lblSize.Foreground = Get-Brush "#8B949E"
    $badge.Child        = $lblSize
    [System.Windows.Controls.Grid]::SetColumn($badge, 4)

    $grid.Children.Add($chk)      | Out-Null
    $grid.Children.Add($lblName)  | Out-Null
    $grid.Children.Add($lblSub)   | Out-Null
    $grid.Children.Add($lblCount) | Out-Null
    $grid.Children.Add($badge)    | Out-Null
    $rowBorder.Child = $grid
    $CategoryListPanel.Children.Add($rowBorder) | Out-Null

    $chk.Add_Click({ Update-SelectedTotals })

    $script:CategoryRows[$cat.Id] = @{
        Def      = $cat
        CheckBox = $chk
        LblCount = $lblCount
        LblSize  = $lblSize
        Badge    = $badge
        Files    = @()
        Bytes    = [long]0
    }
}

function Get-SelectedDistinctFiles {
    $seen = @{}
    $list = @()
    foreach ($cat in $script:CategoryDefinitions) {
        $row = $script:CategoryRows[$cat.Id]
        if ($row.CheckBox.IsChecked) {
            foreach ($f in $row.Files) {
                if (-not $seen.ContainsKey($f.FullName)) {
                    $seen[$f.FullName] = $true
                    $list += $f
                }
            }
        }
    }
    return $list
}

function Update-SelectedTotals {
    $selFiles = Get-SelectedDistinctFiles
    $selBytes = [long]0
    foreach ($f in $selFiles) { $selBytes += $f.Length }
    $LblSelectedGB.Text = (" ({0} selected)" -f (Format-Bytes $selBytes))
}

function Refresh-GameScan {
    $gameRoot = $TxtGamePath.Text.Trim().Replace('"', '')
    $checkDir = Join-Path $gameRoot "GenshinImpact_Data"
    if (-not $gameRoot -or -not (Test-Path -LiteralPath $checkDir)) {
        Write-GuiLog "Game folder not found at '$gameRoot'. Use Browse... to select your 'Genshin Impact game' directory."
        return
    }

    try { $gameRoot | Out-File -FilePath $script:ConfigPath -Encoding utf8 -Force } catch {}

    $allSeen = @{}
    $totalActiveBytes = [long]0
    $totalActiveCount = 0
    $totalStubCount   = 0

    foreach ($cat in $script:CategoryDefinitions) {
        $row = $script:CategoryRows[$cat.Id]
        $files = @(Get-MatchingFiles -GameRoot $gameRoot -RelativePaths $cat.Paths -Patterns $cat.Patterns -ExcludePatterns $cat.Exclude)
        $bytes = [long]0
        foreach ($f in $files) {
            $bytes += $f.Length
            if (-not $allSeen.ContainsKey($f.FullName)) {
                $allSeen[$f.FullName] = $true
                if ($f.Length -eq 0) { $totalStubCount++ }
                else { $totalActiveCount++; $totalActiveBytes += $f.Length }
            }
        }

        $row.Files = $files
        $row.Bytes = $bytes
        $row.LblCount.Text = "$($files.Count) files"

        if ($files.Count -eq 0) {
            $row.LblSize.Text     = "None"
            $row.LblSize.Foreground = Get-Brush "#6E7681"
            $row.Badge.Background = Get-Brush "#161B22"
        } elseif ($bytes -eq 0) {
            $row.LblSize.Text     = "STUBBED (0 KB)"
            $row.LblSize.Foreground = Get-Brush "#3FB950"
            $row.Badge.Background = Get-Brush "#12261E"
        } else {
            $row.LblSize.Text     = Format-Bytes $bytes
            $row.LblSize.Foreground = Get-Brush $(if ($cat.Warn) { "#FF7B72" } else { "#58A6FF" })
            $row.Badge.Background = Get-Brush $(if ($cat.Warn) { "#341A20" } else { "#122338" })
        }
    }

    $LblTotalActiveGB.Text     = Format-Bytes $totalActiveBytes
    $LblTotalFilesSummary.Text = "$totalActiveCount active files / $totalStubCount stubbed (0KB)"
    Update-SelectedTotals

    # Manifest & pkg_version status
    $persistPath = Join-Path $gameRoot "GenshinImpact_Data\Persistent\res_versions_persist"
    $manifestSynced = if (Test-Path -LiteralPath $persistPath) {
        @(Get-Content -LiteralPath $persistPath -Encoding utf8 | Select-String -SimpleMatch $script:EmptyMd5).Count
    } else { 0 }
    $LblManifestSynced.Text = "$manifestSynced synced"

    $pkgPath = Join-Path $gameRoot "pkg_version"
    $pkgSynced = if (Test-Path -LiteralPath $pkgPath) {
        @(Get-Content -LiteralPath $pkgPath -Encoding utf8 | Select-String -SimpleMatch $script:EmptyMd5).Count
    } else { 0 }
    $LblPkgVersionStatus.Text = "Launcher pkg_version: $pkgSynced entries patched"

    # Revisions
    $persistDir = Join-Path $gameRoot "GenshinImpact_Data\Persistent"
    $channel = if (Test-Path "$persistDir\ChannelName")      { (Get-Content "$persistDir\ChannelName" -Raw).Trim() }      else { "OSRELWin" }
    $scriptV = if (Test-Path "$persistDir\ScriptVersion")    { (Get-Content "$persistDir\ScriptVersion" -Raw).Trim() }    else { "?" }
    $resRev  = if (Test-Path "$persistDir\res_revision")     { (Get-Content "$persistDir\res_revision" -Raw).Trim() }     else { "?" }
    $silRev  = if (Test-Path "$persistDir\silence_revision") { (Get-Content "$persistDir\silence_revision" -Raw).Trim() } else { "?" }
    $datRev  = if (Test-Path "$persistDir\data_revision")    { (Get-Content "$persistDir\data_revision" -Raw).Trim() }    else { "?" }

    $LblVersionString.Text = "${channel}${scriptV}_R${resRev}_S${silRev}_D${datRev}"
    $TxtResRevision.Text   = $resRev

    Write-GuiLog "Scanned '$gameRoot' - Active: $(Format-Bytes $totalActiveBytes) ($totalActiveCount files), Stubbed: $totalStubCount, Manifest synced: $manifestSynced."
}

# --- INITIAL PATH AUTO-DETECTION ---
$initialPath = ""
if (Test-Path -LiteralPath $script:ConfigPath) {
    $saved = (Get-Content -LiteralPath $script:ConfigPath -Raw -ErrorAction SilentlyContinue)
    if ($saved) { $initialPath = $saved.Trim().Replace('"', '') }
}
if (-not $initialPath -or -not (Test-Path (Join-Path $initialPath "GenshinImpact_Data"))) {
    $defaultCandidate = "C:\Program Files\HoYoPlay\games\Genshin Impact game"
    if (Test-Path (Join-Path $defaultCandidate "GenshinImpact_Data")) {
        $initialPath = $defaultCandidate
    }
}
$TxtGamePath.Text = $initialPath

# --- UI EVENT HANDLERS ---
$BtnBrowse.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "Select your 'Genshin Impact game' folder (containing GenshinImpact_Data)"
    if ($TxtGamePath.Text -and (Test-Path $TxtGamePath.Text)) { $dlg.SelectedPath = $TxtGamePath.Text }
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $TxtGamePath.Text = $dlg.SelectedPath
        Refresh-GameScan
    }
})

$BtnRescan.Add_Click({ Refresh-GameScan })

$BtnPresetBoy.Add_Click({
    foreach ($cat in $script:CategoryDefinitions) {
        $script:CategoryRows[$cat.Id].CheckBox.IsChecked = ($cat.SafePreset -or $cat.Id -eq "Boy")
    }
    Update-SelectedTotals
    Write-GuiLog "Preset applied: Up to 7.1 + Boy Traveler cutscenes (7.2 AQ kept intact)."
})

$BtnPresetGirl.Add_Click({
    foreach ($cat in $script:CategoryDefinitions) {
        $script:CategoryRows[$cat.Id].CheckBox.IsChecked = ($cat.SafePreset -or $cat.Id -eq "Girl")
    }
    Update-SelectedTotals
    Write-GuiLog "Preset applied: Up to 7.1 + Girl Traveler cutscenes (7.2 AQ kept intact)."
})

$BtnPresetNoGender.Add_Click({
    foreach ($cat in $script:CategoryDefinitions) {
        $script:CategoryRows[$cat.Id].CheckBox.IsChecked = $cat.SafePreset
    }
    Update-SelectedTotals
    Write-GuiLog "Preset applied: Up to 7.1 Regions + Events + UGC (without Traveler gender cutscenes; 7.2 AQ kept intact)."
})

$BtnSelectAll.Add_Click({
    foreach ($cat in $script:CategoryDefinitions) {
        $script:CategoryRows[$cat.Id].CheckBox.IsChecked = ($cat.Id -notin @("Boy", "Girl"))
    }
    Update-SelectedTotals
    Write-GuiLog "Selected all regions including 7.2 Snezhnaya (Boy/Girl left unchecked so you can pick one)."
})

$BtnSelectNone.Add_Click({
    foreach ($cat in $script:CategoryDefinitions) {
        $script:CategoryRows[$cat.Id].CheckBox.IsChecked = $false
    }
    Update-SelectedTotals
})

$BtnSaveRevision.Add_Click({
    $gameRoot = $TxtGamePath.Text.Trim()
    $resRevFile = Join-Path $gameRoot "GenshinImpact_Data\Persistent\res_revision"
    $newR = $TxtResRevision.Text.Trim().TrimStart('R','r')
    if ($newR -notmatch '^\d+$') {
        [System.Windows.MessageBox]::Show("Resource revision must be numeric.", "Invalid Revision", "OK", "Warning") | Out-Null
        return
    }
    try {
        $newR | Out-File -FilePath $resRevFile -Encoding ascii -Force -NoNewline
        $newR | Out-File -FilePath (Join-Path $gameRoot "GenshinImpact_Data/Persistent/res_revision_eternal") -Encoding ascii -Force -NoNewline
        Write-GuiLog "Updated res_revision to R$newR."
        Refresh-GameScan
    } catch {
        Write-GuiLog "Failed to write res_revision: $_"
    }
})

$BtnStubSelected.Add_Click({
    $gameRoot = $TxtGamePath.Text.Trim()
    $selFiles = @(Get-SelectedDistinctFiles)
    if ($selFiles.Count -eq 0) {
        [System.Windows.MessageBox]::Show("No files matched the selected categories.", "Nothing Selected", "OK", "Information") | Out-Null
        return
    }

    $activeFiles = @($selFiles | Where-Object { $_.Length -gt 0 })
    $totalBytes  = [long]0
    foreach ($f in $activeFiles) { $totalBytes += $f.Length }

    $warn72 = if ($script:CategoryRows["Snezhnaya72"].CheckBox.IsChecked) {
        "`n`nWARNING: You have '8b. Snezhnaya 7.2' checked! Make sure you finished the 7.2 Archon Quest first."
    } else { "" }

    if ($activeFiles.Count -eq 0) {
        $synced = Sync-ManifestEngine -GameRoot $gameRoot
        Write-GuiLog "All $($selFiles.Count) selected files are already 0KB stubs. Re-synced $synced manifest entries."
        Refresh-GameScan
        return
    }

    $ans = [System.Windows.MessageBox]::Show(
        "Stub $($activeFiles.Count) active files ($(Format-Bytes $totalBytes)) to 0KB and synchronize res_versions_persist?$warn72",
        "Confirm Stub & Manifest Sync",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )
    if ($ans -ne [System.Windows.MessageBoxResult]::Yes) { return }

    $stubbed = 0
    foreach ($file in $activeFiles) {
        try {
            Remove-FileLock -Path $file.FullName
            New-Item -Path $file.FullName -ItemType File -Force | Out-Null
            $stubbed++
        } catch {
            Write-GuiLog "Error stubbing $($file.Name): $_"
        }
    }

    $synced = Sync-ManifestEngine -GameRoot $gameRoot
    Write-GuiLog "Stubbed $stubbed files (freed $(Format-Bytes $totalBytes)) and synchronized $synced manifest entries."
    Refresh-GameScan
})

$BtnSyncManifest.Add_Click({
    $gameRoot = $TxtGamePath.Text.Trim()
    $synced = Sync-ManifestEngine -GameRoot $gameRoot
    Write-GuiLog "Manifest Sync complete: $synced stubbed entries registered as valid 0KB assets."
    Refresh-GameScan
})

$BtnSyncPkg.Add_Click({
    $gameRoot = $TxtGamePath.Text.Trim()
    $msg = "Experimental Launcher pkg_version Sync ([P]):`n`n" +
           "- Click YES to SYNC (register current 0KB stubs in pkg_version).`n" +
           "- Click NO to REVERT (restore patched entries from pkg_version.bak).`n" +
           "- Click CANCEL to close.`n`n" +
           "Note: Close HoYoPlay before syncing or reverting."
    $ans = [System.Windows.MessageBox]::Show($msg, "Launcher pkg_version Sync (Experimental)", [System.Windows.MessageBoxButton]::YesNoCancel, [System.Windows.MessageBoxImage]::Information)
    if ($ans -eq [System.Windows.MessageBoxResult]::Yes) {
        $n = Sync-PkgVersionEngine -GameRoot $gameRoot
        if ($n -lt 0) { Write-GuiLog "Error writing pkg_version (is the HoYoPlay launcher open?)." }
        else { Write-GuiLog "Synced $n stubbed entries into launcher pkg_version (backup kept at pkg_version.bak)." }
        Refresh-GameScan
    } elseif ($ans -eq [System.Windows.MessageBoxResult]::No) {
        $n = Restore-PkgVersionEngine -GameRoot $gameRoot
        if ($n -lt 0) { Write-GuiLog "Error writing pkg_version (is the HoYoPlay launcher open?)." }
        else { Write-GuiLog "Reverted $n entries in launcher pkg_version from pkg_version.bak." }
        Refresh-GameScan
    }
})

$BtnUnlockRestore.Add_Click({
    $gameRoot = $TxtGamePath.Text.Trim()
    $selFiles = @(Get-SelectedDistinctFiles)
    if ($selFiles.Count -eq 0) {
        [System.Windows.MessageBox]::Show("Check at least one category to unlock or restore.", "No Categories Checked", "OK", "Information") | Out-Null
        return
    }

    $msg = "Selected $($selFiles.Count) files across checked categories.`n`n" +
           "- Click YES to DELETE STUBS & RESTORE MANIFEST (prepares for major update or lets the game re-download real files).`n" +
           "- Click NO to STRIP LEGACY ACL LOCKS ONLY (keeps 0KB stubs & re-syncs manifest).`n" +
           "- Click CANCEL to abort."
    $ans = [System.Windows.MessageBox]::Show($msg, "Unlock / Restore Selected Categories", [System.Windows.MessageBoxButton]::YesNoCancel, [System.Windows.MessageBoxImage]::Warning)
    if ($ans -eq [System.Windows.MessageBoxResult]::Yes) {
        $deletedNames = @()
        foreach ($f in $selFiles) {
            try {
                Remove-FileLock -Path $f.FullName
                Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
                $deletedNames += $f.Name
            } catch {}
        }
        $restoredM = Restore-ManifestEngine -GameRoot $gameRoot -FileNamesToRestore $deletedNames
        $restoredP = Restore-PkgVersionEngine -GameRoot $gameRoot -FileNamesToRestore $deletedNames
        Write-GuiLog "Removed $($deletedNames.Count) files, restored $restoredM manifest entries and $restoredP pkg_version entries."
        Refresh-GameScan
    } elseif ($ans -eq [System.Windows.MessageBoxResult]::No) {
        foreach ($f in $selFiles) { Remove-FileLock -Path $f.FullName }
        $synced = Sync-ManifestEngine -GameRoot $gameRoot
        Write-GuiLog "Stripped legacy ACL locks from $($selFiles.Count) files and synced $synced manifest entries."
        Refresh-GameScan
    }
})

$BtnCompress.Add_Click({
    $gameRoot = $TxtGamePath.Text.Trim()
    if (-not $gameRoot -or -not (Test-Path -LiteralPath $gameRoot)) { return }
    $ans = [System.Windows.MessageBox]::Show(
        "Run Windows NTFS LZX compression (compact.exe /EXE:LZX) recursively on:`n$gameRoot`n`nThis can take 10-30 minutes and runs in a separate console window.",
        "Confirm LZX Compression",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )
    if ($ans -eq [System.Windows.MessageBoxResult]::Yes) {
        $argS = '/S:"' + $gameRoot + '"'
        Start-Process -FilePath "compact.exe" -ArgumentList @('/C', $argS, '/I', '/EXE:LZX')
        Write-GuiLog "Started compact.exe LZX compression in an external window."
    }
})

$window.Add_ContentRendered({
    Write-GuiLog "GenshinSlimmer v13 GUI ready."
    if ($TxtGamePath.Text) { Refresh-GameScan }
})

[void]$window.ShowDialog()
