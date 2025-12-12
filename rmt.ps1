# Goemon64Recomp - Universal Mod Builder (CLI, with last-path reuse + N64Recomp root)
# -----------------------------------------------------------------------------------
# - Remembers:
#     - modSourceFolder  (mod source)
#     - modsOutputFolder (game mods destination)
#     - toolRoot         (N64Recomp root, where RecompModTool.exe lives)
#
# Steps:
# [1/8] Preparing build environment...
# [2/8] Fast dev path reuse (optional)...
# [3/8] Selecting / validating mod source folder...
# [4/8] Selecting / validating mods output folder...
# [5/8] Locating mod repo root and checking dummy_headers\stdio.h...
# [6/8] Checking shared 'patches' folder...
# [7/8] Locating N64Recomp root + RecompModTool.exe...
# [8/8] Building mod and installing...
# [9/9] Launching Goemon64Recompiled.exe and allowing ESC to close game (PowerShell stays open)

param(
    [string]$modSourceFolder,
    [string]$modsOutputFolder
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Test-Command([string]$cmd) {
    $exists = Get-Command $cmd -ErrorAction SilentlyContinue
    return [bool]$exists
}

# Figure out where this script lives, for the .lastpaths.json
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $scriptRoot -or $scriptRoot -eq "") {
    $scriptRoot = (Get-Location).Path
}

$configPath = Join-Path $scriptRoot ".goemon_modbuilder_lastpaths.json"

# Try to read config
$cfg = $null
if (Test-Path $configPath) {
    try {
        $cfgContent = Get-Content $configPath -Raw
        if ($cfgContent -and $cfgContent.Trim().Length -gt 0) {
            $cfg = $cfgContent | ConvertFrom-Json
        }
    }
    catch {
        Write-Host "[WARN] Could not read $configPath, ignoring saved paths." -ForegroundColor Yellow
    }
}

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " Goemon64Recomp - Universal Mod Builder" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# --------------------------------------
# [1/8] Check required tools
# --------------------------------------
Write-Host "[1/8] Preparing build environment..." -ForegroundColor Yellow

$missing = @()

if (-not (Test-Command "git"))   { $missing += "git" }
if (-not (Test-Command "make"))  { $missing += "make" }
if (-not (Test-Command "clang")) { $missing += "clang" }

if ($missing.Count -gt 0) {
    Write-Host "[ERROR] Missing required tools:" -ForegroundColor Red
    $missing | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    Write-Host ""
    Write-Host "Please install the above tools and ensure they are in your PATH, then re-run this script." -ForegroundColor Yellow
    exit 1
}

Write-Host "[OK] git / make / clang found." -ForegroundColor Green
Write-Host ""

# --------------------------------------
# [2/8] Fast dev path reuse (optional)
# --------------------------------------
Write-Host "[2/8] Fast dev path reuse (optional)..." -ForegroundColor Yellow

if (-not $modSourceFolder -and -not $modsOutputFolder -and $cfg -and $cfg.modSourceFolder -and $cfg.modsOutputFolder) {
    Write-Host "  Last mod source folder : $($cfg.modSourceFolder)" -ForegroundColor White
    Write-Host "  Last mods output folder: $($cfg.modsOutputFolder)" -ForegroundColor White
    $reuse = Read-Host "[INPUT] Do you want to build mod from and install to the same paths as last time? (Y/N)"
    if ($reuse -match '^[Yy]') {
        $modSourceFolder = $cfg.modSourceFolder
        $modsOutputFolder = $cfg.modsOutputFolder
        Write-Host "[OK] Reusing last-used mod paths." -ForegroundColor Green
    }
    else {
        Write-Host "[INFO] Not reusing last paths. You will be prompted again." -ForegroundColor Yellow
    }
}
else {
    Write-Host "[INFO] No saved paths found, or paths provided via parameters." -ForegroundColor DarkGray
}

Write-Host ""

# Helper function: modern folder picker using .NET
Add-Type -AssemblyName System.Windows.Forms | Out-Null

function Select-FolderModern([string]$title) {
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = "Folders|*.none"
    $dialog.CheckFileExists = $false
    $dialog.CheckPathExists = $true
    $dialog.FileName = "Select Folder"
    $dialog.Title = $title

    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return [System.IO.Path]::GetDirectoryName($dialog.FileName)
    }
    return $null
}

# --------------------------------------
# [3/8] Select / validate mod source folder
# --------------------------------------
Write-Host "[3/8] Selecting mod source folder..." -ForegroundColor Yellow

while (-not $modSourceFolder) {
    Write-Host "  Please select your MOD SOURCE folder (where mod.toml and Makefile live)." -ForegroundColor White
    $choice = Read-Host "[INPUT] Press ENTER to open folder picker, or type a full path manually"
    if ([string]::IsNullOrWhiteSpace($choice)) {
        $picked = Select-FolderModern "Select MOD SOURCE folder"
        if ($picked) {
            $modSourceFolder = $picked
        }
    }
    else {
        $modSourceFolder = $choice
    }

    if ($modSourceFolder -and -not (Test-Path $modSourceFolder)) {
        Write-Host "[ERROR] Path does not exist: $modSourceFolder" -ForegroundColor Red
        $modSourceFolder = $null
    }
}

$modSourceFolder = (Resolve-Path $modSourceFolder).Path
Write-Host "  Mod source folder: $modSourceFolder" -ForegroundColor White

$modToml = Join-Path $modSourceFolder "mod.toml"
$makefilePath = Join-Path $modSourceFolder "Makefile"

if (-not (Test-Path $modToml)) {
    Write-Host "[ERROR] mod.toml not found at: $modToml" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $makefilePath)) {
    Write-Host "[ERROR] Makefile not found at: $makefilePath" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Found mod.toml at: $modToml" -ForegroundColor Green
Write-Host "[OK] Using Makefile: $makefilePath" -ForegroundColor Green
Write-Host ""

# --------------------------------------
# [4/8] Select / validate mods output folder
# --------------------------------------
Write-Host "[4/8] Selecting mods output folder (game's mods directory)..." -ForegroundColor Yellow

while (-not $modsOutputFolder) {
    Write-Host "  Please select your GAME MODS folder (where the compiled mod will be installed)." -ForegroundColor White
    $choice = Read-Host "[INPUT] Press ENTER to open folder picker, or type a full path manually"
    if ([string]::IsNullOrWhiteSpace($choice)) {
        $picked = Select-FolderModern "Select GAME MODS folder"
        if ($picked) {
            $modsOutputFolder = $picked
        }
    }
    else {
        $modsOutputFolder = $choice
    }

    if ($modsOutputFolder -and -not (Test-Path $modsOutputFolder)) {
        Write-Host "[ERROR] Path does not exist: $modsOutputFolder" -ForegroundColor Red
        $modsOutputFolder = $null
    }
}

$modsOutputFolder = (Resolve-Path $modsOutputFolder).Path
Write-Host "  Mods output folder: $modsOutputFolder" -ForegroundColor White
Write-Host ""

# --------------------------------------
# [5/8] Locate mod repo root & check dummy_headers\stdio.h
# --------------------------------------
Write-Host "[5/8] Checking dummy_headers\stdio.h..." -ForegroundColor Yellow

# Walk upwards from modSourceFolder until we find a .git folder
$repoRoot = $modSourceFolder
$maxDepth = 5
for ($i = 0; $i -lt $maxDepth; $i++) {
    if (Test-Path (Join-Path $repoRoot ".git")) {
        break
    }
    $parent = Split-Path $repoRoot -Parent
    if ([string]::IsNullOrEmpty($parent) -or $parent -eq $repoRoot) {
        break
    }
    $repoRoot = $parent
}

if (-not (Test-Path (Join-Path $repoRoot ".git"))) {
    Write-Host "[WARN] Could not find a .git folder above the mod source. Using mod source folder as repo root." -ForegroundColor Yellow
    $repoRoot = $modSourceFolder
}
Write-Host "[INFO] Repo root: $repoRoot" -ForegroundColor DarkGray

$dummyHeadersDir = Join-Path $repoRoot "dummy_headers"
$stdioPath = Join-Path $dummyHeadersDir "stdio.h"

if (-not (Test-Path $dummyHeadersDir)) {
    Write-Host "[WARN] dummy_headers folder not found at: $dummyHeadersDir" -ForegroundColor Yellow
}
else {
    Write-Host "[INFO] dummy_headers folder found at: $dummyHeadersDir" -ForegroundColor DarkGray
}

if (Test-Path $stdioPath) {
    Write-Host "[INFO] Found dummy_headers\stdio.h at: $stdioPath" -ForegroundColor DarkGray

    try {
        $stdioContent = Get-Content $stdioPath -Raw
        $needsPatch = $true

        if ($stdioContent -match 'typedef unsigned __int64 size_t;') {
            Write-Host "[INFO] stdio.h already has a compatible size_t typedef. No patch needed." -ForegroundColor Green
            $needsPatch = $false
        }
        elseif ($stdioContent -match 'typedef unsigned long size_t;') {
            Write-Host "[INFO] stdio.h has 'typedef unsigned long size_t;'. Will replace with 'unsigned __int64'." -ForegroundColor Yellow
            $needsPatch = $true
        }

        if ($needsPatch) {
            $backupPath = $stdioPath + ".bak"
            if (-not (Test-Path $backupPath)) {
                Copy-Item $stdioPath $backupPath -Force
                Write-Host "[OK] Backed up original stdio.h to: $backupPath" -ForegroundColor Green
            }

            $patchedContent = $stdioContent -replace 'typedef\s+unsigned\s+long\s+size_t;', 'typedef unsigned __int64 size_t;'
            Set-Content -Path $stdioPath -Value $patchedContent
            Write-Host "[OK] Patched stdio.h to use 'unsigned __int64 size_t;'." -ForegroundColor Green
        }
    }
    catch {
        Write-Host "[ERROR] Failed to patch dummy_headers\stdio.h:" -ForegroundColor Red
        Write-Host "        $($_.Exception.Message)" -ForegroundColor Yellow
        exit 1
    }
}
else {
    Write-Host "[INFO] stdio.h already has a compatible size_t typedef. No patch needed." -ForegroundColor Green
}
Write-Host ""

# --------------------------------------
# [6/8] Copy shared 'patches' folder into mod (if missing)
# --------------------------------------
Write-Host "[6/8] Checking shared 'patches' folder..." -ForegroundColor Yellow

$sharedPatches = Join-Path $repoRoot "patches"
$modPatches = Join-Path $modSourceFolder "patches"

if (Test-Path $sharedPatches) {
    Write-Host "[INFO] Shared patches folder found at: $sharedPatches" -ForegroundColor DarkGray

    if (-not (Test-Path $modPatches)) {
        Write-Host "[INFO] Mod has no 'patches' folder. Copying shared patches in..." -ForegroundColor Yellow
        try {
            Copy-Item $sharedPatches $modPatches -Recurse -Force
            Write-Host "[OK] Copied shared 'patches' folder into mod." -ForegroundColor Green
        }
        catch {
            Write-Host "[WARN] Failed to copy shared patches folder (non-fatal): $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "[INFO] Mod already has a 'patches' folder. Leaving it as-is." -ForegroundColor Green
    }
}
else {
    Write-Host "[INFO] No shared 'patches' folder found at: $sharedPatches" -ForegroundColor DarkGray
}
Write-Host ""

# --------------------------------------
# [7/8] Locating N64Recomp root + RecompModTool.exe
# --------------------------------------
Write-Host "[7/8] Locating N64Recomp root + RecompModTool.exe..." -ForegroundColor Yellow

$toolRoot = $null
$toolExe  = $null

function Get-RecompModToolPathFromRoot([string]$root) {
    $candidates = @(
        (Join-Path $root "RecompModTool.exe"),
        (Join-Path $root "build\RecompModTool.exe"),
        (Join-Path $root "RecompModTool\RecompModTool.exe")
    )

    foreach ($c in $candidates) {
        if (Test-Path $c) {
            return $c
        }
    }
    return $null
}

# Try to reuse from config first
if ($cfg -and $cfg.toolRoot) {
    $candidateRoot = $cfg.toolRoot
    if (Test-Path $candidateRoot) {
        $candidateExe = Get-RecompModToolPathFromRoot $candidateRoot
        if ($candidateExe) {
            $toolRoot = (Resolve-Path $candidateRoot).Path
            $toolExe  = (Resolve-Path $candidateExe).Path
            Write-Host "[OK] Reusing N64Recomp root from config: $toolRoot" -ForegroundColor Green
        }
    }
}

# If still not found, try a few guesses based on repoRoot
if (-not $toolExe) {
    $guesses = @(
        (Split-Path $repoRoot -Parent),
        $repoRoot,
        (Join-Path (Split-Path $repoRoot -Parent) "N64Recomp"),
        (Join-Path (Split-Path $repoRoot -Parent) "Goemon64Recomp")
    ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

    foreach ($g in $guesses) {
        $candidateExe = Get-RecompModToolPathFromRoot $g
        if ($candidateExe) {
            $toolRoot = (Resolve-Path $g).Path
            $toolExe  = (Resolve-Path $candidateExe).Path
            Write-Host "[OK] Found RecompModTool.exe at: $toolExe" -ForegroundColor Green
            break
        }
    }
}

# If still not found, prompt the user for N64Recomp root
while (-not $toolExe) {
    Write-Host "[INPUT] Could not automatically locate RecompModTool.exe." -ForegroundColor Yellow
    Write-Host "        Please select the N64Recomp root folder (folder that contains RecompModTool.exe)." -ForegroundColor White
    $choice = Read-Host "[INPUT] Press ENTER to open folder picker, or type a full path manually"
    $candidateRoot = $null

    if ([string]::IsNullOrWhiteSpace($choice)) {
        $picked = Select-FolderModern "Select N64Recomp root folder (where RecompModTool.exe is)"
        if ($picked) {
            $candidateRoot = $picked
        }
    }
    else {
        $candidateRoot = $choice
    }

    if ($candidateRoot -and (Test-Path $candidateRoot)) {
        $candidateExe = Get-RecompModToolPathFromRoot $candidateRoot
        if ($candidateExe) {
            $toolRoot = (Resolve-Path $candidateRoot).Path
            $toolExe  = (Resolve-Path $candidateExe).Path
            Write-Host "[OK] Using N64Recomp root: $toolRoot" -ForegroundColor Green
            break
        }
        else {
            Write-Host "[ERROR] Could not find RecompModTool.exe under: $candidateRoot" -ForegroundColor Red
        }
    }
    else {
        Write-Host "[ERROR] Path does not exist: $candidateRoot" -ForegroundColor Red
    }
}

Write-Host "[INFO] RecompModTool.exe: $toolExe" -ForegroundColor DarkGray
Write-Host ""

# --------------------------------------
# [8/8] Build mod & install into game mods folder
# --------------------------------------
Write-Host "[8/8] Building mod and installing into game mods folder..." -ForegroundColor Yellow

Write-Host "[INFO] Running 'git submodule update --init --recursive' in mod repo root..." -ForegroundColor Yellow
Push-Location $repoRoot
try {
    git submodule update --init --recursive
    if ($LASTEXITCODE -ne 0) {
        throw "git submodule update returned exit code $LASTEXITCODE"
    }
    Write-Host "[OK] git submodule update completed." -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] git submodule update failed:" -ForegroundColor Red
    Write-Host "        $($_.Exception.Message)" -ForegroundColor Yellow
    Pop-Location
    exit 1
}
Pop-Location

Push-Location $modSourceFolder
try {
    Write-Host "[INFO] Running 'make' in mod source folder..." -ForegroundColor Yellow
    make
    if ($LASTEXITCODE -ne 0) {
        throw "make returned exit code $LASTEXITCODE"
    }
    Write-Host "[OK] make completed successfully." -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] make failed:" -ForegroundColor Red
    Write-Host "        $($_.Exception.Message)" -ForegroundColor Yellow
    Pop-Location
    exit 1
}
Pop-Location

# After build, we expect some output under a 'build' folder or similar.
# The exact layout depends on the mod's Makefile, but we will:
#  - Look for any *.mod / *.nrm / *.bin in the build folder
#  - Copy them into the game mods folder

$buildDir = Join-Path $modSourceFolder "build"
if (-not (Test-Path $buildDir)) {
    Write-Host "[WARN] Build directory not found at: $buildDir" -ForegroundColor Yellow
}
else {
    Write-Host "[INFO] Searching for built mod files in: $buildDir" -ForegroundColor DarkGray
    $builtMods = Get-ChildItem -Path $buildDir -File -Include *.mod, *.nrm, *.bin -Recurse -ErrorAction SilentlyContinue

    if (-not $builtMods -or $builtMods.Count -eq 0) {
        Write-Host "[WARN] No *.mod / *.nrm / *.bin files found in build directory." -ForegroundColor Yellow
    }
    else {
        Write-Host "[INFO] Found the following built mod files:" -ForegroundColor DarkGray
        $builtMods | ForEach-Object {
            Write-Host "  - $($_.FullName)" -ForegroundColor White
        }

        foreach ($file in $builtMods) {
            $dest = Join-Path $modsOutputFolder $file.Name
            try {
                Copy-Item $file.FullName $dest -Force
                Write-Host "[OK] Copied $($file.Name) -> $modsOutputFolder" -ForegroundColor Green
            }
            catch {
                Write-Host "[ERROR] Failed to copy $($file.FullName) to $modsOutputFolder" -ForegroundColor Red
                Write-Host "        $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }
}

# Save last used paths (including toolRoot) for next time
try {
    $configObj = [PSCustomObject]@{
        modSourceFolder  = $modSourceFolder
        modsOutputFolder = $modsOutputFolder
        toolRoot         = $toolRoot
    }
    $configObj | ConvertTo-Json | Set-Content -Path $configPath
    Write-Host "[INFO] Saved last-used paths to: $configPath" -ForegroundColor DarkGray
}
catch {
    Write-Host "[WARN] Failed to save last-used paths (non-fatal): $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host " Build complete! Your mod should now be in:" -ForegroundColor Cyan
Write-Host "   $modsOutputFolder" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

# --------------------------------------
# [9/9] Launch Goemon64Recompiled.exe next to the mods folder (optional)
#       + Global ESC detection (works even while game window is focused)
# --------------------------------------

# Define a tiny C# helper to call user32.dll GetAsyncKeyState globally
Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class GlobalKeyboard
{
    [DllImport("user32.dll")]
    private static extern short GetAsyncKeyState(int vKey);

    // 0x1B = ESC key
    public static bool IsEscDown()
    {
        return (GetAsyncKeyState(0x1B) & 0x8000) != 0;
    }
}
"@

try {
    $gameRoot = Split-Path -Path $modsOutputFolder -Parent
    $gameExe  = Join-Path $gameRoot "Goemon64Recompiled.exe"

    if (Test-Path $gameExe) {
        Write-Host "[9/9] Launching Goemon64Recompiled from:" -ForegroundColor Yellow
        Write-Host "      $gameExe" -ForegroundColor Green

        # Start the game and keep a handle so we can monitor / close it.
        $proc = Start-Process -FilePath $gameExe -WorkingDirectory $gameRoot -PassThru

        Write-Host ""
        Write-Host "Game is running." -ForegroundColor Green
        Write-Host "Press ESC on your keyboard at any time to close the game." -ForegroundColor Yellow
        Write-Host "(PowerShell window will stay open so you can immediately rebuild / test again.)" -ForegroundColor DarkGray
        Write-Host ""

        # Poll ESC globally while the game is running
        while (-not $proc.HasExited) {
            if ([GlobalKeyboard]::IsEscDown()) {
                Write-Host "[INFO] ESC detected globally. Closing Goemon64Recompiled.exe..." -ForegroundColor Yellow
                try {
                    if (-not $proc.HasExited) {
                        $proc.Kill()
                    }
                }
                catch {
                    Write-Host "[WARN] Failed to close game process: $($_.Exception.Message)" -ForegroundColor Yellow
                }
                break
            }
            Start-Sleep -Milliseconds 80
        }

        if ($proc.HasExited) {
            Write-Host "[INFO] Game process has exited." -ForegroundColor DarkGray
        }
    }
    else {
        Write-Host "[WARN] Could not find Goemon64Recompiled.exe next to your mods folder." -ForegroundColor Yellow
        Write-Host "       Expected path: $gameExe" -ForegroundColor DarkYellow
        Write-Host "       Launch the game manually if needed." -ForegroundColor DarkGray
    }
}
catch {
    Write-Host "[WARN] Error while trying to launch/monitor Goemon64Recompiled.exe:" -ForegroundColor Yellow
    Write-Host "       $($_.Exception.Message)" -ForegroundColor DarkYellow
}
