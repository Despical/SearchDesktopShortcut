# SearchDesktopShortcut - Copyright (C) 2026 Berke Akcen
# Licensed under the GNU General Public License v3.0 or later. See LICENSE.

[CmdletBinding()]
param(
    [ValidateSet('Install', 'InstallSystem', 'Uninstall', 'RestoreSystem', 'Status', 'BuildHandler', 'PatchFile')]
    [string]$Action = 'Install',
    [string]$Source,
    [string]$Out
)

$ErrorActionPreference = 'Stop'

$ProjectRoot  = Split-Path -Parent $PSScriptRoot
$HandlerSource = Join-Path $ProjectRoot 'src\DesktopShortcutHandler.cs'
$PatchSource  = Join-Path $ProjectRoot 'src\menu-patch.js'

$DataRoot     = Join-Path $env:LOCALAPPDATA 'SearchDesktopShortcut'
$HandlerExe   = Join-Path $DataRoot 'DesktopShortcutHandler.exe'
$CacheBackup  = Join-Path $DataRoot 'cache'
$SystemBackup = Join-Path $DataRoot '11.js.orig'
$SystemHash   = Join-Path $DataRoot '11.js.orig.sha256'

$PackageCache = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.Windows.Search_cw5n1h2txyewy\AC'
$SystemTarget = Join-Path $env:WINDIR 'SystemApps\Microsoft.Windows.Search_cw5n1h2txyewy\cache\Local\Desktop\11.js'
$ProtocolKey  = 'HKCU:\Software\Classes\desktopshortcut'

$Marker        = '/*DesktopShortcutPatch*/'
$AnchorPattern = 'this\.innerShowContextMenu\(([\w$]+)\.extendVerbs\(([\w$]+),t,this\._page\),([\w$]+),([\w$]+),'
$Latin1        = [Text.Encoding]::GetEncoding(28591)
$Utf8Bom       = New-Object System.Text.UTF8Encoding($true)

function Invoke-Native([string]$Exe, [string[]]$Arguments) {
    $output = & $Exe @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "$(Split-Path -Leaf $Exe) failed with exit code $LASTEXITCODE. $($output -join ' ')"
    }
}

function Get-PatchTemplate {
    $lines = Get-Content -LiteralPath $PatchSource -Encoding UTF8 |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith('//') }
    return ($lines -join '')
}

function Get-PatchedText([string]$Text) {
    if ($Text.Contains($Marker)) { throw 'The file is already patched.' }
    $found = [regex]::Matches($Text, $AnchorPattern)
    if ($found.Count -eq 0) { throw 'The expected menu code was not found. Windows Search may have changed.' }
    if ($found.Count -gt 1) { throw 'The expected menu code was found more than once.' }

    $match = $found[0]
    $replacement = (Get-PatchTemplate).
        Replace('@NS@', $match.Groups[1].Value).
        Replace('@VERBS@', $match.Groups[2].Value).
        Replace('@X@', $match.Groups[3].Value).
        Replace('@Y@', $match.Groups[4].Value)
    return $Text.Substring(0, $match.Index) + $replacement + $Text.Substring($match.Index + $match.Length)
}

# Windows Search discards a cached bundle whose size changes. Diagnostic error texts
# are emptied to make room, and the remainder is padded inside the marker comment.
function Get-SizeNeutralText([string]$Text) {
    $patched = Get-PatchedText $Text
    $needed = $patched.Length - $Text.Length
    $builder = New-Object System.Text.StringBuilder $patched
    $literals = [regex]::Matches($patched, '\bError\("([^"\\]{8,})"\)')
    $freed = 0
    for ($i = $literals.Count - 1; $i -ge 0 -and $freed -lt $needed; $i--) {
        $group = $literals[$i].Groups[1]
        [void]$builder.Remove($group.Index, $group.Length)
        $freed += $group.Length
    }
    if ($freed -lt $needed) { throw 'The bundle does not have enough spare text for the patch.' }

    $position = $builder.ToString().IndexOf($Marker, [StringComparison]::Ordinal) + $Marker.Length
    [void]$builder.Insert($position, (' ' * ($freed - $needed)))
    $result = $builder.ToString()
    if ($result.Length -ne $Text.Length) { throw 'The patched bundle size does not match.' }
    return $result
}

function Get-CacheScripts {
    foreach ($name in 'AppCache', 'INetCache') {
        $root = Join-Path $PackageCache $name
        if (Test-Path -LiteralPath $root) {
            Get-ChildItem -LiteralPath $root -Recurse -Force -File -Filter '*.js' -ErrorAction SilentlyContinue |
                Where-Object { $_.Length -gt 100KB }
        }
    }
}

function Stop-Search {
    Get-Process SearchApp -ErrorAction SilentlyContinue | Stop-Process -Force
}

function Build-Handler([string]$Destination) {
    $compiler = Join-Path ([Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()) 'csc.exe'
    if (-not (Test-Path -LiteralPath $compiler)) { throw 'The .NET Framework C# compiler was not found.' }
    Invoke-Native $compiler @('/nologo', '/optimize+', '/target:winexe', "/out:$Destination", $HandlerSource)
}

function Install-Handler {
    New-Item -ItemType Directory -Force $DataRoot | Out-Null
    Build-Handler $HandlerExe
    New-Item -Path "$ProtocolKey\shell\open\command" -Force | Out-Null
    Set-Item -Path $ProtocolKey -Value 'URL:Search Desktop Shortcut'
    New-ItemProperty -Path $ProtocolKey -Name 'URL Protocol' -Value '' -PropertyType String -Force | Out-Null
    Set-Item -Path "$ProtocolKey\shell\open\command" -Value ('"{0}" "%1"' -f $HandlerExe)
    foreach ($name in 'handler.vbs', 'handler.log', 'acl.txt', 'search-settings.json') {
        Remove-Item -LiteralPath (Join-Path $DataRoot $name) -Force -ErrorAction SilentlyContinue
    }
}

function Install-CachePatch {
    New-Item -ItemType Directory -Force $CacheBackup | Out-Null
    $count = 0
    foreach ($file in Get-CacheScripts) {
        $text = $Latin1.GetString([IO.File]::ReadAllBytes($file.FullName))
        $saved = Join-Path $CacheBackup $file.Name
        if ($text.Contains($Marker)) {
            if (-not (Test-Path -LiteralPath $saved)) { throw "Missing backup for $($file.Name)." }
            $clean = $Latin1.GetString([IO.File]::ReadAllBytes($saved))
            if ($clean.Length -ne $text.Length) { throw "The backup size of $($file.Name) does not match." }
        }
        elseif ([regex]::IsMatch($text, $AnchorPattern)) {
            $clean = $text
            [IO.File]::Copy($file.FullName, $saved, $true)
        }
        else { continue }

        $patched = Get-SizeNeutralText $clean
        $count++
        if ($patched -ceq $text) { continue }
        $stamp = $file.LastWriteTimeUtc
        [IO.File]::WriteAllBytes($file.FullName, $Latin1.GetBytes($patched))
        [IO.File]::SetLastWriteTimeUtc($file.FullName, $stamp)
    }
    if ($count -eq 0) { throw 'No Windows Search menu code was found. Open Windows Search once, then try again.' }
    return $count
}

function Restore-CachePatch {
    foreach ($file in Get-CacheScripts) {
        $text = $Latin1.GetString([IO.File]::ReadAllBytes($file.FullName))
        if (-not $text.Contains($Marker)) { continue }
        $saved = Join-Path $CacheBackup $file.Name
        if (-not (Test-Path -LiteralPath $saved)) { throw "Missing backup for $($file.Name)." }
        $stamp = $file.LastWriteTimeUtc
        [IO.File]::Copy($saved, $file.FullName, $true)
        [IO.File]::SetLastWriteTimeUtc($file.FullName, $stamp)
    }
}

function Test-Administrator {
    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-Administrator {
    if (-not (Test-Administrator)) { throw 'This action must run as administrator.' }
}

function Test-SystemPatched {
    return (Test-Path -LiteralPath $SystemTarget) -and [IO.File]::ReadAllText($SystemTarget).Contains($Marker)
}

# Grants temporary write access, then returns the owner and permissions to their original state.
function Write-SystemFile([scriptblock]$Writer) {
    $aclFile = Join-Path $DataRoot 'acl.txt'
    Invoke-Native 'icacls.exe' @($SystemTarget, '/save', $aclFile)
    try {
        Invoke-Native 'takeown.exe' @('/F', $SystemTarget, '/A')
        Invoke-Native 'icacls.exe' @($SystemTarget, '/grant', '*S-1-5-32-544:F')
        & $Writer
    }
    finally {
        try {
            Invoke-Native 'icacls.exe' @($SystemTarget, '/setowner', 'NT SERVICE\TrustedInstaller')
        }
        finally {
            Invoke-Native 'icacls.exe' @((Split-Path $SystemTarget), '/restore', $aclFile)
            Remove-Item -LiteralPath $aclFile -Force -ErrorAction SilentlyContinue
        }
    }
}

function Restore-SystemFile {
    if (-not (Test-SystemPatched)) { return }
    if (-not (Test-Path -LiteralPath $SystemBackup)) { throw 'The system file backup is missing.' }
    $expected = (Get-Content -LiteralPath $SystemHash -Raw).Trim()
    if ((Get-FileHash -LiteralPath $SystemBackup -Algorithm SHA256).Hash -ne $expected) {
        throw 'The system file backup does not match its recorded hash.'
    }
    Write-SystemFile { [IO.File]::WriteAllBytes($SystemTarget, [IO.File]::ReadAllBytes($SystemBackup)) }
}

switch ($Action) {
    'Install' {
        Install-Handler
        $count = Install-CachePatch
        Stop-Search
        Write-Host "Installed. Patched $count Windows Search file(s)." -ForegroundColor Green
        Write-Host 'Open Windows Search and right-click an app.'
    }
    'InstallSystem' {
        Assert-Administrator
        New-Item -ItemType Directory -Force $DataRoot | Out-Null
        if (Test-SystemPatched) {
            if (-not (Test-Path -LiteralPath $SystemBackup)) { throw 'The system file backup is missing.' }
            $clean = $Utf8Bom.GetString([IO.File]::ReadAllBytes($SystemBackup)).TrimStart([char]0xFEFF)
        }
        else {
            $clean = [IO.File]::ReadAllText($SystemTarget)
            Copy-Item -LiteralPath $SystemTarget -Destination $SystemBackup -Force
            (Get-FileHash -LiteralPath $SystemBackup -Algorithm SHA256).Hash | Set-Content -LiteralPath $SystemHash -Encoding ASCII
        }
        $patched = Get-PatchedText $clean
        Stop-Search
        Write-SystemFile { [IO.File]::WriteAllText($SystemTarget, $patched, $Utf8Bom) }
        Stop-Search
        Write-Host 'The local Windows Search copy was patched.' -ForegroundColor Green
    }
    'RestoreSystem' {
        Assert-Administrator
        Stop-Search
        Restore-SystemFile
        Stop-Search
    }
    'Uninstall' {
        Restore-CachePatch
        if (Test-SystemPatched) {
            if (Test-Administrator) {
                Restore-SystemFile
            }
            else {
                $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Action', 'RestoreSystem')
                $process = Start-Process powershell -Verb RunAs -ArgumentList $arguments -Wait -PassThru
                if ($process.ExitCode -ne 0) { throw 'The system file could not be restored.' }
            }
        }
        Stop-Search
        Get-Process DesktopShortcutHandler -ErrorAction SilentlyContinue | Stop-Process -Force
        Remove-Item -Path $ProtocolKey -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $DataRoot -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host 'Uninstalled. Shortcuts already on your desktop were kept.' -ForegroundColor Green
    }
    'Status' {
        $patched = @(Get-CacheScripts | Where-Object {
            $Latin1.GetString([IO.File]::ReadAllBytes($_.FullName)).Contains($Marker)
        }).Count
        Write-Host "Handler installed : $(Test-Path -LiteralPath $HandlerExe)"
        Write-Host "Protocol installed: $(Test-Path -Path $ProtocolKey)"
        Write-Host "Patched web files : $patched"
        Write-Host "Local copy patched: $(Test-SystemPatched)"
    }
    'BuildHandler' {
        Build-Handler $Out
    }
    'PatchFile' {
        $text = $Latin1.GetString([IO.File]::ReadAllBytes($Source))
        [IO.File]::WriteAllBytes($Out, $Latin1.GetBytes((Get-SizeNeutralText $text)))
    }
}
