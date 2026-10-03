; Build with Inno Setup 6.7 or later. Paths and version come from CI /D options.
#if Ver < EncodeVer(6, 7, 0)
  #error Yutaka's dark installer requires Inno Setup 6.7 or later.
#endif
#ifndef MyAppName
  #define MyAppName "Yutaka"
#endif
#define MyAppExeName "Yutaka.exe"

[Setup]
; Keep this ID stable so existing installs upgrade in place.
#ifdef InstallerTestAppId
AppId={#InstallerTestAppId}
#else
AppId={{D0F34749-64D8-4B0E-BBA3-026F8B4392C8}
#endif
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=Yutaka
DefaultDirName={localappdata}\Programs\Yutaka
DefaultGroupName={#MyAppName}
DisableWelcomePage=yes
; Use the real directory page under the custom shell so Inno validates and
; commits the inline install location before copying files.
DisableDirPage=no
DisableProgramGroupPage=yes
DisableReadyPage=yes
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
WizardStyle=modern dark hidebevels
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
Source: "{#BrandDir}\windows-sidebar.bmp"; Flags: dontcopy
Source: "{#BrandDir}\windows-icon.bmp"; Flags: dontcopy
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Code]
const
  BackgroundColor = $0016120F;
  SurfaceColor = $001D1813;
  OutlineColor = $00352F27;
  TextColor = $00F6F5F3;
  MutedColor = $00BBB5AD;
  AccentColor = $0091BD00;

var
  Shell, Header, Sidebar, ProgressTrack, ProgressFill: TPanel;
  Headline, PhaseLabel, DetailLabel: TNewStaticText;
  FolderEdit: TNewPathEdit;
  ShortcutCheck: TNewCheckBox;
  BrowseButton, ActionButton, DismissButton, TitleClose: TNewButton;
  InstallationFinished: Boolean;
#ifdef InstallerTestAppId
  ShortcutStateLabel: TNewStaticText;
#endif

function ReleaseCapture: Boolean;
  external 'ReleaseCapture@user32.dll stdcall';

procedure DragHeader(Sender: TObject);
begin
  ReleaseCapture;
  SendMessage(WizardForm.Handle, $00A1, 2, 0);
end;

function PanelAt(Parent: TWinControl; X, Y, W, H: Integer; Color: TColor): TPanel;
begin
  Result := TPanel.Create(WizardForm);
  Result.Parent := Parent;
  Result.StyleElements := [];
  Result.BevelOuter := bvNone;
  Result.Color := Color;
  Result.SetBounds(ScaleX(X), ScaleY(Y), ScaleX(W), ScaleY(H));
end;

function LabelAt(Parent: TWinControl; Text: String; X, Y, W, H, Size: Integer; Color: TColor; Bold: Boolean): TNewStaticText;
begin
  Result := TNewStaticText.Create(WizardForm);
  Result.Parent := Parent;
  Result.StyleElements := [];
  Result.AutoSize := False;
  Result.WordWrap := True;
  Result.Caption := Text;
  Result.Font.Name := 'Segoe UI';
  Result.Font.Size := Size;
  Result.Font.Color := Color;
  if Bold then Result.Font.Style := [fsBold];
  Result.SetBounds(ScaleX(X), ScaleY(Y), ScaleX(W), ScaleY(H));
end;

function ButtonAt(Text: String; X, Y, W, H: Integer; Click: TNotifyEvent): TNewButton;
begin
  Result := TNewButton.Create(WizardForm);
  Result.Parent := Shell;
  Result.Caption := Text;
  Result.Font.Size := 11;
  Result.SetBounds(ScaleX(X), ScaleY(Y), ScaleX(W), ScaleY(H));
  Result.OnClick := Click;
end;

procedure DismissClicked(Sender: TObject);
begin
  if InstallationFinished then
    WizardForm.NextButton.OnClick(WizardForm.NextButton)
  else
    WizardForm.CancelButton.OnClick(WizardForm.CancelButton);
end;

procedure BrowseClicked(Sender: TObject);
var
  Folder: String;
begin
  Folder := FolderEdit.Text;
  if BrowseForFolder('Choose where to install Yutaka', Folder, True) then
    FolderEdit.Text := Folder;
end;

procedure FolderChanged(Sender: TObject);
begin
  WizardForm.DirEdit.Text := FolderEdit.Text;
end;

procedure ApplyDesktopTaskArgument(Argument: String; var Selected: Boolean);
var
  Tasks: TArrayOfString;
  I: Integer;
  Task: String;
begin
  Tasks := StringSplit(Argument, [','], stExcludeEmpty);
  for I := 0 to GetArrayLength(Tasks) - 1 do begin
    Task := Lowercase(Trim(Tasks[I]));
    if (Task = 'desktopicon') or (Task = '*desktopicon') then Selected := True
    else if Task = '!desktopicon' then Selected := False;
  end;
end;

function InitialDesktopShortcut: Boolean;
var
  Previous, Tasks: String;
begin
  Previous := GetPreviousData('DesktopShortcut', '');
  if Previous = '' then
    Result := FileExists(ExpandConstant('{autodesktop}\{#MyAppName}.lnk'))
  else
    Result := Previous = '1';
  Tasks := ExpandConstant('{param:tasks|__yutaka_default__}');
  if Tasks <> '__yutaka_default__' then begin
    Result := False;
    ApplyDesktopTaskArgument(Tasks, Result);
  end;
  ApplyDesktopTaskArgument(ExpandConstant('{param:mergetasks|}'), Result);
end;

#ifdef InstallerTestAppId
procedure ShortcutStateChanged(Sender: TObject);
begin
  // Observe the VCL property in the isolated fixture, not BM_GETCHECK's
  // native button state beneath the dark style hook.
  if ShortcutCheck.Checked then
    ShortcutStateLabel.Caption := 'TEST DESKTOP SHORTCUT: 1'
  else
    ShortcutStateLabel.Caption := 'TEST DESKTOP SHORTCUT: 0';
  Log('Yutaka GUI check: ' + ShortcutStateLabel.Caption);
end;
#endif

procedure ActionClicked(Sender: TObject);
var
  ErrorCode: Integer;
begin
  if InstallationFinished then begin
    if ShellExecAsOriginalUser('open', ExpandConstant('{app}\{#MyAppExeName}'), '', '', SW_SHOWNORMAL, ewNoWait, ErrorCode) then
      WizardForm.NextButton.OnClick(WizardForm.NextButton)
    else begin
      PhaseLabel.Caption := 'COULD NOT OPEN YUTAKA';
      DetailLabel.Caption := 'Open Yutaka from the Start menu, or try again.';
    end;
    Exit;
  end;
  if WizardForm.CurPageID = wpPreparing then begin
    // Preserve Inno's close-app/restart decisions without reapplying options.
    WizardForm.NextButton.OnClick(WizardForm.NextButton);
    Exit;
  end;
  if (Length(FolderEdit.Text) < 3) or
     ((Copy(FolderEdit.Text, 2, 2) <> ':\') and (Copy(FolderEdit.Text, 1, 2) <> '\\')) then begin
    PhaseLabel.Caption := 'INSTALLATION NOT STARTED';
    DetailLabel.Caption := 'Choose an absolute folder path for Yutaka.';
    WizardForm.ActiveControl := FolderEdit;
    Exit;
  end;
  WizardForm.DirEdit.Text := FolderEdit.Text;
  WizardForm.NextButton.OnClick(WizardForm.NextButton);
end;

procedure ShellKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = 27 then begin
    Key := 0;
    if DismissButton.Enabled then DismissClicked(Sender);
  end;
end;

procedure InitializeWizard;
var
  Image: TBitmapImage;
begin
  if WizardSilent then Exit;
  WizardForm.BorderStyle := bsNone;
  WizardForm.BorderIcons := [biSystemMenu, biMinimize];
  WizardForm.ClientWidth := ScaleX(960);
  WizardForm.ClientHeight := ScaleY(640);
  WizardForm.Position := poScreenCenter;
  WizardForm.Color := BackgroundColor;
  WizardForm.OuterNotebook.Hide;
  WizardForm.MainPanel.Hide;
  WizardForm.Bevel.Hide;
  WizardForm.Bevel1.Hide;
  WizardForm.BeveledLabel.Hide;
  WizardForm.BackButton.Hide;
  // ClickToStartPage checks NextButton.CanFocus before skipping the welcome
  // page. Keep the engine's button visible and enabled, outside the custom
  // layout. Hiding it here or in CurPageChanged strands setup on wpWelcome.
  WizardForm.NextButton.Left := ScaleX(980);
  WizardForm.NextButton.TabStop := False;
  WizardForm.NextButton.Default := False;
  // MainForm.Close also checks CancelButton.CanFocus. Keep the native
  // cancel button available to the engine without showing it in our layout.
  WizardForm.CancelButton.Left := ScaleX(1080);
  WizardForm.CancelButton.TabStop := False;
  WizardForm.KeyPreview := True;
  WizardForm.OnKeyDown := @ShellKeyDown;
  Shell := PanelAt(WizardForm, 0, 0, 960, 640, BackgroundColor);
  Header := PanelAt(Shell, 0, 0, 960, 76, SurfaceColor);
  Header.OnClick := @DragHeader;
  PanelAt(Shell, 0, 76, 960, 1, OutlineColor);
  Sidebar := PanelAt(Shell, 0, 77, 244, 563, SurfaceColor);
  PanelAt(Shell, 244, 77, 1, 563, OutlineColor);
  ExtractTemporaryFile('windows-sidebar.bmp');
  ExtractTemporaryFile('windows-icon.bmp');
  Image := TBitmapImage.Create(WizardForm);
  Image.Parent := Header;
  Image.SetBounds(ScaleX(22), ScaleY(18), ScaleX(38), ScaleY(38));
  Image.Stretch := True;
  Image.Bitmap.LoadFromFile(ExpandConstant('{tmp}\windows-icon.bmp'));
  LabelAt(Header, 'Yutaka', 74, 15, 300, 26, 14, TextColor, True);
  LabelAt(Header, 'DESKTOP SETUP', 75, 43, 300, 20, 8, MutedColor, False);
  Image := TBitmapImage.Create(WizardForm);
  Image.Parent := Sidebar;
  Image.SetBounds(0, 0, ScaleX(244), ScaleY(563));
  Image.Stretch := True;
  Image.Bitmap.LoadFromFile(ExpandConstant('{tmp}\windows-sidebar.bmp'));
  Headline := LabelAt(Shell, 'Your finances.' + #13#10 + 'Your control.', 290, 118, 620, 104, 26, TextColor, True);
  LabelAt(Shell, 'Track accounts, expenses and plans in one place.', 292, 235, 610, 46, 12, MutedColor, False);
  LabelAt(Shell, 'Install location', 292, 306, 600, 22, 10, MutedColor, False);
  FolderEdit := TNewPathEdit.Create(WizardForm);
  FolderEdit.Parent := Shell;
  FolderEdit.SetBounds(ScaleX(292), ScaleY(334), ScaleX(477), ScaleY(36));
  FolderEdit.Text := WizardForm.DirEdit.Text;
  FolderEdit.OnChange := @FolderChanged;
  BrowseButton := ButtonAt('Browse…', 781, 333, 132, 38, @BrowseClicked);
  ShortcutCheck := TNewCheckBox.Create(WizardForm);
  ShortcutCheck.Parent := Shell;
  ShortcutCheck.SetBounds(ScaleX(292), ScaleY(384), ScaleX(610), ScaleY(24));
  ShortcutCheck.Caption := 'Create a desktop shortcut';
  ShortcutCheck.Checked := InitialDesktopShortcut;
#ifdef InstallerTestAppId
  // Keep fixture telemetry outside the visible layout. Production builds
  // contain neither this control nor its event handler.
  ShortcutStateLabel := LabelAt(WizardForm, '', 980, 200, 240, 24, 10, TextColor, False);
  ShortcutCheck.OnClick := @ShortcutStateChanged;
  ShortcutStateChanged(ShortcutCheck);
#endif
  PhaseLabel := LabelAt(Shell, 'READY TO INSTALL', 292, 446, 620, 24, 10, AccentColor, True);
  ProgressTrack := PanelAt(Shell, 292, 478, 621, 6, OutlineColor);
  ProgressFill := PanelAt(ProgressTrack, 0, 0, 0, 6, AccentColor);
  DetailLabel := LabelAt(Shell, 'Your accounts, transactions and settings stay in place.', 292, 504, 620, 38, 10, MutedColor, False);
  DismissButton := ButtonAt('Cancel', 619, 560, 132, 48, @DismissClicked);
  ActionButton := ButtonAt('Install Yutaka', 767, 560, 146, 48, @ActionClicked);
  ActionButton.Default := True;
  TitleClose := ButtonAt('×', 890, 18, 44, 38, @DismissClicked);
  TitleClose.Hint := 'Close installer';
  TitleClose.ShowHint := True;
end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := (PageID = wpSelectTasks);
  // Inno creates TasksList immediately before asking whether to skip this
  // page. Earlier calls from the directory page act on an empty task list.
  if Result and not WizardSilent then begin
    if ShortcutCheck.Checked then WizardSelectTasks('desktopicon')
    else WizardSelectTasks('!desktopicon');
#ifdef InstallerTestAppId
    if ShortcutCheck.Checked <> WizardIsTaskSelected('desktopicon') then
      RaiseException('Native desktop task does not match the custom checkbox');
    if WizardIsTaskSelected('desktopicon') then
      Log('Yutaka GUI check: native desktop task = selected')
    else
      Log('Yutaka GUI check: native desktop task = deselected');
#endif
  end;
end;

procedure RegisterPreviousData(PreviousDataKey: Integer);
begin
  // Store the engine's final selection, including command-line silent installs.
  if WizardIsTaskSelected('desktopicon') then
    SetPreviousData(PreviousDataKey, 'DesktopShortcut', '1')
  else
    SetPreviousData(PreviousDataKey, 'DesktopShortcut', '0');
end;

procedure CurPageChanged(CurPageID: Integer);
var
  Ready, Preparing: Boolean;
begin
  if WizardSilent then Exit;
  WizardForm.BackButton.Hide;
  Ready := (CurPageID = wpSelectDir) or (CurPageID = wpReady);
  Preparing := CurPageID = wpPreparing;
  FolderEdit.Enabled := Ready;
  BrowseButton.Enabled := Ready;
  ShortcutCheck.Enabled := Ready;
  ActionButton.Enabled := Ready or (CurPageID = wpFinished) or (Preparing and WizardForm.NextButton.Enabled);
  DismissButton.Enabled := CurPageID <> wpInstalling;
  TitleClose.Enabled := DismissButton.Enabled;
  if Ready then begin
    FolderEdit.Text := WizardForm.DirEdit.Text;
    PhaseLabel.Caption := 'READY TO INSTALL';
    WizardForm.ActiveControl := ActionButton;
  end;
  if CurPageID = wpInstalling then begin
    Headline.Caption := 'Getting Yutaka' + #13#10 + 'ready for you.';
    PhaseLabel.Caption := 'INSTALLING YUTAKA';
    DetailLabel.Caption := 'Copying the app and creating your shortcuts…';
  end;
  if CurPageID = wpFinished then begin
    InstallationFinished := True;
    Headline.Caption := 'Make yourself' + #13#10 + 'at home.';
    PhaseLabel.Caption := 'INSTALLATION COMPLETE';
    DetailLabel.Caption := 'Yutaka is ready. Open it from the Start menu anytime.';
    ProgressFill.Width := ProgressTrack.Width;
    ActionButton.Caption := 'Launch Yutaka';
    DismissButton.Caption := 'Done';
  end;
  // Keep Inno's prerequisite/error and close-app choices visible when needed.
  // These OS decisions must never be hidden behind the custom shell.
  WizardForm.OuterNotebook.Visible := Preparing;
  if Preparing then begin
    Headline.Caption := 'Preparing Yutaka' + #13#10 + 'for installation.';
    PhaseLabel.Caption := 'CHECKING INSTALLATION';
    DetailLabel.Caption := 'Review the installation details above to continue.';
    WizardForm.OuterNotebook.SetBounds(ScaleX(292), ScaleY(288), ScaleX(621), ScaleY(244));
    WizardForm.InnerNotebook.SetBounds(0, 0, ScaleX(621), ScaleY(244));
    WizardForm.OuterNotebook.BringToFront;
    ActionButton.Caption := 'Continue';
  end else if Ready then ActionButton.Caption := 'Install Yutaka';
end;

procedure CurInstallProgressChanged(CurProgress, MaxProgress: Integer);
begin
  if WizardSilent or (MaxProgress = 0) then Exit;
  ProgressFill.Width := Round((CurProgress / MaxProgress) * ProgressTrack.Width);
  PhaseLabel.Caption := 'INSTALLING YUTAKA · ' + IntToStr(Round((CurProgress / MaxProgress) * 100)) + '%';
end;

procedure CancelButtonClick(CurPageID: Integer; var Cancel, Confirm: Boolean);
begin
  // Let the installer finish its transaction; close/cancel are disabled meanwhile.
  Cancel := CurPageID <> wpInstalling;
  if InstallationFinished then Confirm := False;
end;
