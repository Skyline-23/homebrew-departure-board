param(
    [Parameter(Mandatory)][string]$PackageZip,
    [Parameter(Mandatory)][string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
$package = Join-Path $env:RUNNER_TEMP 'DepartureBoard-package'
$installed = Join-Path $env:RUNNER_TEMP 'DepartureBoard-installed'
$installed = [IO.Path]::GetFullPath($installed)
Expand-Archive $PackageZip $package
foreach ($guideFile in @('Install Guide.html', 'Guide/index.html', 'Guide/ko.html', 'Guide/guide.css', 'Guide/images/macos-settings.png', 'Guide/images/windows-settings.png')) {
    if (!(Test-Path (Join-Path $package $guideFile))) { throw "Missing packaged guide asset: $guideFile" }
}
& "$package/Install.ps1" -NoLaunch -Destination $installed
$resident = $null
$saverProcess = $null

try {
    $saver = Join-Path $installed 'DepartureBoard.scr'
    if (!(Test-Path $saver)) {
        throw 'Missing screen saver.'
    }

    $selected = (Get-ItemProperty 'HKCU:\Control Panel\Desktop').'SCRNSAVE.EXE'
    if ($selected -ne $saver) {
        throw 'Screen saver not registered.'
    }

    # Bypass the .scr shell association so it cannot replace our test arguments with /s.
    $start = [Diagnostics.ProcessStartInfo]::new($saver)
    $start.UseShellExecute = $false
    $start.Arguments = '--self-test "' + $OutputDirectory + '"'
    $process = [Diagnostics.Process]::Start($start)

    if (!$process.WaitForExit(120000)) {
        Stop-Process -Id $process.Id -Force
        throw 'Windows render and platform tests timed out.'
    }

    if ($process.ExitCode -ne 0) {
        Get-Content "$OutputDirectory/failure.txt" -ErrorAction SilentlyContinue
        throw 'Windows render and platform tests failed.'
    }

    Get-Content "$OutputDirectory/result.txt"
    $executable = Join-Path $installed 'DepartureBoard.exe'
    $resident = Start-Process $executable -ArgumentList '--background' -PassThru

    if (!$resident.WaitForInputIdle(15000)) {
        throw 'The resident application did not finish startup.'
    }

    $settings = Start-Process $executable -ArgumentList '/c' -PassThru

    if (!$settings.WaitForExit(15000)) {
        Stop-Process -Id $settings.Id -Force
        throw 'A second launch did not hand off to the resident application.'
    }

    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    do {
        Start-Sleep -Milliseconds 100
        $resident.Refresh()
    } until ($resident.MainWindowTitle -eq 'Departure Board Settings' -or
        $resident.HasExited -or [DateTime]::UtcNow -ge $deadline)

    if ($resident.HasExited -or $resident.MainWindowTitle -ne 'Departure Board Settings') {
        throw 'The tray process did not show its settings window.'
    }

    $resident.CloseMainWindow() | Out-Null
    Start-Sleep -Milliseconds 300

    if ($resident.HasExited) {
        throw 'Closing settings terminated the resident application.'
    }

    Add-Content "$OutputDirectory/result.txt" 'Single instance and close-to-tray behavior passed.'

    Stop-Process -Id $resident.Id -Force
    $resident.WaitForExit()
    $resident = $null

    # A running .scr locks the same payload as the tray executable. Both upgrade
    # and uninstall must stop it before replacing or removing program files.
    $start.Arguments = '/s'
    $saverProcess = [Diagnostics.Process]::Start($start)
    if (!$saverProcess.WaitForInputIdle(15000)) { throw 'Screen saver did not start.' }
    & "$package/Install.ps1" -NoLaunch -Destination $installed
    if (!$saverProcess.WaitForExit(15000)) { throw 'Upgrade left the screen saver running.' }
    $saverProcess = [Diagnostics.Process]::Start($start)
    if (!$saverProcess.WaitForInputIdle(15000)) { throw 'Upgraded screen saver did not start.' }
} finally {
    if ($resident -and !$resident.HasExited) {
        Stop-Process -Id $resident.Id -Force
    }

    & "$installed/Uninstall.ps1"
}

if ($saverProcess -and !$saverProcess.WaitForExit(15000)) {
    Stop-Process -Id $saverProcess.Id -Force
    throw 'Uninstall left the screen saver running.'
}

if (Test-Path $installed) {
    throw 'Uninstaller left program files behind.'
}
Add-Content "$OutputDirectory/result.txt" 'Upgrade and uninstall stopped the running screen saver.'
