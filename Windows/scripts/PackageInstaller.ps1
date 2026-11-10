param(
    [ValidateSet('win-x64', 'win-arm64')][string]$Runtime = 'win-x64',
    [string]$OutputDirectory = "$PSScriptRoot/../../work/windows-publish",
    [string]$CompilerPath
)
$ErrorActionPreference = 'Stop'
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
$package = Join-Path $OutputDirectory $Runtime
if (!(Test-Path "$package/DepartureBoard.exe")) { throw 'Publish the application before packaging the installer.' }
if (!$CompilerPath) {
    $CompilerPath = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "$env:ProgramFiles\Inno Setup 7\ISCC.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (!$CompilerPath) { throw 'Install the official Inno Setup compiler first.' }
$project = [xml](Get-Content "$PSScriptRoot/../DepartureBoard.Windows/DepartureBoard.Windows.csproj")
$version = ($project.Project.PropertyGroup.Version | Select-Object -First 1) -replace '-.*$', ''
Copy-Item "$PSScriptRoot/Configure-Installation.ps1" $package -Force
& $CompilerPath "/DPackageDir=$package" "/DAppVersion=$version" "/DRuntime=$Runtime" "/DOutputDir=$OutputDirectory" "$PSScriptRoot/../installer/DepartureBoard.iss"
if ($LASTEXITCODE -ne 0) { throw 'Installer compilation failed.' }
$installer = Join-Path $OutputDirectory "DepartureBoard-$Runtime-Setup.exe"
$hash = (Get-FileHash $installer -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  DepartureBoard-$Runtime-Setup.exe" | Set-Content "$installer.sha256" -Encoding ascii
