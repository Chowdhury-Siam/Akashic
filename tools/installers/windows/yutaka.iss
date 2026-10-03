; Build with Inno Setup 6.7 or later. Paths and version come from CI /D options.
#if Ver < EncodeVer(6, 7, 0)
  #error Yutaka's dark installer requires Inno Setup 6.7 or later.
#endif
#define MyAppName "Yutaka"
#define MyAppExeName "Yutaka.exe"

[Setup]
; Keep this ID stable so existing installs upgrade in place.
AppId={{D0F34749-64D8-4B0E-BBA3-026F8B4392C8}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=Yutaka
DefaultDirName={localappdata}\Programs\Yutaka
DefaultGroupName={#MyAppName}
DisableWelcomePage=no
DisableDirPage=no
DisableProgramGroupPage=yes
DisableReadyPage=no
DisableFinishedPage=no
OutputDir={#OutputDir}
OutputBaseFilename=YutakaSetup
SetupIconFile={#IconFile}
UninstallDisplayIcon={app}\{#MyAppExeName}
VersionInfoDescription=Yutaka Installer
VersionInfoProductName=Yutaka
VersionInfoCompany=Yutaka
Compression=lzma2/fast
SolidCompression=yes
WizardStyle=modern dark hidebevels includetitlebar
WizardBackColor=#0F1216
WizardImageFile={#BrandDir}\windows-sidebar.bmp
WizardImageBackColor=#0F1216
WizardSmallImageFile={#BrandDir}\windows-icon.bmp
WizardSmallImageBackColor=#0F1216
WizardImageStretch=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Messages]
WelcomeLabel1=Welcome to Yutaka
WelcomeLabel2=Your finances, in your control.%n%nInstall Yutaka on this computer to get started. Your existing accounts, transactions and settings stay in place during an upgrade.%n%nClick Next to continue.
FinishedHeadingLabel=Yutaka is ready
FinishedLabel=Yutaka has been installed on your computer.%n%nOpen the app and make yourself at home.
BeveledLabel=Yutaka  {#MyAppVersion}

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
