param([switch]$NoLaunch, [string]$Destination)
$ErrorActionPreference = 'Stop'
if (!$Destination) {
    $Destination = Join-Path $env:LOCALAPPDATA 'Programs/DepartureBoard'
}
$Destination = [IO.Path]::GetFullPath($Destination)
if ([IO.Path]::GetFullPath($PSScriptRoot) -eq $Destination) {
    throw 'Run the installer from the extracted download, outside the installation folder.'
}
$executable = Join-Path $Destination 'DepartureBoard.exe'
$saver = Join-Path $Destination 'DepartureBoard.scr'
$desktop = 'HKCU:\Control Panel\Desktop'
$statePath = Join-Path $Destination 'installation-state.json'
$prior = $null
if (Test-Path $statePath) {
    $prior = Get-Content $statePath -Raw | ConvertFrom-Json
} else {
    $values = Get-ItemProperty $desktop
    $prior = @{
        ScreenSaver = $values.'SCRNSAVE.EXE'
        Active = $values.ScreenSaveActive
    }
}
Get-Process DepartureBoard -ErrorAction SilentlyContinue | Where-Object {
    $_.Path -and [IO.Path]::GetFullPath($_.Path) -eq $executable
} | Stop-Process -Force
New-Item $Destination -ItemType Directory -Force | Out-Null
Copy-Item "$PSScriptRoot/*" $Destination -Recurse -Force
$prior | ConvertTo-Json | Set-Content $statePath -Encoding utf8
Set-ItemProperty $desktop 'SCRNSAVE.EXE' $saver
Set-ItemProperty $desktop 'ScreenSaveActive' '1'
$startMenu = Join-Path ([Environment]::GetFolderPath('Programs')) 'Departure Board.lnk'
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($startMenu)
$shortcut.TargetPath = $executable
$shortcut.WorkingDirectory = $Destination
$shortcut.Save()
Write-Host "Installed Departure Board in $Destination"
if (!$NoLaunch) { Start-Process $executable }
