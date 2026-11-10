#ifndef PackageDir
  #error PackageDir is required
#endif
#ifndef AppVersion
  #error AppVersion is required
#endif
#ifndef Runtime
  #define Runtime "win-x64"
#endif

[Setup]
AppId={{C92CC9B4-D9CF-499F-8809-BCDBB22A53DA}
AppName=Departure Board
AppVersion={#AppVersion}
AppPublisher=Skyline23
AppPublisherURL=https://dpboard.skyline23.com
AppSupportURL=https://dpboard.skyline23.com/guide/index.html
DefaultDirName={localappdata}\Programs\DepartureBoard
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
#if Runtime == "win-arm64"
ArchitecturesAllowed=arm64
ArchitecturesInstallIn64BitMode=arm64
#else
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
#endif
MinVersion=10.0.22000
OutputDir={#OutputDir}
OutputBaseFilename=DepartureBoard-{#Runtime}-Setup
SetupIconFile={#PackageDir}\Assets\DepartureBoard.ico
UninstallDisplayIcon={app}\DepartureBoard.exe
Compression=lzma2/fast
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"

[Files]
Source: "{#PackageDir}\*"; DestDir: "{app}"; Excludes: "Install.cmd,Install.ps1,Uninstall.ps1,installation-state.json"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\scripts\Configure-Installation.ps1"; Flags: dontcopy

[Icons]
Name: "{userprograms}\Departure Board"; Filename: "{app}\DepartureBoard.exe"; WorkingDir: "{app}"

[InstallDelete]
Type: files; Name: "{app}\Install.cmd"
Type: files; Name: "{app}\Install.ps1"
Type: files; Name: "{app}\Uninstall.ps1"

[Run]
Filename: "{app}\DepartureBoard.exe"; Description: "{cm:LaunchProgram,Departure Board}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: files; Name: "{app}\installation-state.json"
Type: dirifempty; Name: "{app}"

[Code]
function ConfigureInstallation(Script, Phase: String): Boolean;
var
  ExitCode: Integer;
begin
  Result := Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
    '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + Script +
    '" -Phase ' + Phase + ' -InstallDirectory "' + ExpandConstant('{app}') + '"',
    '', SW_HIDE, ewWaitUntilTerminated, ExitCode) and (ExitCode = 0);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  ExtractTemporaryFile('Configure-Installation.ps1');
  if not ConfigureInstallation(ExpandConstant('{tmp}\Configure-Installation.ps1'), 'Prepare') then
    Result := 'Could not prepare Departure Board for installation. Close the app and try again.';
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
    if not ConfigureInstallation(ExpandConstant('{app}\Configure-Installation.ps1'), 'Register') then
      RaiseException('Could not register the Departure Board screen saver.');
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
    if not ConfigureInstallation(ExpandConstant('{app}\Configure-Installation.ps1'), 'Unregister') then
      RaiseException('Could not restore the previous screen saver.');
end;
