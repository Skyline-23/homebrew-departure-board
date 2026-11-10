param(
    [Parameter(Mandatory)][ValidateSet('Prepare', 'Register', 'Unregister')][string]$Phase,
    [Parameter(Mandatory)][string]$InstallDirectory
)
$ErrorActionPreference = 'Stop'
$destination = [IO.Path]::GetFullPath($InstallDirectory)
$executable = Join-Path $destination 'DepartureBoard.exe'
$saver = Join-Path $destination 'DepartureBoard.scr'
$statePath = Join-Path $destination 'installation-state.json'
$desktop = 'HKCU:\Control Panel\Desktop'

if ($Phase -in @('Prepare', 'Unregister')) {
    Get-Process DepartureBoard* -ErrorAction SilentlyContinue | Where-Object {
        $_.Path -and [IO.Path]::GetFullPath($_.Path) -in @($executable, $saver)
    } | Stop-Process -Force -PassThru | Wait-Process -Timeout 10
}

if ($Phase -eq 'Prepare') {
    if (!(Test-Path $statePath)) {
        $values = Get-ItemProperty $desktop
        $prior = @{ ScreenSaver = $values.'SCRNSAVE.EXE'; Active = $values.ScreenSaveActive }
        New-Item $destination -ItemType Directory -Force | Out-Null
        $prior | ConvertTo-Json | Set-Content $statePath -Encoding utf8
    }
} elseif ($Phase -eq 'Register') {
    if (!(Test-Path $statePath)) { throw 'Missing pre-installation screen saver state.' }
    if (!(Test-Path $saver)) { throw 'Missing installed screen saver.' }
    Set-ItemProperty $desktop 'SCRNSAVE.EXE' $saver
    Set-ItemProperty $desktop 'ScreenSaveActive' '1'
} else {
    $selected = (Get-ItemProperty $desktop).'SCRNSAVE.EXE'
    if ($selected -eq $saver -and (Test-Path $statePath)) {
        $prior = Get-Content $statePath -Raw | ConvertFrom-Json
        foreach ($setting in @{'SCRNSAVE.EXE' = $prior.ScreenSaver; 'ScreenSaveActive' = $prior.Active}.GetEnumerator()) {
            if ($null -eq $setting.Value) {
                Remove-ItemProperty $desktop $setting.Key -ErrorAction SilentlyContinue
            } else {
                Set-ItemProperty $desktop $setting.Key $setting.Value
            }
        }
    }
    $run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    $startup = (Get-ItemProperty $run -ErrorAction SilentlyContinue).DepartureBoard
    if ($startup -eq ('"' + $executable + '" --background')) {
        Remove-ItemProperty $run DepartureBoard
    }
}
