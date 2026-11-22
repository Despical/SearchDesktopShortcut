# SearchDesktopShortcut - Copyright (C) 2026 Berke Akcen
# Licensed under the GNU General Public License v3.0 or later. See LICENSE.
#
# Uses a synthetic bundle only. It does not read or change Windows Search files.

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$main = Join-Path $root 'scripts\SearchDesktopShortcut.ps1'
$work = Join-Path ([IO.Path]::GetTempPath()) ("sds-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $work | Out-Null

function Invoke-Project([string[]]$Arguments) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $main @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Project command failed: $($Arguments -join ' ')" }
}

function Invoke-Handler([string]$Exe, [string]$Argument) {
    $process = Start-Process -FilePath $Exe -ArgumentList "`"$Argument`"" -Wait -PassThru -WindowStyle Hidden
    return $process.ExitCode
}

function ConvertTo-Hex([string]$Text) {
    return (($Text.ToCharArray() | ForEach-Object { '{0:x4}' -f [int]$_ }) -join '')
}

function New-Request([string]$Name, [string]$Target) {
    return "desktopshortcut:$(ConvertTo-Hex $Name)-$(ConvertTo-Hex $Target)"
}

function Assert-Equal($Expected, $Actual, [string]$Message) {
    if ($Expected -ne $Actual) { throw "$Message. Expected '$Expected', got '$Actual'." }
}

$created = New-Object Collections.Generic.List[string]
try {
    foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -Filter *.ps1) {
        $errors = $null
        [void][Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$errors)
        Assert-Equal 0 $errors.Count "PowerShell syntax errors in $($file.Name)"
    }

    $errorTexts = (1..60 | ForEach-Object { "function f$_(){throw Error(`"diagnostic message number $_ for testing`")}" }) -join ''
    $bundle = 'var WSB;(function(n){n.host={launch(){}};n.Host={launchUriAsync:(u,d)=>n.host.launch(u,d)};' +
        'n.getItemWithFileMetadata=e=>e.deviceItem;n.isApp=e=>e==="app";n.extendVerbs=e=>e;' + $errorTexts +
        'n.Menu=class{open(e,t){let i=1,r=2;this._page={};this.innerShowContextMenu(n.extendVerbs(e,t,this._page),i,r,0);return this.shown}' +
        'innerShowContextMenu(e){this.shown=e}}})(WSB||(WSB={}));'
    $source = Join-Path $work 'bundle.js'
    $patched = Join-Path $work 'patched.js'
    [IO.File]::WriteAllText($source, $bundle, [Text.Encoding]::ASCII)
    $env:SEARCHDESKTOPSHORTCUT_LANGUAGE = 'tr'
    Invoke-Project @('-Action', 'PatchFile', '-Source', $source, '-Out', (Join-Path $work 'patched-tr.js'))
    $turkish = [IO.File]::ReadAllText((Join-Path $work 'patched-tr.js'))
    if (-not $turkish.Contains('"Masa\u00fcst\u00fcne k\u0131sayol olu\u015ftur"')) { throw 'The Turkish menu label is missing.' }
    $env:SEARCHDESKTOPSHORTCUT_LANGUAGE = 'en'
    Invoke-Project @('-Action', 'PatchFile', '-Source', $source, '-Out', $patched)
    Remove-Item Env:\SEARCHDESKTOPSHORTCUT_LANGUAGE
    & node --check $patched
    if ($LASTEXITCODE -ne 0) { throw 'The patched bundle is not valid JavaScript.' }
    & node (Join-Path $PSScriptRoot 'patch.test.js') $source $patched
    if ($LASTEXITCODE -ne 0) { throw 'Patch tests failed.' }

    $exe = Join-Path $work 'DesktopShortcutHandler.exe'
    Invoke-Project @('-Action', 'BuildHandler', '-Out', $exe)

    $desktop = [Environment]::GetFolderPath('DesktopDirectory')
    $id = [guid]::NewGuid().ToString('N').Substring(0, 8)
    $cases = @(
        @{ Name = "sds-test-exe-$id"; Target = "$env:WINDIR\notepad.exe"; Code = 0; Creates = $true },
        @{ Name = "sds-test-app-$id"; Target = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\notepad.exe'; Code = 0; Creates = $true },
        @{ Name = "sds-test-unc-$id"; Target = '\\server\share\app.exe'; Code = 2; Creates = $false },
        @{ Name = "sds-test-txt-$id"; Target = "$env:WINDIR\win.ini"; Code = 2; Creates = $false },
        @{ Name = "sds-test-up-$id"; Target = '..\..\app.exe'; Code = 2; Creates = $false }
    )
    foreach ($case in $cases) {
        $link = Join-Path $desktop "$($case.Name).lnk"
        $created.Add($link)
        Assert-Equal $case.Code (Invoke-Handler $exe (New-Request $case.Name $case.Target)) "Exit code for $($case.Name)"
        Assert-Equal $case.Creates (Test-Path -LiteralPath $link) "Shortcut state for $($case.Name)"
    }
    Assert-Equal 1 (Invoke-Handler $exe 'desktopshortcut:zz-00') 'Exit code for malformed request'

    Write-Host 'All tests passed.' -ForegroundColor Green
}
finally {
    foreach ($link in $created) {
        if (Test-Path -LiteralPath $link) { [IO.File]::Delete($link) }
    }
    [IO.Directory]::Delete($work, $true)
}
