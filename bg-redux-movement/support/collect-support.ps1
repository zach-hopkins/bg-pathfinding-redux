# Read-only collection; writes one report, never launches the game or uploads data.
[CmdletBinding()]
param(
    [string]$GameDirectory = (Join-Path $PSScriptRoot '..\..'),
    [string]$OutputPath
)
$ErrorActionPreference = 'Stop'
$taskGameRoot = [IO.Path]::GetFullPath($GameDirectory).TrimEnd('\', '/')
$taskReport = New-Object Text.StringBuilder
function Add-Section([string]$Name, [string]$Value) {
    [void]$taskReport.AppendLine("`r`n=== $Name ===")
    [void]$taskReport.AppendLine($Value)
}
function Read-Limited([string]$Path, [int]$Limit = 4194304) {
    if (-not [IO.File]::Exists($Path)) { return '[MISSING]' }
    $stream = $null
    try {
        $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read,
            ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        $length = $stream.Length
        $skip = [Math]::Max(0, $length - $Limit)
        [void]$stream.Seek($skip, [IO.SeekOrigin]::Begin)
        $reader = New-Object IO.StreamReader($stream, [Text.Encoding]::UTF8, $true)
        $text = $reader.ReadToEnd()
        if ($skip -gt 0) {
            $newline = $text.IndexOf("`n")
            if ($newline -ge 0) { $text = $text.Substring($newline + 1) }
            return "[TRUNCATED: newest $Limit bytes of $length retained]`r`n$text"
        }
        return $text
    } catch { return '[UNREADABLE] ' + $_.Exception.Message }
    finally { if ($stream) { $stream.Dispose() } }
}
function Get-LogSetting([string]$Text) {
    $general = $false
    foreach ($line in ($Text -split '\r?\n')) {
        if ($line -match '^\s*\[([^\]]+)\]') { $general = $Matches[1] -ieq 'General'; continue }
        if ($general -and $line -match '^\s*LogFile\s*=(.*)$') {
            return $Matches[1].Trim().Trim('"')
        }
    }
    return ''
}
function Get-FileIdentity([string]$Relative) {
    $path = Join-Path $taskGameRoot $Relative
    if (-not [IO.File]::Exists($path)) { return "$Relative : [MISSING]" }
    try {
        $info = Get-Item -LiteralPath $path
        $version = 'unavailable'
        try { $version = [Diagnostics.FileVersionInfo]::GetVersionInfo($path).FileVersion } catch {}
        $hashStream = [IO.File]::OpenRead($path)
        $hashAlgorithm = [Security.Cryptography.SHA256]::Create()
        try { $digest = [BitConverter]::ToString($hashAlgorithm.ComputeHash($hashStream)).Replace('-', '') }
        finally { $hashStream.Dispose(); $hashAlgorithm.Dispose() }
        return "$Relative : bytes=$($info.Length) version=$version SHA256=$digest"
    } catch { return "$Relative : [UNREADABLE] $($_.Exception.Message)" }
}
[void]$taskReport.AppendLine('BG Redux support report - format 1')
[void]$taskReport.AppendLine('Collected UTC: ' + [DateTime]::UtcNow.ToString('o'))
[void]$taskReport.AppendLine('Review before sharing. May contain character and installed mod names.')
[void]$taskReport.AppendLine('No saves, crash dumps, credentials, environment dump, or uploads included.')
Add-Section 'File versions and actual hashes' ((@(
    'Baldur.exe', 'BaldurII.exe', 'SiegeOfDragonspear.exe', 'EEex.dll', 'LuaBindings.dll', 'InfinityLoader.exe', 'EEex.exe', 'InfinityLoaderDLL.dll',
    'override/M_BGREDX.lua'
) | ForEach-Object { Get-FileIdentity $_ }) -join "`r`n")
Add-Section 'Package metadata' (Read-Limited (Join-Path $taskGameRoot 'bg-redux-movement/release.json') 131072)
Add-Section 'Installer game/version hint' (Read-Limited (Join-Path $taskGameRoot 'bg-redux-movement/installed-profile.lua') 65536)
Add-Section 'Saved feature settings' (Read-Limited (Join-Path $taskGameRoot 'bg-redux-movement.ini') 65536)
Add-Section 'Installed mods (WeiDU.log)' (Read-Limited (Join-Path $taskGameRoot 'WeiDU.log') 524288)
Add-Section 'EEex package version' ((Read-Limited (Join-Path $taskGameRoot 'EEex/EEex.tp2') 262144) -split '\r?\n' |
    Where-Object { $_ -match '^\s*VERSION\s' } | Out-String)
$taskProfiles = Join-Path $taskGameRoot 'bg-redux-movement/profiles.json'
try {
    $profiles = [IO.File]::ReadAllText($taskProfiles) | ConvertFrom-Json
    $identities = foreach ($profile in $profiles) {
        $relative = [string]$profile.runtime_path
        $resolved = [IO.Path]::GetFullPath((Join-Path $taskGameRoot $relative))
        if (-not $resolved.StartsWith($taskGameRoot + [IO.Path]::DirectorySeparatorChar,
                [StringComparison]::OrdinalIgnoreCase)) { continue }
        "Profile: $($profile.id); revision=$($profile.revision); expected SHA256=$($profile.runtime_sha256)"
        Get-FileIdentity $relative
    }
    Add-Section 'Runtime profile identities' ($identities -join "`r`n")
} catch { Add-Section 'Runtime profile identities' ('[UNAVAILABLE] ' + $_.Exception.Message) }
$taskLoaderIni = Read-Limited (Join-Path $taskGameRoot 'InfinityLoader.ini') 262144
$taskLogSetting = Get-LogSetting $taskLoaderIni
$taskLogText = '[MISSING: loader logging is not configured. Reinstall BG Redux with the game closed, then relaunch.]'
if ($taskLogSetting) {
    if ($taskLogSetting.StartsWith('\\')) {
        $taskLogText = '[UNAVAILABLE: configured log is a network path; attach that log separately.]'
    } else {
        $taskLogPath = if ([IO.Path]::IsPathRooted($taskLogSetting)) { $taskLogSetting }
            else { Join-Path $taskGameRoot $taskLogSetting }
        $taskLogText = Read-Limited $taskLogPath
        if ([IO.File]::Exists($taskLogPath)) {
            Add-Section 'Loader log timestamp' ((Get-Item -LiteralPath $taskLogPath).LastWriteTimeUtc.ToString('o'))
        }
    }
}
Add-Section 'Loader log destination' ($taskLogSetting + ' (existing custom destinations are preserved)')
$taskCaptureStatus = if ($taskLogText -match '\[BG Redux\].*\bSTART label=') {
    'Movement capture present. START/END lines identify each recorded run.'
} else { 'NO MOVEMENT CAPTURE RECORDED. Press Left Ctrl+Left Shift+F7 and reproduce within 20 seconds, then collect again.' }
$taskSnapshotStatus = if ($taskLogText -match '\[BG Redux\].*\bSNAPSHOT ') {
    'Party/context snapshots present.'
} else { 'NO GAME-STATE SNAPSHOT RECORDED. Left Ctrl+Left Shift+F8 records a snapshot while in game.' }
Add-Section 'Diagnostic coverage' ($taskCaptureStatus + "`r`n" + $taskSnapshotStatus +
    "`r`nSnapshots/captures describe their recorded moments, not necessarily the current state.`r`nIf startup failed, a capture is not required. For crashes, attach the dump separately if requested.")
Add-Section 'Loader output (bounded; includes startup, errors, captures and game context)' $taskLogText
$taskText = $taskReport.ToString()
$taskText = [regex]::Replace($taskText, [regex]::Escape($taskGameRoot), '[GAME]', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
if ($env:USERPROFILE) {
    $taskText = [regex]::Replace($taskText, [regex]::Escape($env:USERPROFILE), '[USER]', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $taskText = [regex]::Replace($taskText, [regex]::Escape($env:USERPROFILE.Replace('\','/')), '[USER]', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
}
$taskText = [regex]::Replace($taskText, [regex]::Escape($taskGameRoot.Replace('\','/')), '[GAME]', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
$taskExplicitOutput = -not [string]::IsNullOrWhiteSpace($OutputPath)
if (-not $taskExplicitOutput) { $OutputPath = Join-Path $taskGameRoot 'bg-redux-support.log' }
try { [IO.File]::WriteAllText($OutputPath, $taskText, (New-Object Text.UTF8Encoding($false))) }
catch {
    if ($taskExplicitOutput) { throw }
    $OutputPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'bg-redux-support.log'
    [IO.File]::WriteAllText($OutputPath, $taskText, (New-Object Text.UTF8Encoding($false)))
}
Write-Host "Support report saved: $OutputPath"
Write-Host 'Send this one file with a short description of what happened. Nothing was uploaded.'
