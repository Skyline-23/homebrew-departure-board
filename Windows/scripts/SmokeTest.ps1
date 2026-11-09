param(
    [Parameter(Mandatory)][string]$PackageZip,
    [Parameter(Mandatory)][string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
$package = Join-Path $env:RUNNER_TEMP 'DepartureBoard-package'
$installed = Join-Path $env:RUNNER_TEMP 'DepartureBoard-installed'
$installed = [IO.Path]::GetFullPath($installed)
Expand-Archive $PackageZip $package
& "$package/Install.ps1" -NoLaunch -Destination $installed
$resident = $null

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
    $start.ArgumentList.Add('--self-test')
    $start.ArgumentList.Add($OutputDirectory)
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
} finally {
    if ($resident -and !$resident.HasExited) {
        Stop-Process -Id $resident.Id -Force
    }

    & "$installed/Uninstall.ps1"
}

if (Test-Path $installed) {
    throw 'Uninstaller left program files behind.'
}
