$ErrorActionPreference = 'Stop'
$destination = $PSScriptRoot
$executable = Join-Path $destination 'DepartureBoard.exe'
$saver = Join-Path $destination 'DepartureBoard.scr'
$desktop = 'HKCU:\Control Panel\Desktop'
$statePath = Join-Path $destination 'installation-state.json'
Get-Process DepartureBoard* -ErrorAction SilentlyContinue | Where-Object {
    $_.Path -and [IO.Path]::GetFullPath($_.Path) -in @($executable, $saver)
} | Stop-Process -Force -PassThru | Wait-Process -Timeout 10
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
$link = Join-Path ([Environment]::GetFolderPath('Programs')) 'Departure Board.lnk'
if (Test-Path $link) {
    $shell = New-Object -ComObject WScript.Shell
    if ($shell.CreateShortcut($link).TargetPath -eq $executable) { Remove-Item $link }
}
Remove-Item $destination -Recurse -Force
Write-Host 'Removed Departure Board. Settings and credentials were kept.'
