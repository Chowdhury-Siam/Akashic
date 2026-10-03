; CI capability probe. ISCC.exe's file version need not match ISCmplr.dll.
#if Ver < EncodeVer(6, 7, 0)
  #error Yutaka's dark installer requires Inno Setup 6.7 or later.
#endif

[Setup]
AppName=Yutaka compiler check
AppVersion=1.0
CreateAppDir=no
Uninstallable=no
Output=no
WizardStyle=modern dark hidebevels includetitlebar
WizardBackColor=#0F1216
