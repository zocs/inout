#define MyAppName "inout"
#define MyAppVersion "0.1.0"
#define MyAppExeName "inout_flutter.exe"

[Setup]
AppId={{C8B2E5F6-A9D3-4B1C-8E7F-2D4A6B8C0E3F}
AppName={#MyAppName} Portable
AppVersion={#MyAppVersion}
DefaultDirName=inout
DefaultGroupName={#MyAppName}
OutputDir=dist
OutputBaseFilename=inout-portable-v{#MyAppVersion}
SetupIconFile=windows\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
Uninstallable=no
CreateUninstallRegKey=no
ChangesAssociations=no
DirExistsWarning=no
AppendDefaultDirName=yes
UsePreviousAppDir=no
DisableProgramGroupPage=yes
DisableReadyPage=no
InfoBeforeFile=README.md

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "PRIVACY.md"; DestDir: "{app}"; Flags: ignoreversion

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch inout"; Flags: nowait postinstall skipifsilent
Filename: "{cmd}"; Parameters: "/c start {app}"; Description: "Open folder"; Flags: nowait postinstall skipifsilent
