param(
    [Parameter(Mandatory)][string]$Installer,
    [Parameter(Mandatory)][string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
New-Item $OutputDirectory -ItemType Directory -Force | Out-Null
$destination = Join-Path $OutputDirectory 'installed'
$desktop = 'HKCU:\Control Panel\Desktop'
$entry = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{C92CC9B4-D9CF-499F-8809-BCDBB22A53DA}_is1'
if (Test-Path $entry) { throw 'An EXE installation already exists; use a clean test user.' }
$prior = Get-ItemProperty $desktop
$saved = @{'SCRNSAVE.EXE' = $prior.'SCRNSAVE.EXE'; 'ScreenSaveActive' = $prior.ScreenSaveActive}
$saverProcess = $null

function Invoke-Setup([string]$LogName) {
    $arguments = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /DIR="' + $destination + '" /LOG="' + (Join-Path $OutputDirectory $LogName) + '"'
    $p = Start-Process ([IO.Path]::GetFullPath($Installer)) -ArgumentList $arguments -PassThru
    if (!$p.WaitForExit(120000)) { $p.Kill(); throw 'Installer timed out.' }
    if ($p.ExitCode -ne 0) { throw "Installer returned $($p.ExitCode)." }
}

function Invoke-Uninstall {
    $p = Start-Process (Join-Path $destination 'unins000.exe') -ArgumentList '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART' -PassThru
    if (!$p.WaitForExit(60000)) { $p.Kill(); throw 'Uninstaller timed out.' }
    if ($p.ExitCode -ne 0) { throw "Uninstaller returned $($p.ExitCode)." }
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    while ((Test-Path $destination) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 100 }
    if (Test-Path $destination) { throw 'Uninstaller left program files behind.' }
    if (Test-Path $entry) { throw 'Uninstaller left its Installed apps entry behind.' }
}

try {
    Invoke-Setup 'install.log'
    foreach ($file in @('DepartureBoard.exe', 'DepartureBoard.scr', 'Guide/index.html', 'Guide/ko.html', 'Guide/images/windows-settings.png', 'unins000.exe')) {
        if (!(Test-Path (Join-Path $destination $file))) { throw "Missing installed file: $file" }
    }
    if (!(Test-Path $entry)) { throw 'Missing Installed apps entry.' }
    $saver = Join-Path $destination 'DepartureBoard.scr'
    if ((Get-ItemProperty $desktop).'SCRNSAVE.EXE' -ne $saver) { throw 'Screen saver not selected.' }
    $originalState = Get-Content (Join-Path $destination 'installation-state.json') -Raw

    $start = [Diagnostics.ProcessStartInfo]::new($saver)
    $start.UseShellExecute = $false
    $start.Arguments = '/s'
    $saverProcess = [Diagnostics.Process]::Start($start)
    if (!$saverProcess.WaitForInputIdle(15000)) { throw 'Screen saver did not start before upgrade.' }
    Invoke-Setup 'upgrade.log'
    if (!$saverProcess.WaitForExit(15000)) { throw 'Upgrade left the screen saver running.' }
    if ((Get-Content (Join-Path $destination 'installation-state.json') -Raw) -ne $originalState) { throw 'Upgrade lost the original screen saver state.' }

    Invoke-Uninstall
    foreach ($item in $saved.GetEnumerator()) {
        if ((Get-ItemProperty $desktop).($item.Key) -ne $item.Value) { throw "Uninstall did not restore $($item.Key)." }
    }

    Invoke-Setup 'reinstall.log'
    $chosen = Join-Path $env:WINDIR 'System32/scrnsave.scr'
    Set-ItemProperty $desktop 'SCRNSAVE.EXE' $chosen
    Invoke-Uninstall
    if ((Get-ItemProperty $desktop).'SCRNSAVE.EXE' -ne $chosen) { throw 'Uninstall replaced a later screen saver selection.' }
    'PASS: install, Installed apps entry, guide assets, running-saver upgrade, original selection restoration, later selection preservation, and clean uninstall.' |
        Set-Content (Join-Path $OutputDirectory 'result.txt')
    Get-Content (Join-Path $OutputDirectory 'result.txt')
} finally {
    if ($saverProcess -and !$saverProcess.HasExited) { Stop-Process -Id $saverProcess.Id -Force }
    if (Test-Path (Join-Path $destination 'unins000.exe')) { Invoke-Uninstall }
    foreach ($item in $saved.GetEnumerator()) {
        if ($null -eq $item.Value) { Remove-ItemProperty $desktop $item.Key -ErrorAction SilentlyContinue }
        else { Set-ItemProperty $desktop $item.Key $item.Value }
    }
}
