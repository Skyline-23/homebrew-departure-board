param(
    [ValidateSet('win-x64', 'win-arm64')]
    [string]$Runtime = 'win-x64',
    [string]$OutputDirectory = "$PSScriptRoot/../../work/windows-publish",
    [ValidatePattern('^\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?$')][string]$Version
)
$ErrorActionPreference = 'Stop'
$project = Join-Path $PSScriptRoot '../DepartureBoard.Windows/DepartureBoard.Windows.csproj'
$folder = Join-Path $OutputDirectory $Runtime
$versionOption = @()
if ($Version) { $versionOption = @("-p:Version=$Version") }
& dotnet publish $project -c Release -r $Runtime --self-contained true -o $folder @versionOption
if ($LASTEXITCODE -ne 0) { throw 'Windows publish failed.' }
Copy-Item "$folder/DepartureBoard.exe" "$folder/DepartureBoard.scr"
Copy-Item "$PSScriptRoot/Install.ps1" $folder
Copy-Item "$PSScriptRoot/Uninstall.ps1" $folder
Copy-Item "$PSScriptRoot/../README.md" "$folder/README.md"
Copy-Item "$PSScriptRoot/../../Resources/Guide" "$folder/Guide" -Recurse -Force
Copy-Item "$PSScriptRoot/../../Resources/Install Guide.html" $folder
Copy-Item "$PSScriptRoot/../../LICENSE" $folder
Copy-Item "$PSScriptRoot/../../THIRD_PARTY_NOTICES.md" $folder
'@echo off', 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install.ps1"', 'pause' |
    Set-Content "$folder/Install.cmd" -Encoding ascii
Compress-Archive -Path "$folder/*" -DestinationPath "$OutputDirectory/DepartureBoard-$Runtime.zip" -Force
$archive = Join-Path $OutputDirectory "DepartureBoard-$Runtime.zip"
$hash = (Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  DepartureBoard-$Runtime.zip" | Set-Content "$archive.sha256" -Encoding ascii
